/// An Electrum client for RavenCoin.
///
/// Connects with https://github.com/Electrum-RVN-SIG/electrumx-ravencoin
library electrum_adapter;

import 'dart:async';
import 'dart:io';

import 'package:electrum_adapter/client/subscribing_client.dart';
import 'package:electrum_adapter/connect.dart' as conn;
import 'package:electrum_adapter/methods/shared.dart';
import 'package:electrum_adapter/methods/specific/raven/server/version.dart';
import 'package:stream_channel/stream_channel.dart';

export 'connect.dart';
export 'methods/shared.dart';
export 'methods/specific/raven/asset/addresses.dart';
export 'methods/specific/raven/asset/assets.dart';
export 'methods/specific/raven/asset/meta.dart';
export 'methods/specific/raven/scripthash/balance.dart';
export 'methods/specific/raven/scripthash/history.dart';
export 'methods/specific/raven/scripthash/unspent.dart';
export 'methods/specific/raven/server/stats.dart';
export 'methods/specific/raven/server/version.dart';
export 'methods/specific/raven/transaction/fee.dart';
export 'methods/specific/raven/transaction/get.dart';
export 'methods/specific/raven/transaction/memo.dart';
export 'subscriptions/shared.dart';
export 'subscriptions/specific/raven/subscribe_asset.dart';

class Header {
  String hex;
  int height;
  Header(this.hex, this.height);
}

/// Methods on RavenElectrumClient are defined in the `methods` directory.
/// See https://electrumx-ravencoin.readthedocs.io/en/latest/protocol-methods.html
class ElectrumClient extends SubscribingClient {
  ElectrumClient(StreamChannel<dynamic> channel, String host, int port,
      bool useSSL, ({InternetAddress host, int port})? proxyInfo)
      : this.host = host,
        this.port = port,
        this.useSSL = useSSL,
        this.proxyInfo = proxyInfo,
        super(channel);
  late final String host;
  late final int port;
  late final bool useSSL;
  late final ({InternetAddress host, int port})? proxyInfo;

  static Future<ElectrumClient> connect({
    required String host,
    required int port,
    Duration connectionTimeout = conn.connectionTimeout,
    Duration aliveTimerDuration = conn.aliveTimerDuration,
    bool acceptUnverified = false,
    bool useSSL = true,
    ({InternetAddress host, int port})? proxyInfo,
  }) async {
    final client = ElectrumClient(
      await conn.connect(
        host,
        port: port,
        connectionTimeout: connectionTimeout,
        aliveTimerDuration: aliveTimerDuration,
        acceptUnverified: acceptUnverified,
        useSSL: useSSL,
        proxyInfo: proxyInfo,
      ),
      host,
      port,
      useSSL,
      proxyInfo,
    );

    return client;
  }

  @override
  String toString() => 'RavenElectrumClient connected to $host:$port';
}

/// Methods on FiroElectrumClient are defined in the `methods/specific/firo.dart` file.
///
/// See https://github.com/firoorg/electrumx-firo
class FiroElectrumClient extends ElectrumClient {
  FiroElectrumClient(StreamChannel<dynamic> channel, String host, int port,
      bool useSSL, ({InternetAddress host, int port})? proxyInfo)
      : super(channel, host, port, useSSL, proxyInfo);
  String clientName = 'electrum_adapter';
  String clientVersion = '2.0';
  String protocolVersion = '1.10';

  static Future<FiroElectrumClient> connect(
    String host, {
    int port = 50002,
    Duration connectionTimeout = conn.connectionTimeout,
    Duration aliveTimerDuration = conn.aliveTimerDuration,
    bool acceptUnverified = true,
    String clientName = 'electrum_adapter',
    String clientVersion = '2.0',
    String protocolVersion = '1.10',
    bool useSSL = true,
    ({InternetAddress host, int port})? proxyInfo,
  }) async {
    var client = FiroElectrumClient(
      await conn.connect(
        host,
        port: port,
        connectionTimeout: connectionTimeout,
        aliveTimerDuration: aliveTimerDuration,
        acceptUnverified: acceptUnverified,
        useSSL: useSSL,
        proxyInfo: proxyInfo,
      ),
      host,
      port,
      useSSL,
      proxyInfo,
    );
    client.clientName = clientName;
    client.protocolVersion = protocolVersion;
    await client.serverVersion(
        /*
        clientName: '$clientName/$clientVersion',
        protocolVersion: protocolVersion*/
        );
    return client;
  }

  @override
  String toString() => 'FiroElectrumClient connected to $host:$port';
}

/// Methods on RavenElectrumClient are defined in the `methods` directory.
/// See https://electrumx-ravencoin.readthedocs.io/en/latest/protocol-methods.html
class RavenElectrumClient extends ElectrumClient {
  RavenElectrumClient(StreamChannel<dynamic> channel,
      {String host = '',
      int port = 50002,
      bool useSSL = true,
      ({InternetAddress host, int port})? proxyInfo})
      : super(channel, host, port, useSSL, proxyInfo);
  String clientName = 'MTWallet';
  String clientVersion = '1.0';
  String protocolVersion = '1.10';

  static Future<RavenElectrumClient> connect(
    String host, {
    int port = 50002,
    Duration connectionTimeout = conn.connectionTimeout,
    Duration aliveTimerDuration = conn.aliveTimerDuration,
    bool acceptUnverified = true,
    String clientName = 'MTWallet',
    String clientVersion = '1.0',
    String protocolVersion = '1.10',
  }) async {
    var client = RavenElectrumClient(
      await conn.connect(
        host,
        port: port,
        connectionTimeout: connectionTimeout,
        aliveTimerDuration: aliveTimerDuration,
        acceptUnverified: acceptUnverified,
      ),
      host: host,
      port: port,
    );
    client.clientName = clientName;
    client.protocolVersion = protocolVersion;
    await client.serverVersion(
        clientName: '$clientName/$clientVersion',
        protocolVersion: protocolVersion);
    return client;
  }

  @override
  String toString() => 'RavenElectrumClient connected to $host:$port';
}
