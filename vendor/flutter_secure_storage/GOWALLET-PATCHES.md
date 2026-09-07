# GOwallet Android patch based on flutter_secure_storage 8.1.0

Upstream package: https://pub.dev/packages/flutter_secure_storage/versions/8.1.0
Upstream archive SHA-256 from the original Pub lockfile:
`22dbf16f23a4bcf9d35e51be1c84ad5bb6f627750565edd70dab70f3ff5fff8f`.
The upstream BSD license is retained in LICENSE. Dart and iOS APIs are unchanged.

This Android fork requires `encryptedSharedPreferences: true` and API 24+, matching
the GOwallet application. It keeps the existing SharedPreferences filename,
key prefix, AndroidX master-key alias and AES256-SIV/GCM format.

- No implicit fallback to legacy CBC, automatic key replacement, or error-triggered wipe.
- Legacy CBC/GCM is read only for migration using existing wrapped/RSA keys.
- Decode and check all old values/conflicts before copying. Persist the protected
  copies synchronously and read them back before removing source entries. Both
  wrappers share the same backing XML. Failed/interrupted cleanup can be retried;
  conflicting copies remain available for recovery instead of being overwritten.
- Commit failures reach the caller. Provider exceptions are normalized at the
  method channel without leaking ciphertext, aliases or stack traces. A failed
  read never reports successful absence; FileNotFoundException also replies.
- Normal GCM reads do not initialize legacy keys. Malformed UTF-8 is rejected
  during legacy conversion. Empty legacy metadata is retired without key creation.

This fork intentionally ignores Android `resetOnError`; only an explicit
`deleteAll` call clears the protected store. Generic applications requiring direct
legacy writes must not adopt this fork without adapting their usage.

Real Android instrumentation tests in `android/src/androidTest` cover compatibility,
initialization failure/retry, corrupt ciphertext, target/cleanup commit failure,
conflicts, readback failure, missing/damaged keys and the method-channel error path.
They use isolated synthetic namespaces, never user wallets. Run through the
GOwallet Android Gradle project: `:flutter_secure_storage:connectedDebugAndroidTest`.

CBC strings remain for recovery of old data and biometric compatibility. Their
presence in a scanner report does not mean this fork writes new wallet data in CBC.
No independent audit or zero-vulnerability claim is made.
