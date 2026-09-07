import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../intermediate/public_electrum_currency.dart';

class Shibacoin extends PublicElectrumCurrency {
  Shibacoin(super.network);
  @override
  String get identifier => 'shibacoin';
  @override
  String get prettyName => 'Shibacoin';
  @override
  String get ticker => 'SHIC';
  @override
  int get slip44 => 4474;
  @override
  int get electrumPort => 50012;
  @override
  String get electrumHost => 'shic.gozero.trade';
  @override
  String get genesisHash =>
      'ff271edcc83f7d71e7a4e4b0a43b386a188e1470a28671cdbdc47e900118ac7f';
  @override
  int get minCoinbaseConfirms => 240;
  @override
  int get targetBlockTimeSeconds => 60;
  @override
  int get brandColorValue => 0xFFD46B31;
  @override
  DerivePathType get defaultDerivePathType => DerivePathType.bip44;
  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
  ];
  @override
  Amount get dustLimit =>
      Amount(rawValue: BigInt.from(1000000), fractionDigits: 8);
  @override
  BigInt get defaultFeeRate => BigInt.from(1000000);
  @override
  coinlib.Network get networkParams => coinlib.Network(
    wifPrefix: 158,
    p2pkhPrefix: 63,
    p2shPrefix: 22,
    privHDPrefix: 0x02fac495,
    pubHDPrefix: 0x02fadafe,
    bech32Hrp: 'shic', // No witness addresses are accepted for this chain.
    messagePrefix: '\x1aShibacoin Signed Message:\n',
    minFee: defaultFeeRate,
    minOutput: dustLimit.raw,
    feePerKb: defaultFeeRate,
  );
  @override
  AddressType? getAddressType(String address) {
    final type = super.getAddressType(address);
    return type == AddressType.p2pkh || type == AddressType.p2sh ? type : null;
  }

  @override
  Uri defaultBlockExplorer(String txid) =>
      Uri.parse('https://shibaexplorer.com/tx/$txid');
}
