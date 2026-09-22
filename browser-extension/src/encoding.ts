import { sha256 } from '@noble/hashes/sha2.js';
import { ripemd160 } from '@noble/hashes/legacy.js';

const ALPHABET='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
export function bytesToHex(a: Uint8Array){return [...a].map(x=>x.toString(16).padStart(2,'0')).join('');}
export function hexToBytes(s:string){if(!/^[0-9a-f]*$/i.test(s)||s.length%2) throw Error('invalid hex'); return Uint8Array.from(s.match(/../g)||[],x=>parseInt(x,16));}
export function hash160(a:Uint8Array){return ripemd160(sha256(a));}
export function doubleSha256(a:Uint8Array){return sha256(sha256(a));}
export function base58Encode(bytes:Uint8Array){let n=BigInt('0x'+(bytesToHex(bytes)||'0')), out=''; while(n){const r=Number(n%58n);out=ALPHABET[r]+out;n/=58n;} for(const b of bytes){if(b!==0)break;out='1'+out;} return out||'1';}
export function base58Check(version:number,payload:Uint8Array){const body=Uint8Array.of(version,...payload);return base58Encode(Uint8Array.of(...body,...doubleSha256(body).slice(0,4)));}
const BECH='qpzry9x8gf2tvdw0s3jn54khce6mua7l';
function polymod(v:number[]){let c=1;const g=[0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3];for(const x of v){const top=c>>>25;c=((c&0x1ffffff)<<5)^x;for(let i=0;i<5;i++)if((top>>>i)&1)c^=g[i];}return c>>>0;}
function expand(s:string){return [...s].map(c=>c.charCodeAt(0)>>5).concat([0],...[...s].map(c=>c.charCodeAt(0)&31));}
function convert(data:number[],from:number,to:number,pad=true){let acc=0,bits=0,out:number[]=[];for(const v of data){acc=(acc<<from)|v;bits+=from;while(bits>=to){bits-=to;out.push((acc>>bits)&((1<<to)-1));}}if(pad&&bits)out.push((acc<<(to-bits))&((1<<to)-1));return out;}
export function segwitAddress(hrp:string,version:number,program:Uint8Array){const data=[version,...convert([...program],8,5)];const pm=polymod(expand(hrp).concat(data,[0,0,0,0,0,0]))^1;const checksum=Array.from({length:6},(_,i)=>(pm>>5*(5-i))&31);return hrp+'1'+data.concat(checksum).map(x=>BECH[x]).join('');}
export function p2pkhAddress(version:number,pub:Uint8Array){return base58Check(version,hash160(pub));}
export function p2pkhScript(pub:Uint8Array){return Uint8Array.of(0x76,0xa9,20,...hash160(pub),0x88,0xac);}
export function electrumScriptHash(script:Uint8Array){return bytesToHex(Uint8Array.from(sha256(script)).reverse());}
export function formatAmount(value:bigint,decimals=8){const neg=value<0n?'−':'';const n=neg? -value:value;const s=n.toString().padStart(decimals+1,'0');return neg+s.slice(0,-decimals)+'.'+s.slice(-decimals).replace(/0+$/,'').replace(/\.$/,'');}
