"""Query public OSV advisories for locked hosted Dart dependencies only."""
from pathlib import Path
import datetime
import json
import re
import urllib.request
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--output', default='evidence/gowallet/go032-pub-osv.json')
args = parser.parse_args()

root = Path(__file__).resolve().parents[1]
packages = []
for match in re.finditer(r'^  ([\w]+):\n(.*?)(?=^  \w+:|\Z)', (root/'pubspec.lock').read_text(), re.M|re.S):
    name, block = match.groups()
    if '    source: hosted' in block:
        version = re.search(r'^    version: "([^"]+)"', block, re.M).group(1)
        packages.append({'package': {'name': name, 'ecosystem': 'Pub'}, 'version': version})
result = {'checked_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'scope': 'Hosted Pub dependencies only; excludes git, local, native binaries and SDK', 'packages': []}
for offset in range(0, len(packages), 100):
    batch = packages[offset:offset+100]
    request = urllib.request.Request('https://api.osv.dev/v1/querybatch', data=json.dumps({'queries': batch}).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=25) as response:
        data = json.load(response)
    for package, advisory in zip(batch, data['results']):
        result['packages'].append({**package, **advisory})
dest = root/args.output
dest.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'checked': len(packages), 'matches': [p for p in result['packages'] if p.get('vulns')]}))
