import 'dart:convert';
import 'package:bip39/bip39.dart' as bip39;
import 'package:coinlib_flutter/coinlib_flutter.dart' as cl;
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/gowallet/custom_coin_definition.dart';
import 'package:bitfinite/gowallet/custom_coin_registry.dart';
import 'package:bitfinite/db/hive/db.dart';
import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/models/node_model.dart';
import 'package:bitfinite/services/node_service.dart';
import 'package:bitfinite/utilities/flutter_secure_storage_interface.dart';
import 'package:bitfinite/utilities/enums/derive_path_type_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'hive/hive_ce_test_utils.dart';

Map<String, dynamic> btcProfile({bool segwit = false}) => {
  'schema': 1,
  'name': 'Bitcoin custom',
  'ticker': 'BTC',
  'genesis': '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
  'decimals': 8,
  'slip44': 0,
  'p2pkh': 0,
  'p2sh': 5,
  'wif': 128,
  'bip32Public': 0x0488b21e,
  'bip32Private': 0x0488ade4,
  'segwit': segwit,
  'hrp': segwit ? 'bc' : '',
  'txVersion': 1,
  'blockTime': 600,
  'confirmations': 1,
  'coinbaseMaturity': 100,
  'dust': 546,
  'feePerKb': 1000,
  'explorer': 'https://example.org/tx/',
  'host': 'electrum.example.org',
  'port': 50002,
  'tls': true,
};

