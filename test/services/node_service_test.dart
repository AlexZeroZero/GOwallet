// TODO MWC

import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/db/hive/db.dart';
import 'package:bitfinite/models/node_model.dart';
import 'package:bitfinite/services/node_service.dart';
import 'package:bitfinite/utilities/flutter_secure_storage_interface.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';

import '../hive/hive_ce_test_utils.dart';

void main() {
  bool wasRegistered = false;
  final expectedPrimaryDefaults = AppConfig.coins
      .where((coin) => coin.identifier != 'firo')
      .map((e) => e.defaultNode(isPrimary: true))
      .toList(growable: false);
  final expectedDefaultNodeCount =
      expectedPrimaryDefaults.length +
      // Some coins (e.g. BitFinite) seed extra failover nodes via
      // additionalDefaultNodes on top of their primary defaultNode.
      AppConfig.coins
          .where((coin) => coin.identifier != 'firo')
          .fold<int>(
            0,
            (sum, coin) => sum + coin.additionalDefaultNodes.length,
          ) +
      (AppConfig.coins.any((e) => e.identifier == 'firo') ? 4 : 0);

  setUp(() async {
    await setUpHiveCeTest();
    if (!wasRegistered) {
      wasRegistered = true;
      DB.instance.hive.registerAdapter(NodeModelAdapter());
    }
    await DB.instance.hive.openBox<NodeModel>(DB.boxNameNodeModels);
    // await DB.instance.hive.openBox<NodeModel>(DB.boxNamePrimaryNodes);
  });

  group("Empty nodes DB tests", () {
    test("getPrimaryNodeFor", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final node = service.getPrimaryNodeFor(
        currency: Bitcoin(CryptoCurrencyNetwork.main),
      );
      expect(node, null);
      expect(fakeStore.interactions, 0);
    });

    test("setPrimaryNodeFor", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final node = service.getPrimaryNodeFor(
        currency: Bitcoin(CryptoCurrencyNetwork.main),
      );
      expect(node, null);
      final node1 = NodeModel(
        host: "host",
        port: 42,
        name: "btcnode",
        id: "pnodeID",
        useSSL: true,
        enabled: true,
        coinName: "bitcoin",
        isFailover: true,
        isDown: false,
        torEnabled: true,
        clearnetEnabled: true,
        isPrimary: true,
      );
      await service.setPrimaryNodeFor(
        coin: Bitcoin(CryptoCurrencyNetwork.main),
        node: node1,
        shouldNotifyListeners: true,
      );

      expect(
        service
            .getPrimaryNodeFor(currency: Bitcoin(CryptoCurrencyNetwork.main))
            .toString(),
        node1.toString(),
      );
      expect(fakeStore.interactions, 0);
    });

    test("getNodesFor", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final nodes = service.getNodesFor(Bitcoin(CryptoCurrencyNetwork.main));
      expect(nodes.isEmpty, true);
      expect(fakeStore.interactions, 0);
    });

    test("get primary nodes", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final nodes = service.primaryNodes;
      expect(nodes.isEmpty, true);
      expect(fakeStore.interactions, 0);
    });

    test("get nodes", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final nodes = service.nodes;
      expect(nodes.isEmpty, true);
      expect(fakeStore.interactions, 0);
    });

    test("get failover nodes", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final nodes = service.failoverNodesFor(
        currency: Bitcoin(CryptoCurrencyNetwork.main),
      );
      expect(nodes.isEmpty, true);
      expect(fakeStore.interactions, 0);
    });

    test("get non existing getNodeById", () {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final node = service.getNodeById(id: "Some ID");
      expect(node, null);
      expect(fakeStore.interactions, 0);
    });

    test("updateDefaults", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      await service.updateDefaults();
      expect(service.nodes.length, expectedDefaultNodeCount);
      expect(fakeStore.interactions, 0);
    });
  });

  group("Defaults populated tests", () {
    final nodeA = NodeModel(
      host: "host1",
      port: 421,
      name: "btcnode",
      id: "pnodeID1",
      useSSL: true,
      enabled: true,
      coinName: "bitcoin",
      isFailover: true,
      isDown: false,
      torEnabled: true,
      clearnetEnabled: true,
      isPrimary: true,
    );
    final nodeB = NodeModel(
      host: "host2",
      port: 422,
      name: "btcnode",
      id: "pnodeID2",
      useSSL: true,
      enabled: true,
      // Supported-coin identifier: NodeService.delete resolves the node's coin
      // via getCryptoCurrencyByPrettyName, which throws for coins the fork
      // dropped (e.g. monero).
      coinName: "bitfinite",
      isFailover: true,
      isDown: false,
      torEnabled: true,
      clearnetEnabled: true,
      isPrimary: true,
    );
    final nodeC = NodeModel(
      host: "host3",
      port: 423,
      name: "btcnode",
      id: "pnodeID3",
      useSSL: true,
      enabled: true,
      coinName: "epicCash",
      isFailover: true,
      isDown: false,
      torEnabled: true,
      clearnetEnabled: true,
      isPrimary: true,
    );

    setUp(() async {
      await NodeService(
        secureStorageInterface: FakeSecureStorage(),
      ).updateDefaults();
    });

    test("setPrimaryNodeFor and getPrimaryNodeFor", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      expect(
        service
            .getPrimaryNodeFor(currency: Bitfinite(CryptoCurrencyNetwork.main))
            ?.toString(),
        Bitfinite(
          CryptoCurrencyNetwork.main,
        ).defaultNode(isPrimary: true).toString(),
      );
      await service.setPrimaryNodeFor(
        coin: Bitfinite(CryptoCurrencyNetwork.main),
        node: Bitfinite(CryptoCurrencyNetwork.main).defaultNode(isPrimary: true),
      );
      expect(
        service
            .getPrimaryNodeFor(currency: Bitfinite(CryptoCurrencyNetwork.main))
            .toString(),
        Bitfinite(
          CryptoCurrencyNetwork.main,
        ).defaultNode(isPrimary: true).toString(),
      );
      expect(fakeStore.interactions, 0);
    });

    test("get primary nodes", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      // Single-coin app: set the primary for each supported coin's default.
      for (final coin in AppConfig.coins) {
        await service.setPrimaryNodeFor(
          coin: coin,
          node: coin.defaultNode(isPrimary: true),
        );
      }
      final primaryNodes = service.primaryNodes;
      final expectedPrimaryNodes = [...expectedPrimaryDefaults]
        ..sort((a, b) => a.id.compareTo(b.id));
      primaryNodes.sort((a, b) => a.id.compareTo(b.id));

      expect(primaryNodes.length, expectedPrimaryNodes.length);
      expect(primaryNodes.toString(), expectedPrimaryNodes.toString());
      expect(fakeStore.interactions, 0);
    });

    test("get nodes", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      final nodes = service.nodes;
      final defaultIds = expectedPrimaryDefaults.map((e) => e.id).toSet();
      final extraFiroIds = service.nodes
          .where((node) => node.id.startsWith('not_a_real_default_but_temp_'))
          .map((node) => node.id)
          .toSet();

      expect(nodes.length, expectedDefaultNodeCount);
      expect(nodes.map((node) => node.id).toSet(), containsAll(defaultIds));
      expect(
        extraFiroIds.length,
        AppConfig.coins.any((e) => e.identifier == 'firo') ? 4 : 0,
      );
      expect(fakeStore.interactions, 0);
    });

    test("add a node without a password", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      await service.save(nodeA, null, true);
      expect(service.nodes.length, expectedDefaultNodeCount + 1);
      expect(fakeStore.interactions, 1);
    });

    test("add a node with a password", () async {
      final fakeStore = FakeSecureStorage();
      final service = NodeService(secureStorageInterface: fakeStore);
      await service.save(nodeA, "some password", true);
      expect(service.nodes.length, expectedDefaultNodeCount + 1);
      expect(fakeStore.interactions, 1);
      expect(fakeStore.writes, 1);
    });

    group("Additional nodes in storage tests", () {
      setUp(() async {
        await DB.instance.put<NodeModel>(
          boxName: DB.boxNameNodeModels,
          key: nodeA.id,
          value: nodeA,
        );
        await DB.instance.put<NodeModel>(
          boxName: DB.boxNameNodeModels,
          key: nodeB.id,
          value: nodeB,
        );
        await DB.instance.put<NodeModel>(
          boxName: DB.boxNameNodeModels,
          key: nodeC.id,
          value: nodeC,
        );
      });

      test("edit a node with a password", () async {
        final fakeStore = FakeSecureStorage();
        final service = NodeService(secureStorageInterface: fakeStore);
        final currentLength = service.nodes.length;

        final editedNode = nodeA.copyWith(
          name: "Some new kind of name",
          loginName: null,
          trusted: null,
        );

        await service.save(editedNode, "123456", true);

        expect(service.nodes.length, currentLength);

        expect(
          service.getNodeById(id: nodeA.id).toString(),
          editedNode.toString(),
        );
        expect(
          (await service.getNodeById(id: nodeA.id)!.getPassword(fakeStore))!,
          "123456",
        );

        expect(fakeStore.interactions, 2);
        expect(fakeStore.reads, 1);
        expect(fakeStore.writes, 1);
      });

      test("delete a node", () async {
        final fakeStore = FakeSecureStorage();
        final service = NodeService(secureStorageInterface: fakeStore);

        await service.delete(nodeB.id, true);

        expect(service.nodes.length, expectedDefaultNodeCount + 2);
        expect(
          service.nodes.where((element) => element.id == nodeB.id).length,
          0,
        );

        expect(fakeStore.interactions, 1);
        expect(fakeStore.deletes, 1);
      });

      test("set enabled", () async {
        final fakeStore = FakeSecureStorage();
        final service = NodeService(secureStorageInterface: fakeStore);

        final preString = nodeC.toString();

        await service.setEnabledState(nodeC.id, false, true);

        final updatedNode = service.getNodeById(id: nodeC.id);

        expect(preString == updatedNode.toString(), false);
        expect(updatedNode!.enabled, false);

        expect(fakeStore.interactions, 0);
      });
    });
  });

  tearDown(() async {
    await tearDownHiveCeTest();
  });
}
