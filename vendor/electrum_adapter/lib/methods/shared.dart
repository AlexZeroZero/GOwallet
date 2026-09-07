import 'package:electrum_adapter/electrum_adapter.dart';

extension SharedMethods on ElectrumClient {
  Future<dynamic> ping() async => await request('server.ping');

  Future<Map<String, dynamic>> features() async =>
      (await request('server.features')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> serverVersion() async =>
      (await request('server.version')) as Map<String, dynamic>;

  Future<String> broadcastTransaction(String rawTx) async => await request(
        'blockchain.transaction.broadcast',
        [rawTx],
      ) as String;

  /// returns transaction hashs as hexadecimal strings in the same order as rawTxs passed in
  Future<List<String>> broadcastTransactions(List<String> rawTxs) async {
    var futures = <Future<String>>[];
    if (rawTxs.isNotEmpty) {
      peer.withBatch(() {
        for (var rawTx in rawTxs) {
          futures.add(broadcastTransaction(rawTx));
        }
      });
    }
    List<String> results = await Future.wait<String>(futures);
    return results;
  }

  Future<Map<String, dynamic>> getTransaction(String txHash) async {
    var response = Map<String, dynamic>.from((await request(
      'blockchain.transaction.get',
      [txHash, true],
    )) as Map);
    return response;
  }

  /// returns histories in the same order as txHashes passed in
  Future<List<Map<String, dynamic>>> getTransactions(
      Iterable<String> txHashes) async {
    var futures = <Future<Map<String, dynamic>>>[];
    if (txHashes.isNotEmpty) {
      peer.withBatch(() {
        for (var txHash in txHashes) {
          futures.add(getTransaction(txHash));
        }
      });
    }
    return await Future.wait<Map<String, dynamic>>(futures);
  }

  List<Future<Map<String, dynamic>>> getTransactionsFutures(
      Iterable<String> txHashes) {
    var futures = <Future<Map<String, dynamic>>>[];
    if (txHashes.isNotEmpty) {
      peer.withBatch(() {
        for (var txHash in txHashes) {
          futures.add(getTransaction(txHash));
        }
      });
    }
    return futures;
  }

  Future<Map<String, dynamic>> getFeeRate() async =>
      (await request('blockchain.getfeerate')) as Map<String, dynamic>;
}
