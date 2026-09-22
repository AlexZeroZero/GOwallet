import { build } from 'esbuild';
import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
await mkdir('dist',{recursive:true});
await build({entryPoints:['src/ui.ts'],bundle:true,format:'iife',platform:'browser',outfile:'dist/ui.js',minify:true,sourcemap:false});
await cp('src/popup.html','dist/popup.html'); await cp('src/style.css','dist/style.css'); await cp('assets','dist/assets',{recursive:true}); await cp('manifest.json','dist/manifest.json');
const html=await readFile('dist/popup.html','utf8'); await writeFile('dist/popup.html',html.replace('./ui.ts','./ui.js'));
console.log('built dist/');
