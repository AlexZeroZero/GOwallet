"""Verify a GOwallet 1.0 APK with Android SDK tools; writes public JSON evidence."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

p = argparse.ArgumentParser()
p.add_argument('apk', type=Path)
p.add_argument('--build-tools', type=Path, required=True)
p.add_argument('--output', type=Path, default=Path('evidence/release.json'))
p.add_argument('--code-commit', required=True)
a = p.parse_args()
cert = '6e796fcb039900ddf4e0bd6b488fe524f665049b37fc480454fcf0f4c5a43f6e'
suffix = '.bat' if __import__('os').name == 'nt' else ''
signer = subprocess.check_output([str(a.build_tools / ('apksigner' + suffix)), 'verify', '--verbose', '--print-certs', str(a.apk)], text=True)
aapt = str(a.build_tools / ('aapt.exe' if suffix else 'aapt'))
badging = subprocess.check_output([aapt, 'dump', 'badging', str(a.apk)], text=True)
manifest = subprocess.check_output([aapt, 'dump', 'xmltree', str(a.apk), 'AndroidManifest.xml'], text=True)
assert cert in signer
for scheme in ('v2', 'v3'):
    assert re.search(r'Verified using ' + scheme + r' scheme[^\n]*true', signer)
assert "name='org.gowallet.pow' versionCode='9' versionName='1.0.0'" in badging
assert "sdkVersion:'24'" in badging
for flag in ('allowBackup', 'fullBackupContent'):
    assert re.search(r'android:' + flag + r'\([^\n]+0x0\s*$', manifest, re.M)
assert not re.search(r'android:debuggable[^\n]*0xffffffff', manifest)
with zipfile.ZipFile(a.apk) as z:
    assert z.testzip() is None
    abis = sorted(n for n in z.namelist() if n.endswith('/libapp.so'))
    assert abis == ['lib/arm64-v8a/libapp.so', 'lib/x86_64/libapp.so']
    assert any(a.code_commit.encode() in z.read(n) for n in abis), 'Code commit not embedded in APK'
result = {
    'checked_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'version': '1.0.0+9', 'package': 'org.gowallet.pow',
    'app_code_commit': a.code_commit, 'apk': a.apk.name,
    'bytes': a.apk.stat().st_size,
    'sha256': hashlib.sha256(a.apk.read_bytes()).hexdigest(),
    'certificate_sha256': cert, 'apk_v2_v3_signature': 'PASS',
    'same_signing_identity_as_0_4_2': True, 'zip_crc': 'PASS',
    'min_android_api': 24, 'abis': ['arm64-v8a', 'x86_64'],
    'android_backup_disabled': True, 'debuggable': False,
    'limits': ['Static APK checks; does not itself verify device upgrade, malware or SPV correctness']
}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
