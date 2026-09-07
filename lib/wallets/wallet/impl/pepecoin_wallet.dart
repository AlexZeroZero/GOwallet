import 'package:isar_community/isar.dart';

import '../../../gowallet/verified_prevouts.dart';
import '../../../models/input.dart';
import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/isar/models/blockchain_data/transaction.dart';
import '../../../models/isar/models/blockchain_data/v2/input_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/output_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/extensions/extensions.dart';
import '../../../utilities/logger.dart';
import '../../crypto_currency/crypto_currency.dart';
import '../../isar/models/wallet_info.dart';
import '../../models/tx_data.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_wallet.dart';
import '../wallet_mixin_interfaces/coin_control_interface.dart';
import '../wallet_mixin_interfaces/electrumx_interface.dart';
import '../wallet_mixin_interfaces/extended_keys_interface.dart';

class PepecoinWallet<T extends ElectrumXCurrencyInterface>
    extends Bip39HDWallet<T>
    with ElectrumXInterface<T>, ExtendedKeysInterface<T>, CoinControlInterface {
  PepecoinWallet(CryptoCurrencyNetwork network) : super(Pepecoin(network) as T);

  /// Reuse the standard Bitcoin-format transaction history and signing flow.
  PepecoinWallet.forCurrency(T currency) : super(currency);

  final _verifiedPrevouts = VerifiedPrevouts();

  @override
  Future<TxData> buildTransaction({
    required TxData txData,
    required List<BaseInput> inputsWithKeys,
  }) async {
    await _verifiedPrevouts.verify(
      inputs: inputsWithKeys,
      currency: cryptoCurrency,
      fetchRaw: (id) async =>
          (await electrumXClient.getTransaction(
                txHash: id,
                verbose: false,
              ))['rawtx']
              as String,
    );
    return super.buildTransaction(
      txData: txData,
      inputsWithKeys: inputsWithKeys,
    );
  }

  @override
  void validateBroadcastResponse(String raw, String txid) =>
      VerifiedPrevouts.checkBroadcast(raw, txid);

  @override
  int get maximumFeerate => 2500000; // 1000x default value

  @override
  int get isarTransactionVersion => 2;

  @override
  FilterOperation? get changeAddressFilterOperation =>
      FilterGroup.and(standardChangeAddressFilters);

  @override
  FilterOperation? get receivingAddressFilterOperation =>
      FilterGroup.and(standardReceivingAddressFilters);

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

    // Fetch history from ElectrumX.
    final List<Map<String, dynamic>> fullHistory = await fetchHistory(
      allAddressesSet,
    );

    // Exchange and pool addresses carry tens of thousands of transactions and
    // cannot be walked in full; see maxHistoryToWalk for the measurements.
    // The balance is unaffected because it comes from UTXOs.
    final allTxHashes = capHistory(fullHistory);
    final truncated = fullHistory.length > allTxHashes.length;
    if (truncated) {
      Logging.instance.w(
        "${info.name}: address history is ${fullHistory.length} txs, "
        "walking the most recent ${allTxHashes.length}. Balance is unaffected.",
      );
    }
    await info.updateOtherData(
      newEntries: {
        WalletInfoKeys.historyTruncatedTotal: truncated
            ? fullHistory.length
            : null,
      },
      isar: mainDB.isar,
    );

    // Work out which of those we do not already hold, then fetch them in
    // batches rather than one round trip each.
    final List<String> needed = [];
    final Map<String, dynamic> heightByTxid = {};
    for (final txHash in allTxHashes) {
      final txid = txHash["tx_hash"] as String;
      heightByTxid[txid] = txHash["height"];

      final storedTx = await mainDB.isar.transactionV2s
          .where()
          .txidWalletIdEqualTo(txid, walletId)
          .findFirst();

      if (storedTx == null ||
          storedTx.height == null ||
          (storedTx.height != null && storedTx.height! <= 0)) {
        needed.add(txid);
      }
    }

    final fetched = await fetchTransactionsBulk(needed);

    // Every input needs its previous transaction to be priced. Collecting the
    // ids first means one batched pass instead of a round trip per input,
    // which on a 8.5-inputs-per-tx address was most of the sync time.
    final Set<String> prevoutIds = {};
    for (final tx in fetched.values) {
      for (final vin in (tx["vin"] as List? ?? [])) {
        final map = Map<String, dynamic>.from(vin as Map);
        if (map["coinbase"] == null && map["txid"] is String) {
          prevoutIds.add(map["txid"] as String);
        }
      }
    }
    final prevouts = await fetchTransactionsBulk(prevoutIds);

    final List<Map<String, dynamic>> allTransactions = [];
    for (final txid in needed) {
      final tx = fetched[txid];
      if (tx == null) continue;
      if (allTransactions.indexWhere((e) => e["txid"] == tx["txid"]) == -1) {
        tx["height"] = heightByTxid[txid];
        allTransactions.add(tx);
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

          // Already fetched in the batched pass above; the single fetch is
          // only a safety net for an id the batch could not return.
          final inputTx =
              prevouts[txid] ??
              await electrumXCachedClient.getTransaction(
                txHash: txid,
                cryptoCurrency: cryptoCurrency,
              );

          final prevOutJson = Map<String, dynamic>.from(
            (inputTx["vout"] as List).firstWhere((e) => e["n"] == vout) as Map,
          );

          final prevOut = OutputV2.fromElectrumXJson(
            prevOutJson,
            decimalPlaces: cryptoCurrency.fractionDigits,
            isFullAmountNotSats: true,
            walletOwns: false, // Doesn't matter here as this is not saved.
          );

          outpoint = OutpointV2.isarCantDoRequiredInDefaultConstructor(
            txid: txid,
            vout: vout,
          );
          valueStringSats = prevOut.valueStringSats;
          addresses.addAll(prevOut.addresses);
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

          // Pepecoin inherits Dogecoin's output handling, including special
          // outputs like ordinals, which are unsupported here.
          // This is where we would check for them.
          // TODO: [prio=none] Check for special Pepecoin outputs.
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
