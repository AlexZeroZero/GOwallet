import 'dart:io';

import 'package:electrum_adapter/electrum_adapter.dart';

import '../../app_config.dart';
import '../../electrumx_rpc/verify_network.dart';
import '../../services/event_bus/events/global/tor_connection_status_changed_event.dart';
import '../../services/tor_service.dart';
import '../logger.dart';
import '../prefs.dart';

Future<bool> checkElectrumServer({
  required String host,
  required int port,
  required bool useSSL,
  Prefs? overridePrefs,
  TorService? overrideTorService,
  String? expectedGenesis,
}) async {
  final _prefs = overridePrefs ?? Prefs.instance;

  ({InternetAddress host, int port})? proxyInfo;

  ElectrumClient? client;
  try {
    if (AppConfig.hasFeature(AppFeature.tor) && _prefs.useTor) {
      final _torService = overrideTorService ?? TorService.sharedInstance;
      // But Tor isn't running...
      if (_torService.status != TorConnectionStatus.connected) {
        // And the killswitch isn't set...
        if (!_prefs.torKillSwitch) {
          // Then we'll just proceed and connect to ElectrumX through clearnet at the bottom of this function.
          Logging.instance.w(
            "Tor preference set but Tor is not enabled, killswitch not set, connecting to Electrum adapter through clearnet",
          );
        } else {
          // ... But if the killswitch is set, then we throw an exception.
          throw Exception(
            "Tor preference and killswitch set but Tor is not enabled, not connecting to Electrum adapter",
          );
          // TODO [prio=low]: Try to start Tor.
        }
      } else {
        // Get the proxy info from the TorService.
        proxyInfo = _torService.getProxyInfo();
      }
    }

    client =
        await ElectrumClient.connect(
          host: host,
          port: port,
          useSSL: useSSL && !host.endsWith('.onion'),
          proxyInfo: proxyInfo,
          acceptUnverified: false,
        ).timeout(
          Duration(seconds: (proxyInfo == null ? 5 : 30)),
          onTimeout: () => throw Exception(
            "The checkElectrumServer connect() call timed out.",
          ),
        );

    // BFX: electr-bfx (romanz/electrs) rejects a param-less server.version with
    // "invalid params". Send the same handshake params as the live client
    // (electrumx_client.dart) so a working server actually passes the test.
    await client
        .request('server.version', [
          AppConfig.appName,
          ['1.4', '1.5'],
        ])
        .timeout(Duration(seconds: (proxyInfo == null ? 5 : 30)));

    if (expectedGenesis != null) {
      final features = await client.request('server.features', <dynamic>[]).timeout(const Duration(seconds: 10));
      verifyElectrumNetwork(features, expectedGenesis);
    }
    return true;
  } catch (e, s) {
    Logging.instance.e("$e\n$s", error: e, stackTrace: s);
    return false;
  } finally {
    await client?.close();
  }
}
