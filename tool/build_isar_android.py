"""Build the pinned Isar C/Rust source for Android without changing wallet schemas.

Requires Rust 1.88.0, Android NDK r28, libclang for bindgen, and a host C linker.
See vendor/isar_native/GOWALLET-PATCHES.md. No signing keys are used here.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vendor/isar_native"
TARGETS = {
    "arm64-v8a": ("aarch64-linux-android", "aarch64-linux-android"),
    "armeabi-v7a": ("armv7-linux-androideabi", "armv7a-linux-androideabi"),
    "x86_64": ("x86_64-linux-android", "x86_64-linux-android"),
}


def run(args, env):
    subprocess.run([str(a) for a in args], cwd=SOURCE, env=env, check=True)


def source_digest():
    digest = hashlib.sha256()
    digest.update(b"tool/build_isar_android.py\0" + Path(__file__).read_bytes().replace(b"\r\n", b"\n"))
    for path in sorted(SOURCE.rglob("*")):
        rel = path.relative_to(SOURCE)
        if not path.is_file() or rel.parts[0] in {"target", "android"}:
            continue
        if path.suffix not in {".rs", ".toml", ".lock", ".c", ".h", ".in"}:
            continue
        digest.update(rel.as_posix().encode() + b"\0" + path.read_bytes().replace(b"\r\n", b"\n"))
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ndk", type=Path, required=True)
    parser.add_argument("--cargo", default="cargo")
    parser.add_argument("--abis", nargs="+", choices=TARGETS, default=list(TARGETS))
    args = parser.parse_args()
    windows = platform.system() == "Windows"
    host = "windows-x86_64" if windows else "linux-x86_64"
    ndk = args.ndk.resolve()
    properties = (ndk / "source.properties").read_text()
    if not re.search(r"Pkg.Revision\s*=\s*28\.0\.13004108", properties):
        raise SystemExit("Use the reviewed Android NDK 28.0.13004108 (r28).")
    toolchain = ndk / "toolchains/llvm/prebuilt" / host
    binary = toolchain / "bin"
    suffix = ".exe" if windows else ""
    clang = binary / ("clang" + suffix)
    readelf = binary / ("llvm-readelf" + suffix)
    env = os.environ.copy()
    env["ISAR_VERSION"] = "3.3.0-dev.2"
    env["CARGO_TARGET_DIR"] = str(SOURCE / "target")
    records = []
    for abi in args.abis:
        rust_target, clang_target = TARGETS[abi]
        variable = rust_target.replace("-", "_")
        # Explicit target/sysroot also keep bindgen host headers out of Android FFI.
        env["CC_" + variable] = str(clang)
        env["CFLAGS_" + variable] = f"--target={clang_target}24"
        env["AR_" + variable] = str(binary / ("llvm-ar" + suffix))
        env["CARGO_TARGET_" + variable.upper() + "_LINKER"] = str(clang)
        env["BINDGEN_EXTRA_CLANG_ARGS_" + variable] = (
            f'--target={clang_target}24 --sysroot="{toolchain / "sysroot"}" '
            f'-resource-dir="{toolchain / "lib/clang/19"}"'
        )
        env["RUSTFLAGS"] = (
            f"-C link-arg=--target={clang_target}24 "
            "-C link-arg=-Wl,--hash-style=both "
            "-C link-arg=-Wl,-z,relro,-z,now,-z,noexecstack "
            "-C link-arg=-Wl,-z,max-page-size=16384"
        )
        run([args.cargo, "+1.88.0", "build", "--locked", "--release", "-p", "isar",
             "--target", rust_target], env)
        lib = SOURCE / "target" / rust_target / "release/libisar.so"
        symbols = subprocess.check_output([readelf, "--dyn-syms", "-W", lib], text=True)
        segments = subprocess.check_output([readelf, "-lW", lib], text=True)
        dynamic = subprocess.check_output([readelf, "-dW", lib], text=True)
        fortify = sorted(set(re.findall(r"\b(\w+_chk)(?:@|\s|$)", symbols)))
        stack = next((s for s in segments.splitlines() if "GNU_STACK" in s), "")
        if not ("__stack_chk_fail" in symbols and fortify and "GNU_RELRO" in segments
                and "BIND_NOW" in dynamic and re.search(r"\bRW\s+0x", stack)):
            raise RuntimeError(f"{abi}: expected native mitigations were not detected")
        destination = SOURCE / "android" / abi / "libisar.so"
        destination.parent.mkdir(parents=True, exist_ok=True)
        payload = lib.read_bytes()
        destination.write_bytes(payload)
        records.append({"abi": abi, "sha256": hashlib.sha256(payload).hexdigest(),
                        "bytes": len(payload), "fortify_symbols": fortify,
                        "stack_canary": True, "relro": True, "bind_now": True,
                        "non_executable_stack": True})
    manifest = {"isar": "3.3.0-dev.2", "libmdbx": "v0.13.8", "rust": "1.88.0",
                "ndk": "28.0.13004108", "android_api": 24,
                "source_sha256": source_digest(), "binaries": records}
    (SOURCE / "android/build-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
