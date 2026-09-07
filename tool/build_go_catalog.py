from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
keys=json.loads((root/'tool/go-migrated-index.json').read_text(encoding='utf-8'))
catalog={}
for path in sorted((root/'tool/translations').glob('*.tsv')):
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.startswith('#'): continue
        key,translation=line.split('\t',1)
        source=keys[int(key)] if key.isdigit() else key.replace('\\n','\n')
        translation=translation.replace('\\n','\n')
        zh,en=(source,translation) if re.search('[\u4e00-\u9fff]',source) else (translation,source)
        assert sorted(re.findall(r'\{\d+\}',zh))==sorted(re.findall(r'\{\d+\}',en)), (key,zh,en)
        catalog[source]=[zh,en]
def dart(s): return json.dumps(s,ensure_ascii=False).replace('$',r'\$')
(root/'lib/gowallet/l10n/go_catalog.dart').write_text('// Offline presentation catalog. Never translate user data.\nconst Map<String, List<String>> goCatalog = {\n'+''.join(f'  {dart(k)}: [{dart(v[0])}, {dart(v[1])}],\n' for k,v in sorted(catalog.items()))+'};\n',encoding='utf-8')
print(f'{len(catalog)} bilingual templates')
