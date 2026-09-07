/// for
import 'package:electrum_adapter/electrum_adapter.dart';

extension GetAssetNamesMethod on RavenElectrumClient {
  Future<Iterable<dynamic>> getAssetsByPrefix(String symbol) async {
    return (await request(
      'blockchain.asset.get_assets_with_prefix',
      [symbol.toUpperCase()],
    )) as Iterable;
  }
}
