"""Independent BIP32/address/BCH-FORKID fixtures using PUBLIC test keys only."""
import hashlib
import hmac
import json
from pathlib import Path
from generate_wallet_vectors import pub, hash160, base58, N


def sha256d(b):
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def cashaddr(payload, prefix='bfx'):
    bits = ''.join(f'{b:08b}' for b in payload)
    bits += '0' * (-len(bits) % 5)
    words = [int(bits[i:i+5], 2) for i in range(0, len(bits), 5)]
    generators = [0x98f2bc8e61, 0x79b76d99e2, 0xf33e5fb3c4, 0xae2eabe2a8, 0x1e4f43e470]
    chk = 1
    for d in [ord(c) & 31 for c in prefix] + [0] + words + [0]*8:
        top = chk >> 35
        chk = ((chk & 0x07ffffffff) << 5) ^ d
        for i, g in enumerate(generators):
            if (top >> i) & 1:
                chk ^= g
    chk ^= 1
    words += [(chk >> (5 * (7-i))) & 31 for i in range(8)]
    return prefix + ':' + ''.join('fpzry9x8gq2tvdw0s3jn54khce6mua7l'[v] for v in words)


def main():
    mnemonic = ' '.join(['abandon'] * 11 + ['about'])
    seed = hashlib.pbkdf2_hmac('sha512', mnemonic.encode(), b'mnemonic', 2048)
    master = hmac.new(b'Bitcoin seed', seed, hashlib.sha512).digest()
    key, chain = int.from_bytes(master[:32], 'big'), master[32:]
    for index in [44+2**31, 9116+2**31, 2**31, 0, 0]:
        data = (b'\0'+key.to_bytes(32, 'big') if index >= 2**31 else pub(key)) + index.to_bytes(4, 'big')
        child = hmac.new(chain, data, hashlib.sha512).digest()
        key, chain = (key + int.from_bytes(child[:32], 'big')) % N, child[32:]
    pk = pub(key)
    pkh = hash160(pk)
    script = b'\x76\xa9\x14' + pkh + b'\x88\xac'
    outpoint = bytes.fromhex('11'*32) + bytes(4)
    sequence = bytes.fromhex('ffffffff')
    output = (100000000).to_bytes(8, 'little') + bytes([len(script)]) + script
    preimage = ((2).to_bytes(4, 'little') + sha256d(outpoint) + sha256d(sequence)
                + outpoint + bytes([len(script)]) + script + (101000000).to_bytes(8, 'little')
                + sequence + sha256d(output) + bytes(4) + (0x41).to_bytes(4, 'little'))
    case = dict(mnemonic=mnemonic, path="m/44'/9116'/0'/0/0", public_key=pk.hex(),
                legacy=base58(b'\0'+pkh), cashaddr=cashaddr(b'\0'+pkh),
                script=script.hex(), scripthash=hashlib.sha256(script).digest()[::-1].hex(),
                forkid_digest=sha256d(preimage).hex(),
                malformed=[cashaddr(bytes([v])+pkh) for v in (1, 16, 128)],
                foreign=cashaddr(b'\0'+pkh, 'bfxtest'))
    target = Path(__file__).resolve().parents[1] / 'test/fixtures/bfx_vectors.json'
    target.write_text(json.dumps(case, indent=2)+'\n')
    print(case['cashaddr'])


if __name__ == '__main__':
    main()
