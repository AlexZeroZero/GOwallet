import 'package:isar_community/isar.dart';

import '../../../electrumx_rpc/cached_electrumx_client.dart';
import '../../../electrumx_rpc/electrumx_client.dart';
import '../../../electrumx_rpc/esplora_electrumx_client.dart';
import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/isar/models/blockchain_data/transaction.dart';
import '../../../models/isar/models/blockchain_data/v2/input_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/output_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/extensions/extensions.dart';
import '../../../utilities/logger.dart';
import '../../crypto_currency/crypto_currency.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_wallet.dart';
import '../wallet_mixin_interfaces/coin_control_interface.dart';
import '../wallet_mixin_interfaces/electrumx_interface.dart';
import '../wallet_mixin_interfaces/extended_keys_interface.dart';

/// Bellscoin rides ElectrumXInterface like every other UTXO coin here, but
/// its "ElectrumX server" is Nintondo's esplora HTTP API wrapped in
/// [EsploraElectrumXClient] — no public Electrum server exists for this
/// chain. Only two things differ from the Pepecoin template:
/// [updateElectrumX] constructs the esplora adapter, and [fetchChainHeight]
/// reads the tip over HTTP instead of ClientManager's socket subscription
/// (which never exists for this coin, since the adapter registers no
/// electrum_adapter client).
class BellscoinWallet<T extends ElectrumXCurrencyInterface>
    extends Bip39HDWallet<T>
    with ElectrumXInterface<T>, ExtendedKeysInterface<T>, CoinControlInterface {
  BellscoinWallet(CryptoCurrencyNetwork network)
    : super(Bellscoin(network) as T);

  @override
  int get isarTransactionVersion => 2;

  @override
  FilterOperation? get changeAddressFilterOperation =>
      FilterGroup.and(standardChangeAddressFilters);

  @override
  FilterOperation? get receivingAddressFilterOperation =>
      FilterGroup.and(standardReceivingAddressFilters);

  bool _verifiedGenesis = false;

  // ===========================================================================
  // esplora backend plumbing

  @override
  Future<void> updateElectrumX() async {
    final node = getCurrentNode();

    try {
      await electrumXClient.closeAdapter();
    } catch (e) {
      if (e.toString().contains("initialized")) {
        // Ignore. This happens every first time the wallet is opened.
      } else {
        Logging.instance.e("Error closing electrumXClient: $e");
      }
    }

    electrumXClient = EsploraElectrumXClient.from(
      node: ElectrumXNode(
        address: node.host,
        port: node.port,
        name: node.name,
        useSSL: node.useSSL,
        id: node.id,
        torEnabled: node.torEnabled,
        clearnetEnabled: node.clearnetEnabled,
      ),
      prefs: prefs,
      // A single public API exists; anything in the node list beyond it is
      // user-added and becomes the primary via getCurrentNode() instead.
      failovers: [],
      cryptoCurrency: cryptoCurrency,
    );
    electrumXCachedClient = CachedElectrumXClient.from(
      electrumXClient: electrumXClient,
    );
  }

  /// The mixin's implementation reads ClientManager's header subscription,
  /// which only exists for real Electrum sockets. This one asks the esplora
  /// API, and carries the genesis check the mixin normally performs lazily —
  /// without it, a backend serving a different chain would sync garbage
  /// silently (the guard fed itself its own expected value in the Pepecoin
  /// case; here the adapter fetches the server's actual block 0).
  @override
  Future<int> fetchChainHeight({int retries = 1}) async {
    try {
      if (!_verifiedGenesis) {
        final features = await electrumXClient.getServerFeatures();
        if (cryptoCurrency.genesisHash != features["genesis_hash"]) {
          throw Exception(
            "Genesis hash does not match! Expected "
            "${cryptoCurrency.genesisHash}, backend reports "
            "${features["genesis_hash"]}",
          );
        }
        _verifiedGenesis = true;
      }

      return (await electrumXClient.getBlockHeadTip())["height"] as int;
    } catch (e, s) {
      if (retries > 0) {
        return await fetchChainHeight(retries: retries - 1);
      }
      Logging.instance.e(
        "Exception rethrown in fetchChainHeight",
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // ===========================================================================

  @override
  Future<List<Address>> fetchAddressesForElectrumXScan() async {
    final allAddresses = await mainDB
        .getAddresses(walletId)
        .filter()
        .not()
        .group(
          (q) => q
              .typeEqualTo(AddressType.nonWallet)
              .or()
              .subTypeEqualTo(AddressSubType.nonWallet),
        )
        .findAll();
    return allAddresses;
  }

  // ===========================================================================

  @override
  Future<void> updateTransactions() async {
    // Get all addresses.
    final List<Address> allAddressesOld =
        await fetchAddressesForElectrumXScan();

    // Separate receiving and change addresses.
    final Set<String> receivingAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.receiving)
        .map((e) => e.value)
        .toSet();
    final Set<String> changeAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.change)
        .map((e) => e.value)
        .toSet();

    // Remove duplicates.
    final allAddressesSet = {...receivingAddresses, ...changeAddresses};

    // Fetch history through the esplora adapter.
    final List<Map<String, dynamic>> allTxHashes = await fetchHistory(
      allAddressesSet,
    );

    // Only parse new txs (not in db yet).
    final List<Map<String, dynamic>> allTransactions = [];
    for (final txHash in allTxHashes) {
      // Check for duplicates by searching for tx by tx_hash in db.
      final storedTx = await mainDB.isar.transactionV2s
          .where()
          .txidWalletIdEqualTo(txHash["tx_hash"] as String, walletId)
          .findFirst();

      if (storedTx == null ||
          storedTx.height == null ||
          (storedTx.height != null && storedTx.height! <= 0)) {
        // Tx not in db yet.
        final tx = await electrumXCachedClient.getTransaction(
          txHash: txHash["tx_hash"] as String,
          verbose: true,
          cryptoCurrency: cryptoCurrency,
        );

        // Only tx to list once.
        if (allTransactions.indexWhere(
              (e) => e["txid"] == tx["txid"] as String,
            ) ==
            -1) {
          tx["height"] = txHash["height"];
          allTransactions.add(tx);
        }
      }
    }

    // Parse all new txs.
    final List<TransactionV2> txns = [];
    for (final txData in allTransactions) {
      bool wasSentFromThisWallet = false;
      // Set to true if any inputs were detected as owned by this wallet.

      bool wasReceivedInThisWallet = false;
      // Set to true if any outputs were detected as owned by this wallet.

      // Parse inputs.
      BigInt amountReceivedInThisWallet = BigInt.zero;
      BigInt changeAmountReceivedInThisWallet = BigInt.zero;
      final List<InputV2> inputs = [];
      for (final jsonInput in txData["vin"] as List) {
        final map = Map<String, dynamic>.from(jsonInput as Map);

        final List<String> addresses = [];
        String valueStringSats = "0";
        OutpointV2? outpoint;

        final coinbase = map["coinbase"] as String?;

        if (coinbase == null) {
          // Not a coinbase (ie a typical input).
          final txid = map["txid"] as String;
          final vout = map["vout"] as int;

          outpoint = OutpointV2.isarCantDoRequiredInDefaultConstructor(
            txid: txid,
            vout: vout,
          );

          final inlinePrevout = map["_prevout"];
          if (inlinePrevout is Map) {
            // EsploraElectrumXClient passes esplora's inline prevout
            // through, so pricing this input costs no extra request. The
            // fetch below only runs for txs cached before that field
            // existed — and their prevout txs are usually cached too.
            valueStringSats = OutputV2.parseOutputAmountString(
              inlinePrevout["value"].toString(),
              decimalPlaces: cryptoCurrency.fractionDigits,
              isFullAmountNotSats: true,
            );
            addresses.addAll(
              (inlinePrevout["addresses"] as List? ?? []).cast<String>(),
            );
          } else {
            final inputTx = await electrumXCachedClient.getTransaction(
              txHash: txid,
              cryptoCurrency: cryptoCurrency,
            );

            final prevOutJson = Map<String, dynamic>.from(
              (inputTx["vout"] as List).firstWhere((e) => e["n"] == vout)
                  as Map,
            );

            final prevOut = OutputV2.fromElectrumXJson(
              prevOutJson,
              decimalPlaces: cryptoCurrency.fractionDigits,
              isFullAmountNotSats: true,
              walletOwns: false, // Doesn't matter here as this is not saved.
            );

            valueStringSats = prevOut.valueStringSats;
            addresses.addAll(prevOut.addresses);
          }
        }

        InputV2 input = InputV2.isarCantDoRequiredInDefaultConstructor(
          scriptSigHex: map["scriptSig"]?["hex"] as String?,
          scriptSigAsm: map["scriptSig"]?["asm"] as String?,
          sequence: map["sequence"] as int?,
          outpoint: outpoint,
          valueStringSats: valueStringSats,
          addresses: addresses,
          witness: map["witness"] as String?,
          coinbase: coinbase,
          innerRedeemScriptAsm: map["innerRedeemscriptAsm"] as String?,
          // Need addresses before we can know if the wallet owns this input.
          walletOwns: false,
        );

        // Check if input was from this wallet.
        if (allAddressesSet.intersection(input.addresses.toSet()).isNotEmpty) {
          wasSentFromThisWallet = true;
          input = input.copyWith(walletOwns: true);
        }

        inputs.add(input);
      }

      // Parse outputs.
      final List<OutputV2> outputs = [];
      for (final outputJson in txData["vout"] as List) {
        OutputV2 output = OutputV2.fromElectrumXJson(
          Map<String, dynamic>.from(outputJson as Map),
          decimalPlaces: cryptoCurrency.fractionDigits,
          isFullAmountNotSats: true,
          // Need addresses before we can know if the wallet owns this input.
          walletOwns: false,
        );

        // If output was to my wallet, add value to amount received.
        if (receivingAddresses
            .intersection(output.addresses.toSet())
            .isNotEmpty) {
          wasReceivedInThisWallet = true;
          amountReceivedInThisWallet += output.value;
          output = output.copyWith(walletOwns: true);
        } else if (changeAddresses
            .intersection(output.addresses.toSet())
            .isNotEmpty) {
          wasReceivedInThisWallet = true;
          changeAmountReceivedInThisWallet += output.value;
          output = output.copyWith(walletOwns: true);
        }

        outputs.add(output);
      }

      final totalOut = outputs
          .map((e) => e.value)
          .fold(BigInt.zero, (value, element) => value + element);

      TransactionType type;
      const TransactionSubType subType = TransactionSubType.none;

      // At least one input was owned by this wallet.
      if (wasSentFromThisWallet) {
        type = TransactionType.outgoing;

        if (wasReceivedInThisWallet) {
          if (changeAmountReceivedInThisWallet + amountReceivedInThisWallet ==
              totalOut) {
            // Definitely sent all to self.
            type = TransactionType.sentToSelf;
          } else if (amountReceivedInThisWallet == BigInt.zero) {
            // Most likely just a typical send, do nothing here yet.
          }
        }
      } else if (wasReceivedInThisWallet) {
        // Only found outputs owned by this wallet.
        type = TransactionType.incoming;
      } else {
        Logging.instance.e("Unexpected tx found (ignoring it)");
        Logging.instance.d("Unexpected tx found (ignoring it): $txData");
        continue;
      }

      final tx = TransactionV2(
        walletId: walletId,
        blockHash: txData["blockhash"] as String?,
        hash: txData["hash"] as String,
        txid: txData["txid"] as String,
        height: txData["height"] as int?,
        version: txData["version"] as int,
        timestamp:
            txData["blocktime"] as int? ??
            DateTime.timestamp().millisecondsSinceEpoch ~/ 1000,
        inputs: List.unmodifiable(inputs),
        outputs: List.unmodifiable(outputs),
        type: type,
        subType: subType,
        otherData: null,
      );

      txns.add(tx);
    }

    await mainDB.updateOrPutTransactionV2s(txns);
  }

  @override
  Future<({String? blockedReason, bool blocked, String? utxoLabel})>
  checkBlockUTXO(
    Map<String, dynamic> jsonUTXO,
    String? scriptPubKeyHex,
    Map<String, dynamic> jsonTX,
    String? utxoOwnerAddress,
  ) async {
    bool blocked = false;
    String? blockedReason;

    // check for bip47 notification
    final outputs = jsonTX["vout"] as List;
    for (final output in outputs) {
      final List<String>? scriptChunks =
          (output['scriptPubKey']?['asm'] as String?)?.split(" ");
      if (scriptChunks?.length == 2 && scriptChunks?[0] == "OP_RETURN") {
        final blindedPaymentCode = scriptChunks![1];
        final bytes = blindedPaymentCode.toUint8ListFromHex;

        // https://en.bitcoin.it/wiki/BIP_0047#Sending
        if (bytes.length == 80 && bytes.first == 1) {
          blocked = true;
          blockedReason =
              "Paynym notification output. Incautious "
              "handling of outputs from notification transactions "
              "may cause unintended loss of privacy.";
          break;
        }
      }
    }

    return (blockedReason: blockedReason, blocked: blocked, utxoLabel: null);
  }

  @override
  Amount roughFeeEstimate(
    int inputCount,
    int outputCount,
    BigInt feeRatePerKB,
  ) {
    return Amount(
      rawValue: BigInt.from(
        ((181 * inputCount) + (34 * outputCount) + 10) *
            (feeRatePerKB.toInt() / 1000).ceil(),
      ),
      fractionDigits: cryptoCurrency.fractionDigits,
    );
  }

  @override
  int estimateTxFee({required int vSize, required BigInt feeRatePerKB}) {
    return (feeRatePerKB * BigInt.from(vSize) ~/ BigInt.from(1000)).toInt();
  }
}
