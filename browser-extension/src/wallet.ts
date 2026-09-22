import { HDKey } from '@scure/bip32';
import { mnemonicToSeedSync, generateMnemonic, validateMnemonic } from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english.js';
import type { Coin } from './coins.js';
import { p2pkhAddress, segwitAddress, p2pkhScript, electrumScriptHash, hash160 } from './encoding.js';

export function newMnemonic(){return generateMnemonic(wordlist,128);}
export function validMnemonic(m:string){return validateMnemonic(m.trim(),wordlist);}
export function derive(seedMnemonic:string,coin:Coin,index=0,change=0){
  const seed=mnemonicToSeedSync(seedMnemonic,undefined);
  const root=HDKey.fromMasterSeed(seed);
  const purpose=coin.bech32?'84': '44';
  const key=root.derive(`m/${purpose}'/${coin.slip44}'/0'/${change}/${index}`);
  if(!key.publicKey) throw Error('key derivation failed');
  const address=coin.bech32 ? segwitAddress(coin.bech32,0,hash160(key.publicKey)) : p2pkhAddress(coin.p2pkh,key.publicKey);
  const script=coin.bech32 ? Uint8Array.of(0,20,...hash160(key.publicKey)) : p2pkhScript(key.publicKey);
  return {key,address,publicKey:key.publicKey,scriptHash:electrumScriptHash(script)};
}
export function deriveAddress(mnemonic:string,coin:Coin){return derive(mnemonic,coin).address;}
export { type HDKey };
