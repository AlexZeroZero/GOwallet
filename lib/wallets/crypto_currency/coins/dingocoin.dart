import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../intermediate/public_electrum_currency.dart';

/// Native Dingocoin mainnet; legacy transactions only (SegWit is disabled).
/// Parameters: dingocoin/dingocoin src/chainparams.cpp and policy/policy.h.
class Dingocoin extends PublicElectrumCurrency {
  Dingocoin(super.network);
  @override
  String get identifier => 'dingocoin';
  @override
  String get prettyName => 'Dingocoin';
  @override
  String get ticker => 'DINGO';
  @override
  // Existing DINGO BIP44 wallets use coin type 3 (see GLEECBTC/coins).
  // This is a compatibility convention, not a unique SLIP-44 registration.
  int get slip44 => 3;
  @override
  int get electrumPort => 3342;
  @override
  String get electrumHost => 'elecx1.dingocoin.com';
  @override
  String get genesisHash =>
      '1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691';
  static const blockOneHash =
      '594a42d8fe16382085dc982135df72cf8fcea12d34e6efd566e2f9e442e2136f';

  @override
  int get minCoinbaseConfirms => 240;
  @override
  int get targetBlockTimeSeconds => 60;
  @override
  int get brandColorValue => 0xFFB17C30;
  @override
  DerivePathType get defaultDerivePathType => DerivePathType.bip44;
  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
  ];
  @override
  // Conservative one-DINGO output floor, compatible with the public node's
  // one-DINGO/kB relay policy; avoids legacy soft-dust fee surcharges.
  Amount get dustLimit =>
      Amount(rawValue: BigInt.from(100000000), fractionDigits: 8);
  @override
  BigInt get defaultFeeRate => BigInt.from(100000000);
  @override
  coinlib.Network get networkParams => coinlib.Network(
    wifPrefix: 158,
    p2pkhPrefix: 30,
    p2shPrefix: 22,
    privHDPrefix: 0x02fac398,
    pubHDPrefix: 0x02facafd,
    bech32Hrp: 'dingo', // No witness addresses are accepted for this chain.
    messagePrefix: '\x1aDingocoin Signed Message:\n',
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
      Uri.parse('https://explorer.dingocoin.com/tx/$txid');
}