void main() {
  setUpAll(cl.loadCoinlib);
  for (final witness in [false, true]) {
    test(
      'custom Bitcoin ${witness ? "BIP84" : "BIP44"} independent address and offline signature',
      () {
        final coin = CustomElectrumCurrency(
          CustomCoinDefinition.fromJson(btcProfile(segwit: witness)),
        );
        final seed = bip39.mnemonicToSeed(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        );
        final path = coin.constructDerivePath(
          derivePathType: coin.defaultDerivePathType,
          chain: 0,
          index: 0,
        );
        final key = cl.HDPrivateKey.fromSeed(seed).derivePath(path).privateKey;
        final address = coin
            .getAddressForPublicKey(
              publicKey: key.pubkey,
              derivePathType: coin.defaultDerivePathType,
            )
            .address;
        expect(
          address.toString(),
          witness
              ? 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu'
              : '1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA',
        );
        final previous = cl.OutPoint.fromHex('1' * 64, 0);
        final tx = cl.Transaction(
          version: coin.transactionVersion,
          inputs: [
            witness
                ? cl.P2WPKHInput(prevOut: previous, publicKey: key.pubkey)
                : cl.P2PKHInput(prevOut: previous, publicKey: key.pubkey),
          ],
          outputs: [cl.Output.fromAddress(BigInt.from(100000000), address)],
        );
        final signed = witness
            ? tx.signLegacyWitness(
                inputN: 0,
                key: key,
                value: BigInt.from(101000000),
              )
            : tx.signLegacy(inputN: 0, key: key);
        expect(signed.complete, true);
        expect(cl.Transaction.fromHex(signed.toHex()).txid, signed.txid);
      },
    );
  }
  test(
    'identity survives JSON round trip and endpoint changes; chain parameters differentiate coins',
    () {
      final a = CustomCoinDefinition.fromJson(btcProfile());
      final b = CustomCoinDefinition.fromJson({
        ...btcProfile(),
        'host': 'other.example.org',
        'port': 50001,
        'tls': false,
      });
      expect(a.identifier, b.identifier);
      expect(
        CustomCoinDefinition.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(a.toJson())) as Map),
        ).identifier,
        a.identifier,
      );
      final c = CustomCoinDefinition.fromJson({...btcProfile(), 'slip44': 22});
      expect(CustomElectrumCurrency(a), isNot(CustomElectrumCurrency(c)));
      expect(
        CustomCoinRegistry.mergeProfiles([a], [b]).single.string('host'),
        a.string('host'),
      );
      expect(
        () => CustomCoinRegistry.mergeProfiles([a], [c]),
        throwsFormatException,
      );
    },
  );
  for (final bad in <Map<String, dynamic>>[
    {'slip44': 0x80000000},
    {'genesis': 'x'},
    {'decimals': 20},
    {'p2pkh': 256},
    {'p2sh': 0},
    {'bip32Public': 0x100000000},
    {'ticker': 'PEP'},
    {'feePerKb': -1},
    {'host': 'https://server.org'},
    {'explorer': 'javascript:alert(1)'},
    {'txVersion': 3},
    {'segwit': true, 'hrp': ''},
    {'privateKey': 'never accept secrets'},
    {'genesis': Scash(CryptoCurrencyNetwork.main).genesisHash},
  ]) {
    test(
      'reject unsafe profile $bad',
      () => expect(
        () => CustomCoinDefinition.fromJson({...btcProfile(), ...bad}),
        throwsFormatException,
      ),
    );
  }
  test(
    'PEP uses project chain parameters and independent public TLS nodes',
    () {
      final pep = Pepecoin(CryptoCurrencyNetwork.main);
      expect(pep.networkParams.p2pkhPrefix, 56);
      expect(pep.minCoinbaseConfirms, 240);
      expect(
        pep.constructDerivePath(
          derivePathType: DerivePathType.bip44,
          chain: 0,
          index: 0,
        ),
        "m/44'/3434'/0'/0/0",
      );
      expect(pep.defaultNode(isPrimary: true).host, 'electrum.pepeblocks.com');
      expect(pep.additionalDefaultNodes.single.host, 'electrum.pepe.tips');
      expect(pep.defaultNode(isPrimary: true).useSSL, true);
    },
  );
  group('persistent migration', () {
    setUp(() async {
      await setUpHiveCeTest();
      if (!DB.instance.hive.isAdapterRegistered(12))
        DB.instance.hive.registerAdapter(NodeModelAdapter());
      await DB.instance.hive.openBox<dynamic>(DB.boxNameDBInfo);
      await DB.instance.hive.openBox<NodeModel>(DB.boxNameNodeModels);
      CustomCoinRegistry.instance.load();
    });
    tearDown(() async {
      await DB.instance.hive.box<dynamic>(DB.boxNameDBInfo).clear();
      CustomCoinRegistry.instance.load();
      await tearDownHiveCeTest();
    });
    test(
      'profiles survive restart; encrypted backup profile list restores IDs',
      () async {
        final registry = CustomCoinRegistry.instance;
        await registry.importProfiles([btcProfile()]);
        final backup = jsonEncode(registry.exportProfiles());
        final id = registry.coins.single.identifier;
        registry.load();
        expect(AppConfig.getCryptoCurrencyFor(id)!.ticker, 'BTC');
        await DB.instance.hive.box<dynamic>(DB.boxNameDBInfo).clear();
        registry.load();
        await registry.importProfiles(jsonDecode(backup));
        expect(registry.coins.single.identifier, id);
        await expectLater(
          registry.importProfiles([
            {...btcProfile(), 'slip44': 3},
          ]),
          throwsFormatException,
        );
        expect(registry.coins.single.identifier, id);
      },
    );
    test(
      'update defaults migrates old built-in TCP without changing user node or primary preference',
      () async {
        final coin = Scash(CryptoCurrencyNetwork.main),
            service = NodeService(secureStorageInterface: FakeSecureStorage());
        final old = coin
            .defaultNode(isPrimary: false)
            .copyWith(
              host: '192.0.2.1',
              port: 50001,
              useSSL: false,
              loginName: null,
              trusted: null,
            );
        final custom = NodeModel(
          host: 'my.example.org',
          port: 55002,
          name: 'Mine',
          id: 'user-node',
          useSSL: true,
          enabled: true,
          coinName: coin.identifier,
          isFailover: true,
          isDown: false,
          torEnabled: false,
          clearnetEnabled: true,
          isPrimary: true,
        );
        await DB.instance.put<NodeModel>(
          boxName: DB.boxNameNodeModels,
          key: old.id,
          value: old,
        );
        await DB.instance.put<NodeModel>(
          boxName: DB.boxNameNodeModels,
          key: custom.id,
          value: custom,
        );
        await service.updateDefaults();
        final migrated = service.getNodeById(id: old.id)!;
        expect(migrated.host, 'scash.gozero.trade');
        expect(migrated.useSSL, true);
        expect(migrated.isPrimary, false);
        expect(service.getPrimaryNodeFor(currency: coin)!.id, custom.id);
        expect(service.getNodeById(id: custom.id)!.host, 'my.example.org');
      },
    );
  });
}
