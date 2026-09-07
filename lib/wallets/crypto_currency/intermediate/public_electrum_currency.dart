import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;

import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/node_model.dart';
import '../../../utilities/default_nodes.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../crypto_currency.dart';
import '../interfaces/electrumx_currency_interface.dart';
import 'bip39_hd_currency.dart';

/// Shared mainnet behavior. Each supported chain still supplies its own
/// consensus/address parameters; an arbitrary server cannot define a coin.
abstract class PublicElectrumCurrency extends Bip39HDCurrency
    with ElectrumXCurrencyInterface {
  PublicElectrumCurrency(super.network) {
    if (network != CryptoCurrencyNetwork.main) {
      throw ArgumentError('Only mainnet is supported for this currency');
    }
  }

  int get slip44;
  int get electrumPort;
  String get electrumHost;
  @override
  String get mainNetId => identifier;
  @override
  String get uriScheme => identifier;
  @override
  int get minConfirms => 1;
  @override
  int get defaultSeedPhraseLength => 12;
  @override
  int get fractionDigits => 8;
  @override
  bool get hasBuySupport => false;
  @override
  bool get hasMnemonicPassphraseSupport => true;
  @override
  List<int> get possibleMnemonicLengths => [12, 24];
  @override
  BigInt get satsPerCoin => BigInt.from(100000000);
  @override
  AddressType get defaultAddressType => defaultDerivePathType.getAddressType();
  @override
  int get transactionVersion => 1;

  @override
  String constructDerivePath({
    required DerivePathType derivePathType,
    int account = 0,
    required int chain,
    required int index,
  }) {
    if (!supportedDerivationPathTypes.contains(derivePathType) ||
        account < 0 ||
        account >= 0x80000000 ||
        (chain != 0 && chain != 1) ||
        index < 0 ||
        index >= 0x80000000) {
      throw ArgumentError('Unsupported derivation path');
    }
    final purpose = switch (derivePathType) {
      DerivePathType.bip44 => 44,
      DerivePathType.bip49 => 49,
      DerivePathType.bip84 => 84,
      DerivePathType.bip86 => 86,
      _ => throw ArgumentError('Unsupported derivation path'),
    };
    return "m/$purpose'/$slip44'/$account'/$chain/$index";
  }

  @override
  ({coinlib.Address address, AddressType addressType}) getAddressForPublicKey({
    required coinlib.ECPublicKey publicKey,
    required DerivePathType derivePathType,
  }) {
    if (!supportedDerivationPathTypes.contains(derivePathType)) {
      throw ArgumentError('Unsupported address type');
    }
    final coinlib.Address address;
    switch (derivePathType) {
      case DerivePathType.bip44:
        address = coinlib.P2PKHAddress.fromPublicKey(
          publicKey,
          version: networkParams.p2pkhPrefix,
        );
      case DerivePathType.bip49:
        final script = coinlib.P2WPKHAddress.fromPublicKey(
          publicKey,
          hrp: networkParams.bech32Hrp,
        ).program.script;
        address = coinlib.P2SHAddress.fromRedeemScript(
          script,
          version: networkParams.p2shPrefix,
        );
      case DerivePathType.bip84:
        address = coinlib.P2WPKHAddress.fromPublicKey(
          publicKey,
          hrp: networkParams.bech32Hrp,
        );
      default:
        throw ArgumentError('Unsupported address type');
    }
    return (address: address, addressType: derivePathType.getAddressType());
  }

  @override
  bool validateAddress(String address) => getAddressType(address) != null;

  @override
  NodeModel defaultNode({required bool isPrimary}) => NodeModel(
    host: electrumHost,
    port: electrumPort,
    name: '$ticker Electrum TLS',
    id: DefaultNodes.buildId(this),
    useSSL: true,
    enabled: true,
    coinName: identifier,
    isFailover: true,
    isDown: false,
    torEnabled: false,
    clearnetEnabled: true,
    isPrimary: isPrimary,
  );
}
