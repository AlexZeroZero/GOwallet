package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import android.util.Base64;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherFactory;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import static org.junit.Assert.*;

/** Real AndroidKeyStore and EncryptedSharedPreferences; synthetic values only. */
@RunWith(AndroidJUnit4.class)
public class StorageHardeningTest {
    private Context context;
    private FlutterSecureStorage storage;
    private SharedPreferences raw;
    private String prefix;
    private String key;

    @Before public void setup() {
        final String namespace = "storage_test_" + UUID.randomUUID().toString().replace("-", "");
        context = new ContextWrapper(InstrumentationRegistry.getInstrumentation().getTargetContext()) {
            @Override public Context getApplicationContext() { return this; }
            @Override public String getPackageName() { return "org.gowallet.tests." + namespace; }
            @Override public SharedPreferences getSharedPreferences(String name, int mode) {
                return super.getSharedPreferences(namespace + "_" + name, mode);
            }
        };
        storage = configured(new FlutterSecureStorage(context));
        raw = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE);
        prefix = storage.ELEMENT_PREFERENCES_KEY_PREFIX;
        key = prefix + "_wallet_mnemonic";
    }

    private <T extends FlutterSecureStorage> T configured(T value) {
        value.options = new HashMap<>();
        value.options.put("encryptedSharedPreferences", "true");
        value.options.put("resetOnError", "false");
        return value;
    }

    private SharedPreferences encrypted() throws Exception {
        return storage.openEncryptedPreferences(context, "FlutterSecureStorage");
    }

    private StorageCipher legacy(String... values) throws Exception {
        StorageCipherFactory factory = new StorageCipherFactory(raw, storage.options);
        StorageCipher cipher = factory.getCurrentStorageCipher(context);
        SharedPreferences.Editor edit = raw.edit();
        for (int i = 0; i < values.length; i++) {
            edit.putString(i == 0 ? key : prefix + "_extra" + i,
                    Base64.encodeToString(cipher.encrypt(values[i].getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP));
        }
        factory.storeCurrentAlgorithms(edit);
        assertTrue(edit.commit());
        return cipher;
    }

    private interface Action { void run() throws Exception; }
    private static void fails(Action action) throws Exception {
        try { action.run(); fail("Expected storage failure"); }
        catch (Exception expected) { /* failure must reach caller */ }
    }

    @Test public void existingGcmIdentityAndNormalOperationsRemainCompatible() throws Exception {
        assertTrue(encrypted().edit().putString(key, "existing-public-fixture").commit());
        assertEquals("existing-public-fixture", storage.read(key));
        storage.write(prefix + "_pin", "synthetic-pin-hash");
        assertEquals("synthetic-pin-hash", storage.readAll().get("pin"));
        assertFalse(raw.contains(key));
        assertFalse(raw.getAll().containsValue("synthetic-pin-hash"));
        storage.delete(prefix + "_pin");
        assertFalse(storage.containsKey(prefix + "_pin"));
        assertEquals("existing-public-fixture", configured(new FlutterSecureStorage(context)).read(key));
    }

    @Test public void cbcMigratesMultipleValuesInSameBackingFile() throws Exception {
        legacy("public-fixture-one", "public-fixture-two");
        assertEquals("public-fixture-one", storage.read(key));
        assertEquals("public-fixture-two", storage.readAll().get("extra1"));
        assertFalse(raw.contains(key));
        assertFalse(raw.contains(prefix + "_extra1"));
        assertFalse(raw.contains("FlutterSecureSAlgorithmStorage"));
        assertEquals("public-fixture-one", configured(new FlutterSecureStorage(context)).read(key));
    }

    @Test public void initializationFailureNeverReturnsMissingWritesOrDeletesAndCanRetry() throws Exception {
        legacy("keep-me");
        final boolean[] unavailable = {true};
        FlutterSecureStorage failing = configured(new FlutterSecureStorage(context) {
            @Override SharedPreferences openEncryptedPreferences(Context c, String n) throws Exception {
                if (unavailable[0]) throw new IOException("simulated keystore unavailability");
                return super.openEncryptedPreferences(c, n);
            }
        });
        Map<String, ?> before = new HashMap<>(raw.getAll());
        fails(() -> failing.read(key));
        fails(() -> failing.containsKey(key));
        fails(() -> failing.readAll());
        fails(() -> failing.write(key, "replacement"));
        fails(() -> failing.delete(key));
        fails(() -> failing.deleteAll());
        assertEquals(before, raw.getAll());
        unavailable[0] = false;
        assertEquals("keep-me", failing.read(key));
    }

    @Test public void unauthenticatedModeIsRejectedWithoutCreatingData() throws Exception {
        storage.options.put("encryptedSharedPreferences", "false");
        fails(() -> storage.write(key, "never-store-this"));
        assertTrue(raw.getAll().isEmpty());
    }

    @Test public void corruptLegacyCiphertextPreventsPartialMigration() throws Exception {
        legacy("good-value", "bad-value");
        String original = raw.getString(key, null);
        assertTrue(raw.edit().putString(prefix + "_extra1", "invalid-ciphertext").commit());
        SharedPreferences target = encrypted();
        fails(() -> storage.read(key));
        assertEquals(original, raw.getString(key, null));
        assertFalse(target.contains(key));
        assertEquals("invalid-ciphertext", raw.getString(prefix + "_extra1", null));
    }

    private SharedPreferences failCommit(SharedPreferences delegate) {
        return (SharedPreferences) Proxy.newProxyInstance(SharedPreferences.class.getClassLoader(),
                new Class[]{SharedPreferences.class}, (p, method, args) -> {
            if (method.getName().equals("edit")) {
                SharedPreferences.Editor edit = delegate.edit();
                return Proxy.newProxyInstance(SharedPreferences.Editor.class.getClassLoader(),
                        new Class[]{SharedPreferences.Editor.class}, (ep, em, ea) -> {
                    if (em.getName().equals("commit")) return false;
                    Object result = em.invoke(edit, ea);
                    return result instanceof SharedPreferences.Editor ? ep : result;
                });
            }
            try { return method.invoke(delegate, args); }
            catch (InvocationTargetException e) { throw e.getCause(); }
        });
    }

    private void migrate(StorageCipher cipher, SharedPreferences source, SharedPreferences target) throws Exception {
        VerifiedMigration.migrate(source, target, prefix, value -> new String(
                cipher.decrypt(Base64.decode(value, Base64.DEFAULT)), StandardCharsets.UTF_8));
    }

    @Test public void failedTargetCommitRetainsAllLegacyValues() throws Exception {
        StorageCipher cipher = legacy("keep-one", "keep-two");
        SharedPreferences target = encrypted();
        String original = raw.getString(key, null);
        fails(() -> migrate(cipher, raw, failCommit(target)));
        assertEquals(original, raw.getString(key, null));
        assertFalse(target.contains(key));
        assertEquals("keep-one", storage.read(key));
    }

    @Test public void interruptionAfterCopyCanRetryWithoutOverwritingOrLosingData() throws Exception {
        StorageCipher cipher = legacy("recover-after-interruption");
        SharedPreferences target = encrypted();
        String original = raw.getString(key, null);
        fails(() -> migrate(cipher, failCommit(raw), target));
        assertEquals(original, raw.getString(key, null));
        assertEquals("recover-after-interruption", target.getString(key, null));
        assertEquals("recover-after-interruption", configured(new FlutterSecureStorage(context)).read(key));
        assertFalse(raw.contains(key));
    }

    @Test public void conflictingCopiesArePreservedForRecovery() throws Exception {
        legacy("legacy-version");
        SharedPreferences target = encrypted();
        assertTrue(target.edit().putString(key, "different-protected-version").commit());
        String original = raw.getString(key, null);
        fails(() -> storage.read(key));
        assertEquals(original, raw.getString(key, null));
        assertEquals("different-protected-version", target.getString(key, null));
    }

    @Test public void failedReadbackNeverDeletesSource() throws Exception {
        StorageCipher cipher = legacy("verify-before-cleanup");
        SharedPreferences target = encrypted();
        SharedPreferences wrongReadback = (SharedPreferences) Proxy.newProxyInstance(
                SharedPreferences.class.getClassLoader(), new Class[]{SharedPreferences.class}, (p, m, a) -> {
                    if (m.getName().equals("getString")) return "incorrect-readback";
                    try { return m.invoke(target, a); }
                    catch (InvocationTargetException e) { throw e.getCause(); }
                });
        String original = raw.getString(key, null);
        fails(() -> migrate(cipher, raw, wrongReadback));
        assertEquals(original, raw.getString(key, null));
        assertEquals("verify-before-cleanup", storage.read(key));
    }

    @Test public void missingWrappedLegacyKeyIsNeverRegenerated() throws Exception {
        legacy("keep-ciphertext");
        SharedPreferences keys = context.getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE);
        assertTrue(keys.edit().clear().commit());
        String original = raw.getString(key, null);
        fails(() -> storage.read(key));
        assertTrue(keys.getAll().isEmpty());
        assertEquals(original, raw.getString(key, null));
    }

    @Test public void damagedWrappedKeyIsNotOverwritten() throws Exception {
        legacy("keep-ciphertext");
        SharedPreferences keys = context.getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE);
        String entry = keys.getAll().keySet().iterator().next();
        assertTrue(keys.edit().putString(entry, "damaged-wrapped-key").commit());
        fails(() -> storage.read(key));
        assertEquals("damaged-wrapped-key", keys.getString(entry, null));
        assertTrue(raw.contains(key));
    }

    @Test public void normalGcmDoesNotTouchLegacyKeys() throws Exception {
        assertTrue(encrypted().edit().putString(key, "already-migrated").commit());
        FlutterSecureStorage noLegacy = configured(new FlutterSecureStorage(context) {
            @Override StorageCipher loadLegacyCipher(SharedPreferences source) {
                throw new AssertionError("GCM storage must not initialize a legacy cipher");
            }
        });
        assertEquals("already-migrated", noLegacy.read(key));
        noLegacy.write(key, "updated-value");
        assertEquals("updated-value", noLegacy.read(key));
    }

    @Test public void authenticatedCiphertextTamperingIsRejectedWithoutWipe() throws Exception {
        storage.write(key, "synthetic-confidential-value");
        String encryptedKey = null;
        for (String k : raw.getAll().keySet()) {
            if (!k.startsWith("__androidx_security_crypto_")) encryptedKey = k;
        }
        assertNotNull(encryptedKey);
        byte[] ciphertext = Base64.decode(raw.getString(encryptedKey, null), Base64.DEFAULT);
        ciphertext[ciphertext.length - 1] ^= 1;
        String damaged = Base64.encodeToString(ciphertext, Base64.NO_WRAP);
        assertTrue(raw.edit().putString(encryptedKey, damaged).commit());
        fails(() -> storage.read(key));
        assertEquals(damaged, raw.getString(encryptedKey, null));
    }

    @Test public void methodChannelFailureNeverResetsEvenWhenResetWasRequested() throws Exception {
        legacy("preserve-on-file-error");
        FlutterSecureStorage failing = configured(new FlutterSecureStorage(context) {
            @Override SharedPreferences openEncryptedPreferences(Context c, String n) throws Exception {
                throw new FileNotFoundException("private-error-details-must-not-escape");
            }
        });
        FlutterSecureStoragePlugin plugin = new FlutterSecureStoragePlugin();
        Field field = FlutterSecureStoragePlugin.class.getDeclaredField("secureStorage");
        field.setAccessible(true);
        field.set(plugin, failing);
        Map<String, Object> args = new HashMap<>();
        args.put("key", "wallet_mnemonic");
        failing.options.put("resetOnError", "true");
        args.put("options", failing.options);
        final int[] calls = {0};
        MethodChannel.Result result = new MethodChannel.Result() {
            @Override public void success(Object value) { fail("Storage error reported as success"); }
            @Override public void notImplemented() { fail("Missing error response"); }
            @Override public void error(String code, String message, Object details) {
                calls[0]++;
                assertEquals("secure_storage_unavailable", code);
                assertFalse(message.contains("private-error"));
                assertNull(details);
            }
        };
        String original = raw.getString(key, null);
        plugin.new MethodRunner(new MethodCall("read", args), result).run();
        assertEquals(1, calls[0]);
        assertEquals(original, raw.getString(key, null));
    }

    @Test public void normalWriteCommitFailureReachesCaller() throws Exception {
        SharedPreferences target = encrypted();
        FlutterSecureStorage failing = configured(new FlutterSecureStorage(context) {
            @Override SharedPreferences openEncryptedPreferences(Context c, String n) { return failCommit(target); }
        });
        fails(() -> failing.write(key, "must-not-report-success"));
        assertFalse(target.contains(key));
    }

    @Test public void emptyLegacyStoreMetadataDoesNotBreakReadAll() throws Exception {
        assertTrue(raw.edit().putString("FlutterSecureSAlgorithmKey", "RSA_ECB_PKCS1Padding") // gitleaks:allow -- public algorithm identifier
                .putString("FlutterSecureSAlgorithmStorage", "AES_CBC_PKCS7Padding").commit());
        assertTrue(storage.readAll().isEmpty());
        assertFalse(raw.contains("FlutterSecureSAlgorithmStorage"));
        storage.write(key, "new-wallet-fixture");
        assertEquals("new-wallet-fixture", storage.read(key));
    }

    @Test public void missingRsaKeyIsNotRecreatedDuringRecovery() throws Exception {
        legacy("old-data-needs-original-key");
        java.security.KeyStore keyStore = java.security.KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        String alias = context.getPackageName() + ".FlutterSecureStoragePluginKey";
        keyStore.deleteEntry(alias); // Unique synthetic test alias, never a wallet key.
        fails(() -> storage.read(key));
        assertFalse(keyStore.containsAlias(alias));
        assertTrue(raw.contains(key));
    }
}
