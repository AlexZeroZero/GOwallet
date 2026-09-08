import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as cl;
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/crypto_currency/interfaces/electrumx_currency_interface.dart';

void main() {
  setUpAll(cl.loadCoinlib);
  final fixture =
      jsonDecode(
            File('test/fixtures/scash_shic_vectors.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final item in fixture['cases'] as List) {
    final v = item as Map<String, dynamic>;
    final ElectrumXCurrencyInterface coin = switch(v['coin']) {
      'scash' => Scash(CryptoCurrencyNetwork.main),
      'shibacoin' => Shibacoin(CryptoCurrencyNetwork.main),
      'pepecoin' => Pepecoin(CryptoCurrencyNetwork.main),
      'dingocoin' => Dingocoin(CryptoCurrencyNetwork.main),
      _ => throw StateError('Unknown fixture currency'),
    };
    test(
      '${v['path']}: independent address vectors and offline transaction signing',
      () {
        final seed = bip39.mnemonicToSeed(fixture['mnemonic'] as String);
        final key = cl.HDPrivateKey.fromSeed(
          seed,
        ).derivePath(v['path'] as String).privateKey;
        expect(key.pubkey.hex, v['public_key']);
        final result = coin.getAddressForPublicKey(
          publicKey: key.pubkey,
          derivePathType: v['purpose'] == 84
              ? DerivePathType.bip84
              : DerivePathType.bip44,
        );
        expect(result.address.toString(), v['address']);
        expect(coin.validateAddress(v['address'] as String), true);
        expect(
          coin.addressToScriptHash(address: v['address'] as String),
          v['scripthash'],
        );
        expect(coin.validateAddress('${v['address']}x'), false);
        final digest = Uint8List.fromList(List.generate(32, (i) => i));
        final signature = cl.ECDSASignature.sign(key, digest);
        expect(signature.verify(key.pubkey, digest), true);
        digest[0] ^= 1;
        expect(signature.verify(key.pubkey, digest), false);

        // A synthetic outpoint: this transaction is never sent to any network.
        final previous = cl.OutPoint.fromHex(List.filled(64, '1').join(), 0);
        final cl.Input input = v['purpose'] == 84
            ? cl.P2WPKHInput(prevOut: previous, publicKey: key.pubkey)
            : cl.P2PKHInput(prevOut: previous, publicKey: key.pubkey);
        final unsigned = cl.Transaction(
          version: coin.transactionVersion,
          inputs: [input],
          outputs: [
            cl.Output.fromAddress(BigInt.from(100000000), result.address),
          ],
        );
        final signed = v['purpose'] == 84
            ? unsigned.signLegacyWitness(
                inputN: 0,
                key: key,
                value: BigInt.from(101000000),
              )
            : unsigned.signLegacy(inputN: 0, key: key);
        expect(signed.complete, true);
        expect(signed.isWitness, v['purpose'] == 84);
        final decoded = cl.Transaction.fromHex(signed.toHex());
        expect(decoded.txid, signed.txid);
        expect(decoded.outputs.single.value, BigInt.from(100000000));
        expect(
          decoded.outputs.single.scriptPubKey,
          result.address.program.script.compiled,
        );
      },
    );
  }
}
