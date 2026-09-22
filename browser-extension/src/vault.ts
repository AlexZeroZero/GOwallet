const STORE='gowallet-vault-v1';
const te=new TextEncoder(),td=new TextDecoder();
async function key(password:string,salt:Uint8Array){const base=await crypto.subtle.importKey('raw',te.encode(password) as BufferSource,'PBKDF2',false,['deriveKey']);return crypto.subtle.deriveKey({name:'PBKDF2',salt:salt as BufferSource,iterations:310000,hash:'SHA-256'},base,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);}
function b64(a:ArrayBuffer|Uint8Array){return btoa(String.fromCharCode(...new Uint8Array(a)));}
function unb64(s:string){return Uint8Array.from(atob(s),c=>c.charCodeAt(0));}
export async function encryptMnemonic(mnemonic:string,password:string){const salt=crypto.getRandomValues(new Uint8Array(16)),iv=crypto.getRandomValues(new Uint8Array(12));const k=await key(password,salt);const ct=await crypto.subtle.encrypt({name:'AES-GCM',iv},k,te.encode(mnemonic));return {salt:b64(salt),iv:b64(iv),ciphertext:b64(ct)};}
export async function decryptMnemonic(v:{salt:string,iv:string,ciphertext:string},password:string){const k=await key(password,unb64(v.salt));const pt=await crypto.subtle.decrypt({name:'AES-GCM',iv:unb64(v.iv)},k,unb64(v.ciphertext));return td.decode(pt);}
export async function saveVault(mnemonic:string,password:string){await chrome.storage.local.set({[STORE]:await encryptMnemonic(mnemonic,password)});}
export async function loadVault(password:string){const x=await chrome.storage.local.get(STORE);if(!x[STORE])return null;return decryptMnemonic(x[STORE],password);}
export async function hasVault(){return Boolean((await chrome.storage.local.get(STORE))[STORE]);}
