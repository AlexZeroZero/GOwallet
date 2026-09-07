import 'package:electrum_adapter/client/subscribing_client.dart';
import 'package:electrum_adapter/electrum_adapter.dart';
import 'package:equatable/equatable.dart';

class BlockHeader extends Equatable {
  final String hex;
  final int height;

  BlockHeader(this.hex, this.height);

  @override
  List<Object> get props => <Object>[hex, height];
}

extension SubscribeMethods on ElectrumClient {
  Stream<BlockHeader> subscribeHeaders() {
    var methodPrefix = 'blockchain.headers';

    // If this is the first time, register
    registerSubscribable(methodPrefix, 0);

    return subscribeNonBatch(methodPrefix).asyncMap((item) => BlockHeader(
          item['hex'] as String,
          item['height'] as int,
        ));
  }

  Future<Stream<String?>> subscribeScripthash(String scripthash) async {
    var methodPrefix = 'blockchain.scripthash';

    // If this is the first time, register
    registerSubscribable(methodPrefix, 1);

    return await subscribe(methodPrefix, [scripthash]);
  }

  Future<List<Stream<String?>>> subscribeScripthashes(
    Iterable<String> scripthashes,
  ) async {
    var futures = <Future<Stream<String?>>>[];
    if (scripthashes.isNotEmpty) {
      peer.withBatch(() {
        for (var scripthash in scripthashes) {
          futures.add(subscribeScripthash(scripthash));
        }
      });
    }
    return await Future.wait<Stream<String?>>(futures);
  }

  Future<bool> unsubscribeScripthash(String scripthash) async => await request(
        'blockchain.scripthash.unsubscribe',
        [scripthash],
      ) as bool;

  Future<List<bool>> unsubscribeScripthashes(
    Iterable<String> scripthashes,
  ) async {
    var futures = <Future<bool>>[];
    if (scripthashes.isNotEmpty) {
      peer.withBatch(() {
        for (var scripthash in scripthashes) {
          futures.add(unsubscribeScripthash(scripthash));
        }
      });
    }
    return await Future.wait<bool>(futures);
  }
}
