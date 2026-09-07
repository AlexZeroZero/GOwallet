"""Independent BIP32/address vectors using only Python's standard library.

The all-zero BIP39 mnemonic is public test data, never a funded wallet.
"""
import hashlib
import hmac
import json
from pathlib import Path

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)


def add(a, b):
    if a is None:
        return b
    if b is None:
        return a
    x, y = a
    u, v = b
    if x == u and (y + v) % P == 0:
        return None
    slope = ((3*x*x) * pow(2*y, -1, P) if a == b else (v-y)*pow(u-x, -1, P)) % P
    z = (slope*slope-x-u) % P
    return z, (slope*(x-z)-y) % P


def pub(k):
    point, acc = G, None
    while k:
        if k & 1:
            acc = add(acc, point)
        point = add(point, point)
        k >>= 1
    x, y = acc
    return bytes([2+(y & 1)]) + x.to_bytes(32, 'big')


def hash160(b):
    return hashlib.new('ripemd160', hashlib.sha256(b).digest()).digest()


def base58(b):
    raw = b + hashlib.sha256(hashlib.sha256(b).digest()).digest()[:4]
    n, out = int.from_bytes(raw, 'big'), ''
    while n:
        n, i = divmod(n, 58)
        out = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'[i] + out
    return '1' * (len(raw)-len(raw.lstrip(b'\0'))) + out


def segwit(hrp, payload):
    acc, bits, words = 0, 0, [0]
    for value in payload:
        acc = acc << 8 | value
        bits += 8
        while bits >= 5:
            bits -= 5
            words.append((acc >> bits) & 31)
    if bits:
        words.append((acc << (5-bits)) & 31)
    values = [ord(c) >> 5 for c in hrp] + [0] + [ord(c) & 31 for c in hrp] + words + [0]*6
    chk = 1
    for value in values:
        top = chk >> 25
        chk = (chk & 0x1ffffff) << 5 ^ value
        for i, gen in enumerate([0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]):
            if (top >> i) & 1:
                chk ^= gen
    chk ^= 1
    words += [(chk >> (5*(5-i))) & 31 for i in range(6)]
    return hrp + '1' + ''.join('qpzry9x8gf2tvdw0s3jn54khce6mua7l'[i] for i in words)


def main():
    mnemonic = ' '.join(['abandon']*11 + ['about'])
    seed = hashlib.pbkdf2_hmac('sha512', mnemonic.encode(), b'mnemonic', 2048)
    master = hmac.new(b'Bitcoin seed', seed, hashlib.sha512).digest()
    cases = []
    for coin, purpose, coin_type in [('scash', 84, 805), ('scash', 44, 805), ('shibacoin', 44, 4474), ('pepecoin', 44, 3434)]:
        key, chain = int.from_bytes(master[:32], 'big'), master[32:]
        path = [purpose+2**31, coin_type+2**31, 2**31, 0, 0]
        for index in path:
            data = (b'\0'+key.to_bytes(32, 'big') if index >= 2**31 else pub(key)) + index.to_bytes(4, 'big')
            value = hmac.new(chain, data, hashlib.sha512).digest()
            key = (key+int.from_bytes(value[:32], 'big')) % N
            chain = value[32:]
        public = pub(key)
        pkhash = hash160(public)
        address = segwit('scash', pkhash) if purpose == 84 else base58(bytes([{'scash': 0, 'shibacoin': 63, 'pepecoin': 56}[coin]])+pkhash)
        script = b'\0\x14'+pkhash if purpose == 84 else b'\x76\xa9\x14'+pkhash+b'\x88\xac'
        cases.append({'coin': coin, 'purpose': purpose, 'path': f"m/{purpose}'/{coin_type}'/0'/0/0",
                      'public_key': public.hex(), 'address': address,
                      'scripthash': hashlib.sha256(script).digest()[::-1].hex()})
    target = Path(__file__).resolve().parents[1] / 'test/fixtures/scash_shic_vectors.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({'mnemonic': mnemonic, 'cases': cases}, indent=2)+'\n', encoding='utf-8')
    print(target)


if __name__ == '__main__':
    main()
