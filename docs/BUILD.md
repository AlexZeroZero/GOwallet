# Build GOwallet 1.0.1

The release uses Flutter 3.47.0 (Dart 3.13.0), JDK 17, Android SDK 36 and NDK 28.2.13676358 (application) and 28.0.13004108 (vendored SQLite). Build from the public release tag and preserve `pubspec.lock`. Templates generate the ignored `pubspec.yaml`, Android flavor and assets; do not use the inherited upstream flavor generator for GOwallet.

## Windows

Install Git, Python 3, Flutter and the Android toolchain. Put Flutter/Dart on PATH, accept Android SDK licenses, configure JAVA_HOME and ANDROID_HOME/SDK. Use an ASCII checkout/build path. Enable Windows Developer Mode if Flutter requires plugin symlinks.

```powershell
git clone https://github.com/AlexZeroZero/GOwallet.git
cd GOwallet
git checkout v1.0.1
python tool/configure_electrum_wallet.py
$env:FLUTTER_WINDOWS = 'false'
$env:FLUTTER_LINUX = 'false'
$env:FLUTTER_MACOS = 'false'
flutter pub get --enforce-lockfile
flutter build apk --debug --no-pub --target-platform android-arm64,android-x64
```

For a signed release, the Windows helper loads or creates a local signing identity. Set your actual JDK/Python paths and choose a new ASCII junction pointing to this checkout:

The helper disables unrelated desktop plugin generation for its process and restores the environment afterwards. It fails on dependency/platform generation errors. Explicit Flutter global/project desktop feature overrides may still require Developer Mode for symlinks.

```powershell
./tool/build_android.ps1 -Release -Python python -JavaHome $env:JAVA_HOME -BuildRoot D:\gowallet-build -TempRoot D:\gowallet-tmp
```

By default the helper keeps its PKCS12 key and Windows-user-bound DPAPI password in ignored `.private/gowallet-signing`. Back them up securely; DPAPI ciphertext alone is not a portable signing backup. To reuse an existing publisher identity, pass `-SigningDirectory` pointing to its protected external directory. Missing files in an explicitly supplied directory cause failure. Never commit that directory, Android `key.properties`, credentials or keystores.

Other build hosts may use the generator and Flutter directly, providing `GOWALLET_KEYSTORE`, `GOWALLET_KEY_ALIAS` and `GOWALLET_KEY_PASSWORD` privately to Gradle for a release build. These platforms have not been validated for this release. The official signing key is not part of the source, and independently signed builds cannot overwrite the official installation. Byte-for-byte reproducibility has not been independently established.

## Regression checks

On Windows the signing tests require `build/secp256k1.dll`. Build bitcoin-core/secp256k1 revision `e3a885d42a7800c1ccebad94ad1e2b82c4df5c65` (v0.5.0) with a compatible x64 C compiler/CMake, shared-library output and `SECP256K1_ENABLE_MODULE_RECOVERY=ON`, then place the resulting DLL at that path. The release checks used the existing locally compiled DLL; Android builds compile their own native library via `vendor/coinlib_flutter/src/CMakeLists.txt`. Do not substitute an unknown downloaded DLL.

```powershell
$tests = @(Get-ChildItem test/gowallet*_test.dart | ForEach-Object FullName)
flutter test --no-pub --reporter expanded @tests test/scash_shic_signing_test.dart test/scash_shic_wallet_test.dart
python tool/audit_pub_osv.py --output evidence/pub-osv.json
```

These tests use fixtures/mocks; live network tests are separate and no real-fund broadcast is implied. Some inherited upstream analyzer warnings remain. Optional inherited submodules are not required by the GOwallet Android flavor; their revisions and licenses are preserved. Native dependencies and tools must still be installed/downloaded by the build system.

## Android storage fault-injection tests (1.0.1)

With an API 24+ test device/emulator connected and the generated Android project configured:

```powershell
./android/gradlew.bat -p android :flutter_secure_storage:connectedDebugAndroidTest --console=plain
```

Release evidence used an API 35 x86_64 emulator and 17 tests with isolated synthetic namespaces, not user wallet data. See [verification and limits](VERIFICATION-1.0.1.md). Local `flutter_secure_storage` and `sqlite3_flutter_libs` overrides are intentional; preserve them and the lockfile. SQLite source is fetched with a fixed SHA-256 and compiled locally, so CMake and the specified NDK are required. Original plugin licenses and all platform sources remain under `vendor/`.
