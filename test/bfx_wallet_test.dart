import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:coinlib_flutter/coinlib_flutter.dart' as cl;
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/utilities/bfx_cashaddr.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/wallet/impl/bitfinite_wallet.dart';

Uint8List bytes(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

void main() {
  setUpAll(cl.loadCoinlib);
  final coin = Bitfinite(CryptoCurrencyNetwork.main);
  final wallet = BitfiniteWallet(CryptoCurrencyNetwork.main);
  final fixture =
      jsonDecode(File('test/fixtures/bfx_vectors.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'BFX registration and independent recovery vector preserve network identity',
    () {
      expect(AppConfig.getCryptoCurrencyFor('bitfinite'), coin);
      final path = coin.constructDerivePath(
        derivePathType: DerivePathType.bip44,
        chain: 0,
        index: 0,
      );
      expect(path, (fixture['path'] as String));
      final key = cl.HDPrivateKey.fromSeed(
        bip39.mnemonicToSeed((fixture['mnemonic'] as String)),
      ).derivePath(path).privateKey;
      expect(key.pubkey.hex, (fixture['public_key'] as String));
      final address = coin
          .getAddressForPublicKey(
            publicKey: key.pubkey,
            derivePathType: DerivePathType.bip44,
          )
          .address
          .toString();
      expect(address, (fixture['legacy'] as String));
      expect(
        wallet.convertAddressString(address),
        (fixture['cashaddr'] as String),
      );
      for (final value in [
        address,
        (fixture['cashaddr'] as String),
        (fixture['cashaddr'] as String).toUpperCase(),
        (fixture['cashaddr'] as String).split(':').last,
      ]) {
        expect(coin.validateAddress(value), isTrue);
        expect(
          coin.addressToScriptHash(address: value),
          (fixture['scripthash'] as String),
        );
        expect(wallet.normalizeAddress(value), address);
      }
      final nodes = [
        coin.defaultNode(isPrimary: true),
        ...coin.additionalDefaultNodes,
      ];
      expect(nodes.map((n) => n.host), [
        'electr.bitfinitechain.org',
        'electrum2.bitfinitechain.org',
      ]);
      expect(nodes.every((n) => n.useSSL && n.port == 443), isTrue);
    },
  );

  test(
    'BFX rejects wrong-chain, mixed-case, malformed and unsupported addresses',
    () {
      for (final address in [
        '1',
        '3invalid',
        '${(fixture['legacy'] as String)}x',
        '${(fixture['cashaddr'] as String)}x',
        'Bfx:${(fixture['cashaddr'] as String).split(':').last}',
        (fixture['foreign'] as String),
        ...(fixture['malformed'] as List<dynamic>).cast<String>(),
      ]) {
        expect(coin.validateAddress(address), isFalse, reason: address);
        expect(coin.getAddressType(address), isNull);
        expect(
          () => coin.addressToScriptHash(address: address),
          throwsFormatException,
        );
      }
      expect(
        () => BfxCashAddr.encode(hash160: Uint8List(19)),
        throwsArgumentError,
      );
      expect(
        () => BfxCashAddr.encode(hash160: Uint8List(20), type: 2),
        throwsArgumentError,
      );
      final p2sh = BfxCashAddr.encode(
        hash160: Uint8List(20),
        type: BfxCashAddr.typeP2SH,
      );
      expect(
        wallet.normalizeAddress(p2sh),
        '31h1vYVSYuKP6AhS86fbRdMw9XHieotbST',
      );
      expect(wallet.convertAddressString(wallet.normalizeAddress(p2sh)), p2sh);
    },
  );

  test('BFX BCH signing verifies against an independent FORKID digest', () {
    final key = cl.HDPrivateKey.fromSeed(
      bip39.mnemonicToSeed((fixture['mnemonic'] as String)),
    ).derivePath((fixture['path'] as String)).privateKey;
    // Same BCH builder and normalization as BCashInterface. Synthetic outpoint:
    // no network broadcast, no real funds or user secrets.
    final builder = bitbox.Bitbox.transactionBuilder(testnet: false);
    builder.setVersion(coin.transactionVersion);
    builder.addInput('11' * 32, 0);
    builder.addOutput(
      wallet.normalizeAddress((fixture['cashaddr'] as String)),
      100000000,
    );
    builder.sign(
      0,
      bitbox.ECPair.fromPrivateKey(key.data, compressed: true),
      101000000,
    );
    final signed = builder.build();
    final decoded = cl.Transaction.fromHex(signed.toHex());
    final script = decoded.inputs.single.scriptSig;
    final signature = script.sublist(1, 1 + script[0]);
    expect(signature.last, 0x41); // ALL | FORKID
    final digest = bytes((fixture['forkid_digest'] as String));
    final ecdsa = cl.ECDSASignature.fromDer(
      signature.sublist(0, signature.length - 1),
    );
    expect(ecdsa.verify(key.pubkey, digest), isTrue);
    digest[0] ^= 1;
    expect(ecdsa.verify(key.pubkey, digest), isFalse);
    expect(
      decoded.outputs.single.scriptPubKey,
      bytes((fixture['script'] as String)),
    );
    expect(decoded.outputs.single.value, BigInt.from(100000000));
    expect(decoded.isWitness, isFalse);
  });
}
