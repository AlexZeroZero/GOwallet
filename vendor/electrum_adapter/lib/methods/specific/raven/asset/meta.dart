/// get meta data about an asset by name
import 'package:electrum_adapter/electrum_adapter.dart';
import 'package:equatable/equatable.dart';

class TxSource with EquatableMixin {
  late final String txHash;
  late final int txPos;
  late final int height;

  TxSource({required this.txHash, required this.txPos, required this.height});

  @override
  List<Object> get props => <Object>[txHash, txPos, height];

  @override
  String toString() {
    return '''TxSource( 
        txHash: $txHash,
        txPos: $txPos,
        height: $height)''';
  }
}

class AssetMeta with EquatableMixin {
  final String symbol;
  final int satsInCirculation;
  final int divisions;
  final bool reissuable;
  final bool hasIpfs;
  final TxSource source;

  AssetMeta(
      {required this.symbol,
      required this.satsInCirculation,
      required this.divisions,
      required this.reissuable,
      required this.hasIpfs,
      required this.source});

  @override
  List<Object> get props =>
      [symbol, satsInCirculation, divisions, reissuable, hasIpfs, source];

  @override
  String toString() {
    return '''AssetMeta( 
        symbol: $symbol,
        satsInCirculation: $satsInCirculation,
        divisions: $divisions,
        reissuable: $reissuable,
        hasIpfs: $hasIpfs,
        source: $source)''';
  }
}

extension GetAssetMetaMethod on RavenElectrumClient {
  Future<AssetMeta?> getMeta(String symbol) async {
    var response = await request(
      'blockchain.asset.get_meta',
      [symbol],
    );
    if (response.runtimeType == String) {
      /// "_This rpc call is not functional unless -assetindex is enabled. To enable, please run the wallet with -assetindex, this will require a reindex to occur"
      return null; // todo: this should error and we should catch it above
    }
    response = response as Map;
    if (response.isNotEmpty) {
      return AssetMeta(
        symbol: symbol,
        satsInCirculation: response['sats_in_circulation'] as int,
        divisions: response['divisions'] as int,
        reissuable: response['reissuable'] as bool,
        hasIpfs: response['has_ipfs'] as bool,
        source: TxSource(
            txHash: response['source']['tx_hash'] as String,
            txPos: response['source']['tx_pos'] as int,
            height: response['source']['height'] as int),
      );
    }
    return null;
  }

  /// returns histories in the same order as txHashes passed in
  Future<List<AssetMeta?>> getMetas(List<String> symbols) async {
    var futures = <Future<AssetMeta?>>[];
    if (symbols.isNotEmpty) {
      peer.withBatch(() {
        for (var symbol in symbols) {
          futures.add(getMeta(symbol));
        }
      });
    }
    List<AssetMeta?> results = await Future.wait<AssetMeta?>(futures);
    return results;
  }
}
