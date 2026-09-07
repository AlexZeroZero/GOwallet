import 'package:electrum_adapter/electrum_adapter.dart';
import 'package:equatable/equatable.dart';

class ScripthashHistory with EquatableMixin {
  int height;
  String txHash;
  late String? memo;
  ScripthashHistory({required this.height, required this.txHash, this.memo});

  @override
  List<Object> get props => <Object>[height, txHash, memo ?? ''];

  @override
  String toString() {
    return 'ScripthashHistory(txHash: $txHash, height: $height, memo: $memo)';
  }
}

extension GetHistoryMethod on RavenElectrumClient {
  Future<List<ScripthashHistory>> getHistory(String scripthash) async =>
      ((await request(
        'blockchain.scripthash.get_history',
        [scripthash],
      ) as List<dynamic>)
          .map((response) => ScripthashHistory(
              height: response['height'] as int,
              txHash: response['tx_hash'] as String))).toList();

  /// returns histories in the same order as scripthashes passed in
  Future<List<List<ScripthashHistory>>> getHistories(
    Iterable<String> scripthashes,
  ) async {
    var futures = <Future<List<ScripthashHistory>>>[];
    if (scripthashes.isNotEmpty) {
      peer.withBatch(() {
        for (var scripthash in scripthashes) {
          futures.add(getHistory(scripthash));
        }
      });
    }
    List<List<ScripthashHistory>> results =
        await Future.wait<List<ScripthashHistory>>(futures);
    return results;
  }
}
