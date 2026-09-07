"""Read-only OSV check of registry packages locked for the Isar native build."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import tomllib
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lock = root / "vendor/isar_native/Cargo.lock"
packages = [p for p in tomllib.loads(lock.read_text())["package"]
            if p.get("source", "").startswith("registry+")]
queries = [{"package": {"ecosystem": "crates.io", "name": p["name"]},
            "version": p["version"]} for p in packages]
results = []
for offset in range(0, len(queries), 100):
    batch = queries[offset:offset+100]
    request = urllib.request.Request("https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": batch}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=45) as response:
        findings = json.load(response)["results"]
    if len(findings) != len(batch):
        raise RuntimeError("OSV response count mismatch")
    results.extend({**query, **finding} for query, finding in zip(batch, findings))
report = {"checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "lock_sha256": hashlib.sha256(lock.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
          "scope": "All locked crates.io packages, including host/dev/other-platform dependencies. Excludes vendored Isar/libmdbx source, Android binaries, Rust standard library and SDK. Advisory matching is not reachability analysis or an independent audit.",
          "packages": results}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checked": len(results), "matches": [p for p in results if p.get("vulns")]}))
