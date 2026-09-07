package com.it_nomads.fluttersecurestorage;

import android.content.SharedPreferences;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

/** Copy and verify before retiring legacy ciphertext; safe to retry after interruption. */
final class VerifiedMigration {
    interface Decoder { String decode(String value) throws Exception; }

    static boolean hasLegacyValues(SharedPreferences source, String prefix) {
        for (String key : source.getAll().keySet()) {
            if (key.startsWith(prefix + "_")) return true;
        }
        return false;
    }

    static void commitOrThrow(SharedPreferences.Editor editor) throws IOException {
        if (!editor.commit()) throw new IOException("Secure storage commit failed");
    }

    static void migrate(SharedPreferences source, SharedPreferences target,
                        String prefix, Decoder decoder) throws Exception {
        Map<String, String> values = new LinkedHashMap<>();
        // Validate every source and conflict before changing either store.
        for (Map.Entry<String, ?> entry : source.getAll().entrySet()) {
            String key = entry.getKey();
            if (!key.startsWith(prefix + "_")) continue;
            if (!(entry.getValue() instanceof String)) {
                throw new IOException("Unexpected legacy value type");
            }
            String value = decoder.decode((String) entry.getValue());
            if (value == null) throw new IOException("Legacy decryption returned null");
            if (target.contains(key) && !value.equals(target.getString(key, null))) {
                throw new IOException("Legacy and protected values conflict");
            }
            values.put(key, value);
        }
        if (values.isEmpty()) {
            // An empty old store can still have unencrypted algorithm metadata.
            // Leaving it beside GCM values would break EncryptedSharedPreferences.getAll().
            if (source.contains("FlutterSecureSAlgorithmKey") || source.contains("FlutterSecureSAlgorithmStorage")) {
                commitOrThrow(source.edit().remove("FlutterSecureSAlgorithmKey")
                        .remove("FlutterSecureSAlgorithmStorage"));
            }
            return;
        }

        SharedPreferences.Editor copy = target.edit();
        for (Map.Entry<String, String> entry : values.entrySet()) {
            copy.putString(entry.getKey(), entry.getValue());
        }
        // Equal values are committed again: an earlier attempt may have failed on disk.
        commitOrThrow(copy);
        for (Map.Entry<String, String> entry : values.entrySet()) {
            if (!entry.getValue().equals(target.getString(entry.getKey(), null))) {
                throw new IOException("Protected copy verification failed");
            }
        }

        SharedPreferences.Editor cleanup = source.edit();
        for (String key : values.keySet()) cleanup.remove(key);
        cleanup.remove("FlutterSecureSAlgorithmKey");
        cleanup.remove("FlutterSecureSAlgorithmStorage");
        // Both wrappers share the SAME backing XML. First persist both copies;
        // only the second commit retires the legacy entries.
        commitOrThrow(cleanup);
    }

    private VerifiedMigration() { }
}
