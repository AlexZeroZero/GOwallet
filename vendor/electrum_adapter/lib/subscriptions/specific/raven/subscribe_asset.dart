import 'dart:async';

import 'package:electrum_adapter/client/subscribing_client.dart';
import 'package:electrum_adapter/electrum_adapter.dart';

extension SubscribeAssetMethod on RavenElectrumClient {
  Future<Stream<String?>> subscribeAsset(String assetName) async {
    var methodPrefix = 'blockchain.asset';

    // If this is the first time, register
    registerSubscribable(methodPrefix, 1);

    return (await subscribe(methodPrefix, [assetName]))
        .asyncMap((item) => item as FutureOr<String?>);
  }
}
