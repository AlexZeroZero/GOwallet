import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:bitfinite/electrumx_rpc/client_manager.dart';
import 'package:bitfinite/electrumx_rpc/electrumx_client.dart';
import 'package:bitfinite/utilities/logger.dart';
import 'package:bitfinite/utilities/tor_plain_net_option_enum.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'electrumx_test.dart' show MockPrefs;

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_ELECTRUM');
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('wallet_tcp_test_');
    await Logging.instance.initialize(dir.path, level: Level.off);
  });
  ElectrumXClient connect(CryptoCurrency coin, int port, {String? host}) => ElectrumXClient(
    host: host ?? coin.defaultNode(isPrimary: true).host,
    port: port,
    useSSL: true,
    prefs: MockPrefs(),
    failovers: [],
    cryptoCurrency: coin,
    netType: TorPlainNetworkOption.both,
    globalEventBusForTesting: EventBus(),
    connectionTimeoutForSpecialCaseJsonRPCClients: const Duration(seconds: 30),
  );

  for (final coin in [
    Scash(CryptoCurrencyNetwork.main),
    Shibacoin(CryptoCurrencyNetwork.main),
    Pepecoin(CryptoCurrencyNetwork.main),
  ]) {
    test(
      '${coin.ticker}: real wallet client TLS handshake, fees and history',
      () async {
        final client = connect(coin, coin.defaultNode(isPrimary: true).port!);
        try {
          final features = await client.getServerFeatures();
          expect(features['genesis_hash'], coin.genesisHash);
          final tip = await client.request(
            command: 'blockchain.headers.subscribe',
          );
          expect(tip['height'], greaterThan(0));
          expect(
            (tip['hex'] as String).length,
            coin is Scash ? 224 : greaterThanOrEqualTo(160),
          );
          expect(
            (await client.estimateFee(blocks: 6)).toDouble(),
            greaterThan(0),
          );
          final hash = coin is Shibacoin
              ? '2bc50c7105bd8f792f0f9a08e56ca9ca48107c0f7560a5cd581ba0bfc59d2ae9'
              : List.filled(64, '0').join();
          final history = await client.request(
            command: 'blockchain.scripthash.get_history',
            args: [hash],
          );
          expect(history, isA<List>());
          if (coin is Shibacoin) expect(history, isNotEmpty);
          final utxos = await client.request(
            command: 'blockchain.scripthash.listunspent',
            args: [hash],
          );
          expect(utxos, isA<List>());
          final balance = await client.request(
            command: 'blockchain.scripthash.get_balance',
            args: [hash],
          );
          expect(balance['confirmed'], isA<int>());
          // No broadcast calls or private keys are used by these live checks.
          print(
            '${coin.ticker}: TLS PASS, indexed height ${tip['height']}, history ${history.length}',
          );
        } finally {
          await ClientManager.sharedInstance.remove(cryptoCurrency: coin);
        }
      },
      skip: !live,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  test(
    'actual SHIC endpoint rejects a SCASH wallet before registration',
    () async {
      final scash = Scash(CryptoCurrencyNetwork.main);
      final client = connect(scash, 50012, host: 'shic.gozero.trade');
      await expectLater(client.getServerFeatures(), throwsStateError);
      expect(client.getElectrumAdapter(), isNull);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
