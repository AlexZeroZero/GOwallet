package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherFactory;
import java.nio.charset.StandardCharsets;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

/** GOwallet Android fork of flutter_secure_storage 8.1.0. See LICENSE. */
public class FlutterSecureStorage {
    protected String ELEMENT_PREFERENCES_KEY_PREFIX =
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";
    protected Map<String, Object> options;
    private final Context applicationContext;

    public FlutterSecureStorage(Context context) {
        applicationContext = context.getApplicationContext();
    }

    private String option(String key, String fallback) {
        Object value = options == null ? null : options.get(key);
        return value == null || value.toString().isEmpty() ? fallback : value.toString();
    }

    private SharedPreferences ensureInitialized() throws Exception {
        // An unavailable protected store must never look like an empty wallet.
        if (!"true".equals(option("encryptedSharedPreferences", "false"))
                || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw new IllegalStateException("Authenticated storage is required");
        }
        String name = option("sharedPreferencesName", "FlutterSecureStorage");
        ELEMENT_PREFERENCES_KEY_PREFIX = option("preferencesKeyPrefix",
                "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg");
        SharedPreferences raw = applicationContext.getSharedPreferences(name, Context.MODE_PRIVATE);
        // No fallback, reset or cached failed instance. A later request can retry.
        SharedPreferences encrypted = openEncryptedPreferences(applicationContext, name);
        final StorageCipher[] legacyCipher = {null};
        VerifiedMigration.migrate(raw, encrypted, ELEMENT_PREFERENCES_KEY_PREFIX, value -> {
            if (legacyCipher[0] == null) legacyCipher[0] = loadLegacyCipher(raw);
            byte[] plaintext = legacyCipher[0].decrypt(Base64.decode(value, Base64.DEFAULT));
            // A malformed old value must not silently become replacement characters.
            return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(plaintext)).toString();
        });
        return encrypted;
    }

    // Package-visible seams let instrumentation exercise actual failure paths.
    StorageCipher loadLegacyCipher(SharedPreferences source) throws Exception {
        return new StorageCipherFactory(source, options).getSavedStorageCipher(applicationContext);
    }

    SharedPreferences openEncryptedPreferences(Context context, String name) throws Exception {
        MasterKey key = new MasterKey.Builder(context)
                .setKeyGenParameterSpec(new KeyGenParameterSpec.Builder(
                        MasterKey.DEFAULT_MASTER_KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setKeySize(256).build())
                .build();
        return EncryptedSharedPreferences.create(context, name, key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM);
    }

    boolean containsKey(String key) throws Exception {
        return ensureInitialized().contains(key);
    }

    String read(String key) throws Exception {
        return ensureInitialized().getString(key, null);
    }

    public Map<String, String> readAll() throws Exception {
        Map<String, String> result = new HashMap<>();
        for (Map.Entry<String, ?> entry : ensureInitialized().getAll().entrySet()) {
            String prefix = ELEMENT_PREFERENCES_KEY_PREFIX + "_";
            if (entry.getKey().startsWith(prefix)) {
                if (!(entry.getValue() instanceof String)) {
                    throw new IllegalStateException("Unexpected protected value type");
                }
                result.put(entry.getKey().substring(prefix.length()), (String) entry.getValue());
            }
        }
        return result;
    }

    void write(String key, String value) throws Exception {
        VerifiedMigration.commitOrThrow(ensureInitialized().edit().putString(key, value));
    }

    public void delete(String key) throws Exception {
        VerifiedMigration.commitOrThrow(ensureInitialized().edit().remove(key));
    }

    void deleteAll() throws Exception {
        // Only an explicit deleteAll call may clear the store, never an error handler.
        VerifiedMigration.commitOrThrow(ensureInitialized().edit().clear());
    }
}
