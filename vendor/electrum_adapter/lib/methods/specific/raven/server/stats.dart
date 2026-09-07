import 'package:electrum_adapter/electrum_adapter.dart';

class ServerStats {
  late double ourCost;
  late int hardLimit;
  late int softLimit;
  late double costDecayPerSec;
  late double bandwithCostPerByte;
  late double sleep;
  late int concurrentRequests;
  late int sendSize;
  late int sendCount;
  late int receiveSize;
  late int receiveCount;
  ServerStats(
      this.ourCost,
      this.hardLimit,
      this.softLimit,
      this.costDecayPerSec,
      this.bandwithCostPerByte,
      this.sleep,
      this.concurrentRequests,
      this.sendSize,
      this.sendCount,
      this.receiveSize,
      this.receiveCount);

  @override
  String toString() {
    return '''ServerStats( 
    ourCost: $ourCost, 
    hardLimit: $hardLimit, 
    softLimit: $softLimit, 
    costDecayPerSec: $costDecayPerSec, 
    bandwithCostPerByte: $bandwithCostPerByte, 
    sleep: $sleep, 
    concurrentRequests: $concurrentRequests, 
    sendSize: $sendSize, 
    sendCount: $sendCount, 
    receiveSize: $receiveSize, 
    receiveCount: $receiveCount)''';
  }
}

extension GetOurStatsMethod on RavenElectrumClient {
  Future<dynamic> getOurStats() async {
    var proc = 'server.our_stats';
    dynamic stats = await request(proc);
    return ServerStats(
      stats['our_cost'] as double,
      stats['hard_limit'] as int,
      stats['soft_limit'] as int,
      stats['cost_decay_per_sec'] as double,
      stats['bandwith_cost_per_byte'] as double,
      stats['sleep'] as double,
      stats['concurrent_requests'] as int,
      stats['send_size'] as int,
      stats['send_count'] as int,
      stats['receive_size'] as int,
      stats['receive_count'] as int,
    );
  }
}
