import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import '../../../utilities/amount/amount.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../intermediate/public_electrum_currency.dart';

class Scash extends PublicElectrumCurrency {
  Scash(super.network);
  @override
  String get identifier => 'scash';
  @override
  String get prettyName => 'Scash';
  @override
  String get ticker => 'SCASH';
  @override
  int get slip44 => 805;
  @override
  int get electrumPort => 50002;
  @override
  String get electrumHost => 'scash.gozero.trade';
  @override
  String get genesisHash =>
      'e3bf1597a568216022dbda6a0945f09b005d19f041e7158c3cbca9d4029ee82d';
  @override
  int get minCoinbaseConfirms => 100;
  @override
  int get targetBlockTimeSeconds => 600;
  @override
  int get brandColorValue => 0xFF3866DC;
  @override
  DerivePathType get defaultDerivePathType => DerivePathType.bip84;
  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
    DerivePathType.bip49,
    DerivePathType.bip84,
  ];
  @override
  Amount get dustLimit => Amount(rawValue: BigInt.from(546), fractionDigits: 8);
  @override
  BigInt get defaultFeeRate => BigInt.from(1000);
  @override
  coinlib.Network get networkParams => coinlib.Network(
    wifPrefix: 0x80,
    p2pkhPrefix: 0,
    p2shPrefix: 5,
    privHDPrefix: 0x0488ade4,
    pubHDPrefix: 0x0488b21e,
    bech32Hrp: 'scash',
    messagePrefix: '\x18Bitcoin Signed Message:\n',
    minFee: defaultFeeRate,
    minOutput: dustLimit.raw,
    feePerKb: defaultFeeRate,
  );
  @override
  Uri defaultBlockExplorer(String txid) =>
      Uri.parse('https://explorer.scash.network/tx/$txid');
}
