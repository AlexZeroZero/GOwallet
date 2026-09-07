import '../../models/isar/models/blockchain_data/address.dart';
import '../../models/node_model.dart';
import '../../utilities/enums/derive_path_type_enum.dart';

export 'coins/banano.dart';
export 'coins/bitcoin.dart';
export 'coins/bitcoin_frost.dart';
export 'coins/bitcoincash.dart';
export 'coins/bellscoin.dart';
export 'coins/bitfinite.dart';
export 'coins/scash.dart';
export 'coins/custom_electrum.dart';
export 'coins/shibacoin.dart';
export 'coins/cardano.dart';
export 'coins/dash.dart';
export 'coins/dogecoin.dart';
export 'coins/pepecoin.dart';
export 'coins/ecash.dart';
export 'coins/epiccash.dart';
export 'coins/mimblewimblecoin.dart';
export 'coins/ethereum.dart';
export 'coins/fact0rn.dart';
export 'coins/firo.dart';
export 'coins/litecoin.dart';
export 'coins/monero.dart';
export 'coins/namecoin.dart';
export 'coins/nano.dart';
export 'coins/particl.dart';
export 'coins/peercoin.dart';
export 'coins/salvium.dart';
export 'coins/solana.dart';
export 'coins/stellar.dart';
export 'coins/tezos.dart';
export 'coins/wownero.dart';
export 'coins/xelis.dart';

enum CryptoCurrencyNetwork {
  main,
  test,
  stage,
  test4;

  bool get isTestNet =>
      this == CryptoCurrencyNetwork.test || this == CryptoCurrencyNetwork.test4;
}

abstract class CryptoCurrency {
  final CryptoCurrencyNetwork network;

  CryptoCurrency(this.network);

  // Identifier should be unique.
  /// This [identifier] should also match the old `Coin` enum name for each
  /// respective coin as it is used to differentiate between coins in persistent
  /// storage.
  String get identifier;

  /// Should be the [identifier] of the main net version of the currency
  String get mainNetId;

  String get ticker;
  String get prettyName;
  String get uriScheme;

  // override in subclass if the currency has tokens on it's network
  // (used for eth currently)
  /// The coin's own brand colour, when it has a published one.
  ///
  /// Only consulted if the active theme defines no colour for this coin. Themes
  /// carried over from upstream only cover the coins upstream ships, so anything
  /// added since falls back to the theme's primary and ends up looking like
  /// every other coin. A published brand colour is a better answer than that,
  /// and a theme that defines its own still wins.
  int? get brandColorValue => null;

  bool get hasTokenSupport => false;

  // Override in subclass if the currency has Tor support:
  bool get torSupport => false;

  int get minConfirms;
  int get minCoinbaseConfirms => minConfirms;

  // TODO: [prio=low] could be handled differently as (at least) epiccash/mimblewimblecoin does not use this
  String get genesisHash;

  bool validateAddress(String address);
  AddressType? getAddressType(String address);

  NodeModel defaultNode({required bool isPrimary});

  /// Extra built-in failover nodes seeded alongside [defaultNode]. Empty by
  /// default; a coin can override to ship additional failover servers.
  List<NodeModel> get additionalDefaultNodes => const [];


  int get defaultSeedPhraseLength;
  int get fractionDigits;
  bool get hasBuySupport;
  bool get hasMnemonicPassphraseSupport;
  List<int> get possibleMnemonicLengths;
  AddressType get defaultAddressType;
  BigInt get satsPerCoin;
  int get targetBlockTimeSeconds;
  DerivePathType get defaultDerivePathType;

  Uri defaultBlockExplorer(String txid);

  @override
  bool operator ==(Object other) {
    return other is CryptoCurrency &&
        other.runtimeType == runtimeType &&
        other.network == network;
  }

  @override
  int get hashCode => Object.hash(runtimeType, network);
}
