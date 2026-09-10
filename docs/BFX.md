# BitFinite (BFX)

GOwallet 1.0.4 adds BFX mainnet to the built-in coin list. It uses the existing
BFX wallet implementation with stricter address validation. BFX is a separate
coin project; GOwallet's app identity remains GOwallet.

## Public endpoints

Listed at <https://gozero.trade/nodes/> and <https://bitfinitechain.org/docs>:

- Primary: `electr.bitfinitechain.org:443`, TLS.
- Backup: `electrum2.bitfinitechain.org:443`, TLS.

These are third-party, raw Electrum-compatible TCP/TLS services, not HTTPS APIs.
GOwallet negotiates protocols 1.4–1.5, validates the TLS certificate and checks
the chain's genesis hash before accepting the connection. Users may configure
their own compatible endpoint in network settings. GOwallet does not operate
these BFX nodes, and node availability is outside the app's control.

## Parameters and compatibility

Verified against [BitFinite Core](https://github.com/bitfinitechain/bitfinite-core/blob/master/src/chainparams.cpp)
and its [cashaddr codec](https://github.com/bitfinitechain/bitfinite-core/blob/master/src/cashaddr.cpp):

- Genesis: `000000000900096d5b0f4a3489f919362f12fce06524e15074c3cd3c19aeabea`.
- 8 decimal places; legacy BIP44 derivation `m/44'/9116'/0'/0/index`.
- Base58 P2PKH/P2SH/WIF prefixes: 0 / 5 / 128.
- Extended public/private prefixes: `0488b21e` / `0488ade4`.
- BFX cashaddr prefix `bfx`, custom alphabet `fpzry9x8gq2tvdw0s3jn54khce6mua7l`.
- P2PKH and P2SH 160-bit destinations supported. Checksum-valid uppercase or
  prefixless cashaddr is supported; mixed case, wrong network, unsupported
  type/size and malformed Base58 are rejected.
- BCH-style `SIGHASH_ALL | SIGHASH_FORKID` (0x41), transaction version 2.
- No SegWit, CashTokens UI or testnet support is advertised. Recovery requires
  the same mnemonic, passphrase and derivation convention; wallets using a
  different account/path do not automatically map to this default.
- No market-price mapping is invented for BFX; unavailable quotes remain unknown.

## Test data and artwork

`tool/generate_bfx_vectors.py` independently generates the recovery and FORKID
digest fixtures. `test/bfx_wallet_test.dart` checks address/script equivalence,
rejects malformed and wrong-network destinations, and verifies an offline BCH
signature against the independent digest. `test/scash_shic_tcp_live_test.dart`
has opt-in primary and backup checks using the actual wallet client.

The fixture mnemonic is **public test data**. Never fund its addresses. These
checks do not send real-fund transactions or constitute an independent audit.

BFX coin artwork is the unmodified project image from
<https://bitfinitechain.org/logo.png>, retrieved 2026-09-10. It is used only to
identify BFX in the coin list and wallet pages, not as GOwallet app branding.

