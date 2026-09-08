# Dingocoin (DINGO)

GOwallet supports native Dingocoin mainnet through third-party Electrum servers.
It does not deploy a Dingocoin full node or require a GOwallet account server.

- Default: `elecx1.dingocoin.com:3342`, TLS with certificate verification.
- Source: [GOzero node directory](https://gozero.trade/nodes/), checked 2026-09-08;
  [published upstream server list](https://github.com/GLEECBTC/coins/blob/master/electrums/DINGO).
- The directory also lists `delecx.twinkykms.com:3339` (unencrypted TCP). It was
  checked for chain consistency but is not an automatic fallback from TLS.
  Users may add compatible servers in network settings.
- Core sources: [chain parameters](https://github.com/dingocoin/dingocoin/blob/master/src/chainparams.cpp),
  [fee policy](https://github.com/dingocoin/dingocoin/blob/master/src/policy/policy.h),
  [fee calculation](https://github.com/dingocoin/dingocoin/blob/master/src/dingocoin-fees.cpp),
  [message prefix](https://github.com/dingocoin/dingocoin/blob/master/src/validation.cpp).

| Parameter | Value |
| --- | --- |
| P2PKH / P2SH / WIF | 30 / 22 / 158 |
| Extended public / private prefix | `02facafd` / `02fac398` |
| Recovery path | `m/44'/3'/0'/0/index`; change uses chain 1 |
| Precision | 8 decimals |
| Coinbase maturity | 240 blocks |
| Transaction type | Legacy, version 1; SegWit is disabled on the chain |
| Fallback fee rate | 1 DINGO/kB, matching observed public-node relay policy |
| Wallet output floor | 1 DINGO, conservatively avoiding legacy dust surcharges |

Coin type 3 is the existing DINGO BIP44 convention used in
[GLEECBTC/coins](https://github.com/GLEECBTC/coins/blob/master/coins), not a unique
SLIP-44 assignment. A BIP39 seed from a wallet with a different path or seed format
does not automatically restore the same addresses. DINGO and Dogecoin also share
address prefixes: never send DOGE to a DINGO wallet or reuse the same seed across
these chains assuming they are isolated by derivation path.

DINGO shares Dogecoin's genesis hash. Before sending wallet address queries,
GOwallet additionally hashes block 1 and checks the Core checkpoint
`594a42d8fe16382085dc982135df72cf8fcea12d34e6efd566e2f9e442e2136f`.
Missing, malformed, or wrong-chain replies fail the connection. This detects
ordinary wrong-network configuration; it is not full SPV verification or proof
that a malicious server is honest.

The logo is the published Dingocoin mark, retrieved via
`https://gozero.trade/coins/dingo.png`. Fiat pricing uses CoinGecko ID `dingocoin`
when enabled. No private keys or seeds are transmitted to these services.

独立的节点运营者负责节点服务。GOwallet 本地保存密钥并签名；节点停机、延迟或错误响应
可能影响显示与广播。可以切换兼容节点，切换节点无需迁移链上资产。
