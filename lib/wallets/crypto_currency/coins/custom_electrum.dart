import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import '../../../gowallet/custom_coin_definition.dart';
import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/node_model.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/default_nodes.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../crypto_currency.dart';
import '../intermediate/public_electrum_currency.dart';

class CustomElectrumCurrency extends PublicElectrumCurrency {
  final CustomCoinDefinition definition;
  CustomElectrumCurrency(this.definition) : super(CryptoCurrencyNetwork.main);
  @override
  String get identifier => definition.identifier;
  @override
  String get prettyName => definition.name;
  @override
  String get ticker => definition.ticker;
  @override
  String get genesisHash => definition.string('genesis');
  @override
  int get slip44 => definition.integer('slip44');
  @override
  int get electrumPort => definition.integer('port');
  @override
  String get electrumHost => definition.string('host');
  @override
  int get fractionDigits => definition.integer('decimals');
  @override
  BigInt get satsPerCoin => BigInt.from(10).pow(fractionDigits);
  @override
  int get minConfirms => definition.integer('confirmations');
  @override
  int get minCoinbaseConfirms => definition.integer('coinbaseMaturity');
  @override
  int get targetBlockTimeSeconds => definition.integer('blockTime');
  @override
  int get transactionVersion => definition.integer('txVersion');
  @override
  int get brandColorValue => 0xFF48BFA0;
  @override
  BigInt get defaultFeeRate => BigInt.from(definition.integer('feePerKb'));
  @override
  Amount get dustLimit => Amount(
    rawValue: BigInt.from(definition.integer('dust')),
    fractionDigits: fractionDigits,
  );
  @override
  DerivePathType get defaultDerivePathType =>
      definition.flag('segwit') ? DerivePathType.bip84 : DerivePathType.bip44;
  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
    if (definition.flag('segwit')) ...[
      DerivePathType.bip49,
      DerivePathType.bip84,
    ],
  ];
  @override
  coinlib.Network get networkParams => coinlib.Network(
    wifPrefix: definition.integer('wif'),
    p2pkhPrefix: definition.integer('p2pkh'),
    p2shPrefix: definition.integer('p2sh'),
    privHDPrefix: definition.integer('bip32Private'),
    pubHDPrefix: definition.integer('bip32Public'),
    bech32Hrp: definition.string('hrp').isEmpty
        ? 'unused'
        : definition.string('hrp'),
    // Message signing is not offered for custom coins; transaction signing only.
    messagePrefix: '\x18Bitcoin Signed Message:\n',
    minFee: defaultFeeRate,
    minOutput: dustLimit.raw,
    feePerKb: defaultFeeRate,
  );
  @override
  AddressType? getAddressType(String address) {
    final type = super.getAddressType(address);
    return type == AddressType.p2pkh ||
            type == AddressType.p2sh ||
            (definition.flag('segwit') && type == AddressType.p2wpkh)
        ? type
        : null;
  }

  @override
  NodeModel defaultNode({required bool isPrimary}) => NodeModel(
    host: electrumHost,
    port: electrumPort,
    name: '$ticker Electrum',
    id: DefaultNodes.buildId(this),
    useSSL: definition.flag('tls'),
    enabled: true,
    coinName: identifier,
    isFailover: true,
    isDown: false,
    torEnabled: false,
    clearnetEnabled: true,
    isPrimary: isPrimary,
  );
  @override
  Uri defaultBlockExplorer(String txid) {
    final prefix = definition.string('explorer');
    if (prefix.isEmpty || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(txid))
      return Uri();
    return Uri.parse('$prefix$txid');
  }

  @override
  bool operator ==(Object other) =>
      other is CustomElectrumCurrency && other.identifier == identifier;
  @override
  int get hashCode => identifier.hashCode;
}
