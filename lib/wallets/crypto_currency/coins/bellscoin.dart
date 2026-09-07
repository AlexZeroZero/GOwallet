import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;

import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/node_model.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/default_nodes.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../crypto_currency.dart';
import '../interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_currency.dart';

/// Bellscoin (BELLS) — Billy Markus's 2013 chain (it predates Dogecoin by
/// ~8 days), revived by the Nintondo team in late 2023. bellscoinV3 is a
/// modern Bitcoin Core rebase: scrypt AuxPoW, 60s blocks, SegWit and Taproot
/// active.
///
/// Unlike BFX and Pepecoin this coin has NO Electrum server anywhere — the
/// chain is ~365 GB thanks to three inscription-mania eras, so nobody indexes
/// it with ElectrumX. The backend is Nintondo's esplora HTTP API via
/// EsploraElectrumXClient (see bellscoin_wallet.dart); this class still mixes
/// in ElectrumXCurrencyInterface because the adapter speaks the Electrum
/// protocol shapes to the rest of the wallet.
class Bellscoin extends Bip39HDCurrency with ElectrumXCurrencyInterface {
  Bellscoin(super.network) {
    _idMain = "bellscoin";
    _uriScheme = "bellscoin";
    switch (network) {
      case CryptoCurrencyNetwork.main:
        _id = _idMain;
        _name = "Bellscoin";
        _ticker = "BELLS";
      // No testnet: Bells testnetV2 has no public esplora instance to ride.
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  late final String _id;
  @override
  String get identifier => _id;

  late final String _idMain;
  @override
  String get mainNetId => _idMain;

  late final String _name;
  @override
  String get prettyName => _name;

  late final String _uriScheme;
  @override
  String get uriScheme => _uriScheme;

  late final String _ticker;
  @override
  String get ticker => _ticker;

  @override
  bool get torSupport => true;

  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
  ];

  @override
  String constructDerivePath({
    required DerivePathType derivePathType,
    int account = 0,
    required int chain,
    required int index,
  }) {
    // SLIP-44 registers Bellscoin as 762. DECIDED 2026-09-01: we use it.
    //
    // Know the consequence before "fixing" this either way: the Nintondo
    // browser extension — the dominant BELLS wallet — derives at Bitcoin's
    // coin type 0 (DEFAULT_HD_PATH = "m/44'/0'/0'/0" in their source). A seed
    // from their wallet restores EMPTY here and vice versa. That is the
    // Pepecoin/Dogecoin coin-type lesson with the signs flipped, and 762 is
    // deliberate anyway: fresh accounts on our own path can never
    // accidentally sweep BEL-20 inscriptions sitting on an imported Nintondo
    // seed's UTXOs — this wallet treats every UTXO as plain coins.
    final String coinType = switch (network) {
      CryptoCurrencyNetwork.main => "762",
      _ => throw Exception("Unsupported network: $network"),
    };

    int purpose;
    switch (derivePathType) {
      case DerivePathType.bip44:
        purpose = 44;
        break;

      default:
        throw Exception("DerivePathType $derivePathType not supported");
    }

    return "m/$purpose'/$coinType'/$account'/$chain/$index";
  }

  @override
  List<NodeModel> get additionalDefaultNodes => const [];

  /// DUST_RELAY_TX_FEE is 3000 sat/kvB in bellscoinV3 (Bitcoin's value), so
  /// the P2PKH dust threshold is Bitcoin's 546 sats — not the 0.01-coin
  /// Doge-family limit Pepecoin carries.
  @override
  Amount get dustLimit =>
      Amount(rawValue: BigInt.from(546), fractionDigits: fractionDigits);

  /// Checked against the backend's reported `genesis_hash` on every connect.
  ///
  /// Verified twice, independently: kernel/chainparams.cpp in
  /// Nintondo/bellscoinV3 (hashGenesisBlock assert) and the live esplora
  /// `GET /block-height/0`. Both agree. The adapter fetches the server's
  /// value from the API rather than echoing this constant back, so the guard
  /// actually guards (the Pepecoin lesson).
  @override
  String get genesisHash {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return "e5be24df57c43a82d15c2f06bda96129"
            "6948f8f8eb48501bed1efb929afe0698";
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  @override
  ({coinlib.Address address, AddressType addressType}) getAddressForPublicKey({
    required coinlib.ECPublicKey publicKey,
    required DerivePathType derivePathType,
  }) {
    switch (derivePathType) {
      case DerivePathType.bip44:
        final addr = coinlib.P2PKHAddress.fromPublicKey(
          publicKey,
          version: networkParams.p2pkhPrefix,
        );

        return (address: addr, addressType: AddressType.p2pkh);

      default:
        throw Exception("DerivePathType $derivePathType not supported");
    }
  }

  /// Bell Bag Gold #F3C532, the lead colour of the official Bells palette.
  ///
  /// Wearable at last because heroInk() is now ADAPTIVE: on this gold, white
  /// measures 1.64:1 so the hero takes near-black ink (11.08:1) instead —
  /// the earlier fixes darkened the SURFACE to keep white ink, which traded
  /// the brand colour away. See hero_ink.dart for the rule and the measured
  /// opacity matrix; coin_card already adapted on its own.
  @override
  int get brandColorValue => 0xFFF3C532;

  @override
  int get minConfirms => 1;

  @override
  coinlib.Network get networkParams {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return coinlib.Network(
          wifPrefix: 0x99, // 153
          p2pkhPrefix: 0x19, // 25 -> addresses start with B
          p2shPrefix: 0x1e, // 30
          privHDPrefix: 0x02fac398,
          pubHDPrefix: 0x02facafd,
          // SegWit is active on Bells (height 144,000) but this wallet ships
          // legacy P2PKH only for now — universal exchange support first.
          bech32Hrp: "bel",
          // util/message.cpp MESSAGE_MAGIC; "Bells Signed Message:\n" is 22
          // chars, hence the \x16 length prefix.
          messagePrefix: '\x16Bells Signed Message:\n',
          minFee: BigInt.from(1), // Not used in stack wallet currently
          minOutput: dustLimit.raw, // Not used in stack wallet currently
          feePerKb: BigInt.from(1), // Not used in stack wallet currently
        );
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  @override
  bool validateAddress(String address) {
    try {
      coinlib.Address.fromString(address, networkParams);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  NodeModel defaultNode({required bool isPrimary}) {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        // Nintondo's esplora fork — the only public backend for this chain,
        // Cloudflare-fronted. Not an Electrum server: EsploraElectrumXClient
        // translates. The host string carries its own scheme, the same
        // pattern the Cardano/Tezos defaults use.
        return NodeModel(
          host: "https://electrs.nintondo.io",
          port: 443,
          // NOT DefaultNodes.defaultName: that constant is
          // "${AppConfig.prefix} Default" — literally "BitFinite Default" —
          // and every coin shares it. See pepecoin.dart.
          name: "Bellscoin Default",
          id: DefaultNodes.buildId(this),
          useSSL: true,
          enabled: true,
          coinName: identifier,
          isFailover: true,
          isDown: false,
          torEnabled: true,
          clearnetEnabled: true,
          isPrimary: isPrimary,
        );

      default:
        throw UnimplementedError();
    }
  }

  @override
  int get defaultSeedPhraseLength => 12;

  @override
  int get fractionDigits => 8;

  /// No integrated buy provider carries BELLS; advertising a Buy flow that
  /// dead-ends would violate "never advertise what the system cannot
  /// deliver".
  @override
  bool get hasBuySupport => false;

  @override
  bool get hasMnemonicPassphraseSupport => true;

  @override
  List<int> get possibleMnemonicLengths => [defaultSeedPhraseLength, 24];

  @override
  AddressType get defaultAddressType => defaultDerivePathType.getAddressType();

  @override
  BigInt get satsPerCoin => BigInt.from(100000000);

  @override
  int get targetBlockTimeSeconds => 60;

  @override
  DerivePathType get defaultDerivePathType => DerivePathType.bip44;

  @override
  Uri defaultBlockExplorer(String txid) {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return Uri.parse("https://nintondo.io/bells/explorer/tx/$txid");
      default:
        throw Exception(
          "Unsupported network for defaultBlockExplorer(): $network",
        );
    }
  }

  @override
  int get transactionVersion => 1;

  /// bellscoinV3 wallet policy: DEFAULT_TRANSACTION_MINFEE = 10000 sat/kvB,
  /// min relay 1000 sat/kvB. The esplora `/fee-estimates` endpoint returns
  /// `{}` (the mempool idles at zero), so in practice every send uses this
  /// rate via the estimateFee fallback — the same situation as BFX's
  /// electr-bfx, which lacks estimatefee entirely. 100000 sat/kvB is 10x the
  /// node's wallet minimum: relays everywhere, and at BELLS prices a full kB
  /// costs a twentieth of a US cent.
  @override
  BigInt get defaultFeeRate => BigInt.from(100000);
}
