Source: cypherstack/coinlib commit a3c972ce0b71b45afe17576d39831fe370ce7ce7, coinlib package.

Only patch: lib/src/tx/transaction.dart rewinds one byte after the non-witness marker probe, not two. Without this correction a signed P2PKH transaction changes its txid when decoded. Regression: test/scash_shic_signing_test.dart. Original license retained.
