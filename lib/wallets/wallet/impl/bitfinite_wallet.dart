import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:isar_community/isar.dart';

import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/isar/models/blockchain_data/transaction.dart';
import '../../../models/isar/models/blockchain_data/v2/input_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/output_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../services/coins/bitcoincash/bch_utils.dart';
import '../../../services/coins/bitcoincash/cashtokens.dart' as cash_tokens;
import '../../../utilities/amount/amount.dart';
import '../../../utilities/bfx_cashaddr.dart';
import '../../../models/notification_model.dart';
import '../../../services/notifications_service.dart';
import '../../../utilities/extensions/extensions.dart';
import '../../../utilities/logger.dart';
import '../../../utilities/prefs.dart';
import '../../crypto_currency/crypto_currency.dart';
import '../../isar/models/wallet_info.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_wallet.dart';
import '../wallet_mixin_interfaces/bcash_interface.dart';
import '../wallet_mixin_interfaces/coin_control_interface.dart';
import '../wallet_mixin_interfaces/electrumx_interface.dart';
import '../wallet_mixin_interfaces/extended_keys_interface.dart';

/// BitFinite (BFX) wallet — a faithful adaptation of BitcoincashWallet.
///
/// Differences from BCH:
///  - super(Bitfinite(network)) and single derivation path (m/44'/9116').
///  - CashFusionInterface dropped (no BFX fusion servers). BCashInterface is
///    KEPT because BFX signs with BCH-style SIGHASH_FORKID (fork id 0 — verified
///    against bitfinite-core: identical to BCH, so BCH tx-building/signing is
///    correct as-is).
///  - The two bitbox cashaddr calls (convertAddressString / normalizeAddress)
///    are routed through BfxCashAddr because BFX uses a custom base32 alphabet
///    (q<->f swapped) — stock bitbox would emit/verify the wrong strings.
///
/// The token/SLP/fusion *detection* in checkBlockUTXO + tx classification is kept
/// as a safety net (harmless if BFX has no tokens active).
class BitfiniteWallet<T extends ElectrumXCurrencyInterface>
    extends Bip39HDWallet<T>
    with
        ElectrumXInterface<T>,
        ExtendedKeysInterface<T>,
        BCashInterface<T>,
        CoinControlInterface<T> {
  @override
  int get isarTransactionVersion => 2;

  BitfiniteWallet(CryptoCurrencyNetwork network)
    : super(Bitfinite(network) as T);

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
        .typeEqualTo(AddressType.nonWallet)
        .and()
        .group(
          (q) => q
              .subTypeEqualTo(AddressSubType.receiving)
              .or()
              .subTypeEqualTo(AddressSubType.change),
        )
        .findAll();
    return allAddresses;
  }

  /// Convert a stored legacy (base58) address to BFX cashaddr for display and
  /// for matching against ElectrumX-reported output addresses.
  ///
  /// NOTE: confirm the exact address string electr-bfx returns in tx vout JSON
  /// during the first sync test, and make sure both sides use the same canonical
  /// form (BFX cashaddr here). If electr-bfx returns base58, drop this conversion.
  @override
  String convertAddressString(String address) {
    if (address.startsWith("1") || address.startsWith("3")) {
      final decoded = bs58check.decode(address);
      final type = decoded[0] == cryptoCurrency.networkParams.p2shPrefix
          ? BfxCashAddr.typeP2SH
          : BfxCashAddr.typeP2PKH;
      return BfxCashAddr.encode(
        hash160: Uint8List.fromList(decoded.sublist(1)),
        type: type,
        prefix: BfxCashAddr.mainnetPrefix,
      );
    }
    return address;
  }

  // ===========================================================================

  @override
  Future<void> updateTransactions() async {
    final List<Address> allAddressesOld =
        await fetchAddressesForElectrumXScan();

    final Set<String> receivingAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.receiving)
        .map((e) => convertAddressString(e.value))
        .toSet();

    final Set<String> changeAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.change)
        .map((e) => convertAddressString(e.value))
        .toSet();

    final allAddressesSet = {...receivingAddresses, ...changeAddresses};

    final List<Map<String, dynamic>> fullHistory = await fetchHistory(
      allAddressesSet,
    );

    // See maxHistoryToWalk: a pool or exchange address cannot be walked in
    // full. Balance is unaffected, it comes from UTXOs.
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

    // This wallet re-reads every transaction each sync rather than skipping
    // ones already stored, so it leans entirely on the tx cache. Batching the
    // fetch is what keeps that affordable once an address has real history.
    final fetched = await fetchTransactionsBulk(
      allTxHashes.map((e) => e["tx_hash"] as String),
    );

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
    for (final txHash in allTxHashes) {
      final tx = fetched[txHash["tx_hash"] as String];
      if (tx == null) continue;
      if (allTransactions.indexWhere((e) => e["txid"] == tx["txid"]) == -1) {
        tx["height"] = txHash["height"];
        allTransactions.add(tx);
      }
    }

    final List<TransactionV2> txns = [];

    for (final txData in allTransactions) {
      bool wasSentFromThisWallet = false;
      bool wasReceivedInThisWallet = false;
      BigInt amountReceivedInThisWallet = BigInt.zero;
      BigInt changeAmountReceivedInThisWallet = BigInt.zero;

      // parse inputs
      final List<InputV2> inputs = [];
      for (final jsonInput in txData["vin"] as List) {
        final map = Map<String, dynamic>.from(jsonInput as Map);

        final List<String> addresses = [];
        String valueStringSats = "0";
        OutpointV2? outpoint;

        final coinbase = map["coinbase"] as String?;

        if (coinbase == null) {
          final txid = map["txid"] as String;
          final vout = map["vout"] as int;

          // Fetched in the batched pass above; the single call is only a
          // safety net for an id the batch could not return.
          final inputTx =
              prevouts[txid] ??
              await electrumXCachedClient.getTransaction(
                txHash: txid,
                cryptoCurrency: cryptoCurrency,
              );

          try {
            final prevOutJson = Map<String, dynamic>.from(
              (inputTx["vout"] as List).firstWhere((e) => e["n"] == vout)
                  as Map,
            );
            final prevOut = OutputV2.fromElectrumXJson(
              prevOutJson,
              decimalPlaces: cryptoCurrency.fractionDigits,
              walletOwns: false,
              isFullAmountNotSats: true,
            );

            outpoint = OutpointV2.isarCantDoRequiredInDefaultConstructor(
              txid: txid,
              vout: vout,
            );
            valueStringSats = prevOut.valueStringSats;
            addresses.addAll(prevOut.addresses);
          } catch (e, s) {
            Logging.instance.w(
              "Error getting prevOutJson: $e\nStack trace: $s",
              error: e,
              stackTrace: s,
            );
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
          walletOwns: false,
        );

        if (allAddressesSet.intersection(input.addresses.toSet()).isNotEmpty) {
          wasSentFromThisWallet = true;
          input = input.copyWith(walletOwns: true);
        }

        inputs.add(input);
      }

      // parse outputs
      final List<OutputV2> outputs = [];
      for (final outputJson in txData["vout"] as List) {
        OutputV2 output = OutputV2.fromElectrumXJson(
          Map<String, dynamic>.from(outputJson as Map),
          decimalPlaces: cryptoCurrency.fractionDigits,
          walletOwns: false,
          isFullAmountNotSats: true,
        );

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
      TransactionSubType subType = TransactionSubType.none;

      if (wasSentFromThisWallet) {
        type = TransactionType.outgoing;

        if (wasReceivedInThisWallet) {
          if (changeAmountReceivedInThisWallet + amountReceivedInThisWallet ==
              totalOut) {
            type = TransactionType.sentToSelf;
          } else if (amountReceivedInThisWallet == BigInt.zero) {
            // typical send
          }

          if (outputs.isNotEmpty) {
            final output = outputs.first;
            if (BchUtils.isFUZE(output.scriptPubKeyHex.toUint8ListFromHex)) {
              subType = TransactionSubType.cashFusion;
            }
          }
        }
      } else if (wasReceivedInThisWallet) {
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

    await _fireNewTxNotifications(txns);

    await mainDB.updateOrPutTransactionV2s(txns);
  }

  /// Fire in-app + OS notifications for newly-seen transactions (incoming and
  /// outgoing) so the notification bell badge updates.
  ///
  /// Upstream Stack Wallet never re-wired transaction notifications into the new
  /// wallet architecture — the old TransactionNotificationTracker is commented
  /// out in services/wallets.dart and nothing else fires CryptoNotificationEvent
  /// — so without this the bell never shows new-transaction notifications.
  ///
  /// A tx notifies at most once: after it is first discovered it is persisted,
  /// so subsequent syncs find it in [knownTxids] and skip it. To avoid a
  /// restore/initial sync spamming the whole history, only *fresh* activity is
  /// announced (still pending, or confirmed within the last couple of hours);
  /// old confirmed history is seeded silently.
  Future<void> _fireNewTxNotifications(List<TransactionV2> txns) async {
    try {
      final knownTxids = (await mainDB.isar.transactionV2s
              .where()
              .walletIdEqualTo(walletId)
              .txidProperty()
              .findAll())
          .toSet();

      // Existing tx notifications for this wallet, keyed by txid, so a pending
      // one can be flipped to confirmed once its tx is mined into a block.
      final existingByTxid = <String, NotificationModel>{};
      for (final n in NotificationsService.instance.notifications) {
        if (n.walletId == walletId && n.txid != null) {
          existingByTxid[n.txid!] = n;
        }
      }

      final nowSecs = DateTime.timestamp().millisecondsSinceEpoch ~/ 1000;
      const freshnessWindowSecs = 2 * 60 * 60; // 2h
      const pendingSuffix = " (pending)";

      var fired = 0;
      var confirmed = 0;
      for (final tx in txns) {
        final isPending = tx.height == null || tx.height == 0;

        final existing = existingByTxid[tx.txid];
        if (existing != null) {
          // Already announced. When a pending tx lands in a block, flip its
          // notification from "(pending)" to confirmed. BFX is zeroconf, so
          // "confirmed" here means mined (has a block height), not a
          // minConfirms count. Preserve read state so it doesn't re-badge.
          if (!isPending && existing.title.endsWith(pendingSuffix)) {
            await NotificationsService.instance.add(
              existing.copyWith(
                title: existing.title.substring(
                  0,
                  existing.title.length - pendingSuffix.length,
                ),
              ),
              true,
            );
            confirmed++;
          }
          continue;
        }

        if (knownTxids.contains(tx.txid)) continue; // seeded silently, don't announce

        final isFresh =
            isPending || (nowSecs - tx.timestamp) < freshnessWindowSecs;
        if (!isFresh) continue; // silently seed old history

        final incoming = tx.type == TransactionType.incoming;
        final base = incoming ? "Received transaction" : "Sent transaction";

        // Write the in-app notification directly to the shared
        // NotificationsService singleton (which notificationsProvider watches),
        // rather than firing CryptoNotificationEvent. That event bus is a
        // separate instance with no reliably-attached listener, so fires were
        // silently dropped and the bell badge never updated.
        await Prefs.instance.incrementCurrentNotificationIndex();
        final model = NotificationModel(
          id: Prefs.instance.currentNotificationId,
          title: isPending ? "$base$pendingSuffix" : base,
          description: info.name,
          iconAssetName: "",
          date: DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000),
          walletId: walletId,
          read: false,
          shouldWatchForUpdates: false,
          coinName: cryptoCurrency.identifier,
          txid: tx.txid,
        );
        await NotificationsService.instance.add(model, true);
        fired++;
      }

      if (fired > 0 || confirmed > 0) {
        Logging.instance.i(
          "BFX tx notifications: $fired new, $confirmed confirmed",
        );
      }
    } catch (e, s) {
      Logging.instance.w(
        "fireNewTxNotifications failed",
        error: e,
        stackTrace: s,
      );
    }
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

    if (scriptPubKeyHex != null) {
      // Block accidental spends of token outputs (safety net).
      try {
        final ctOutput = cash_tokens.unwrap_spk(
          scriptPubKeyHex.toUint8ListFromHex,
        );
        if (ctOutput.token_data != null) {
          blocked = true;
          blockedReason = "Cash token output detected";
        }
      } catch (e, s) {
        Logging.instance.w(
          "Script pub key cash token parsing check failed",
          error: e,
          stackTrace: s,
        );
      }

      if (!blocked && BchUtils.isSLP(scriptPubKeyHex.toUint8ListFromHex)) {
        blocked = true;
        blockedReason = "SLP token output detected";
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
      fractionDigits: info.coin.fractionDigits,
    );
  }

  @override
  int estimateTxFee({required int vSize, required BigInt feeRatePerKB}) {
    return (feeRatePerKB * BigInt.from(vSize) ~/ BigInt.from(1000)).toInt();
  }

  @override
  String normalizeAddress(String address) {
    try {
      if (BfxCashAddr.isValid(address)) {
        final d = BfxCashAddr.decode(address);
        final version = d.type == BfxCashAddr.typeP2SH
            ? cryptoCurrency.networkParams.p2shPrefix
            : cryptoCurrency.networkParams.p2pkhPrefix;
        return bs58check.encode(
          Uint8List.fromList([version, ...d.hash160]),
        );
      }
      return address;
    } catch (_) {
      return address;
    }
  }
}
