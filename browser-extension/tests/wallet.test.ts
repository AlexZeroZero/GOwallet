import { strict as assert } from 'node:assert';
import { describe,it } from 'node:test';
import { COINS } from '../src/coins.js';
import { deriveAddress } from '../src/wallet.js';
import { encryptMnemonic,decryptMnemonic } from '../src/vault.js';

const mnemonic='abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
describe('GOwallet browser wallet',()=>{
  it('keeps SCASH path/address compatible with mobile wallet',()=>assert.equal(deriveAddress(mnemonic,COINS.scash),'scash1q7r4nylj7vamdp57tkek392dxaw262thqppzchv'));
  it('derives all four supported mainnet addresses',()=>{for(const coin of Object.values(COINS)){const a=deriveAddress(mnemonic,coin);assert.ok(a.length>20);}});
  it('encrypts and rejects a wrong vault password',async()=>{const v=await encryptMnemonic(mnemonic,'correct horse battery staple');assert.equal(await decryptMnemonic(v,'correct horse battery staple'),mnemonic);await assert.rejects(()=>decryptMnemonic(v,'wrong password'));});
});
