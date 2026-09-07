# GOwallet Isar Android compiler hardening

Isar remains **3.3.0-dev.2** and libmdbx remains **v0.13.8**. This is a source
rebuild of the native library, not a database engine/schema or Dart API upgrade.

- Isar source: https://github.com/isar-community/isar-community/tree/39ea19ff035518aef4d0e776206d96a428f57789
- libmdbx source: https://github.com/isar-community/libmdbx/tree/4d58857f8fd0aba400706610ba05ba4dd869f04e
- Isar and libmdbx Apache-2.0 licenses are retained. The `mdbx-sys` crate declares
  MPL-2.0; its license text is supplied beside its manifest. Rust registry
  dependencies and checksums are recorded in `Cargo.lock` under their own licenses.

Upstream did not publish a Cargo.lock for this tag. This rebuild resolves and
locks its declared Rust dependencies; it does not claim to reconstruct every
dependency version used by upstream's historical binary build. Rust **1.88.0**
matches the upstream Android build script. Android C compilation/linking uses
NDK **28.0.13004108**, API **24**.

## Changes

1. Replace the build-time mutable libmdbx tag clone with the vendored source.
   Copy source into Cargo's output directory before generating version.c.
2. Add `-fstack-protector-strong` and `_FORTIFY_SOURCE=2` to the Android C
   database engine. Preserve its original feature definitions and optimizations.
3. Explicitly link with RELRO, immediate binding, a non-executable stack and
   16 KiB maximum page alignment. Bindgen receives the NDK target, sysroot and
   resource headers rather than accidentally using host-platform headers.
4. Keep the hosted `isar_community_flutter_libs` package/API unchanged. The root
   Android Gradle project replaces only its JNI library source directory with
   `vendor/isar_native/android`; absent builds fail explicitly without silently
   shipping upstream binaries. No native binaries are committed in this folder.

Canary/FORTIFY detection verifies protections in the C database engine. It does
not assert that every Rust function has a stack canary or that all memory-safety
vulnerabilities have been eliminated. Rust code, schema definitions, FFI methods
and wallet logic are not changed. Do not insert artificial symbol references to
make scanners report protections that are not actually compiled into the engine.

## Build prerequisites and commands

Use Python **3.11+**, rustup/Cargo with Rust **1.88.0**, the specified Android NDK,
a host C linker, and a loadable libclang for bindgen. On Windows, the tested host
was `x86_64-pc-windows-gnu` with MinGW GCC and libclang. Put Cargo and the host
compiler/DLL directory on PATH, and set LIBCLANG_PATH to that DLL directory.
An MSVC-host Rust installation requires the matching MSVC host build tools.
Cross-host bit-for-bit reproducibility is not claimed.

```text
rustup toolchain install 1.88.0 --profile minimal
rustup target add --toolchain 1.88.0 aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
python tool/build_isar_android.py --ndk <Android-SDK>/ndk/28.0.13004108
```

Run these commands from the GOwallet repository root. The Windows Android build
helper also runs this native build and accepts `-IsarNdkDirectory`; otherwise it
uses ANDROID_HOME or ANDROID_SDK_ROOT. Cargo uses `--locked` and incremental
output. The build script checks the actual library for required mitigations and
writes a JSON manifest with source and binary hashes. Generated `android/` and
`target/` directories are ignored. Linux-host support is provided by the script
but has not been tested for the official APK.

## Compatibility and limits

`tool/isar_compatibility_probe.c` uses the public synchronous FFI in isolated
synthetic Android databases. It exercises original-library creation, hardened
read/write, unique indexes, links, JSON/scalar/list data, explicit transaction
rollback, integrity checks, process termination with an uncommitted write, and
original-library reread. Run each phase in a new process. It is not a real-wallet
recovery test or proof against physical storage failure.

All three rebuilt ABIs retain the original 93 global exports. The APP supports
ARM64/x86_64; the additional ARMv7 native library does not establish complete
Flutter ARMv7 support. APK upgrade and exact-release-library checks are recorded
in the release verification evidence rather than inferred from a successful build.

OSV checks of the lockfile include host/dev/platform dependencies and do not
cover all native/SDK vulnerabilities. `paste 1.0.15` retains the upstream
unmaintained advisory **RUSTSEC-2024-0436**. It is a compile-time procedural macro;
no exploitable runtime vulnerability is established by that advisory. It remains
visible for dependency-maintenance follow-up.
