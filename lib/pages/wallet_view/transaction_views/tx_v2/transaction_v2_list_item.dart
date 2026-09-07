import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuple/tuple.dart';

import '../../../../models/exchange/response_objects/trade.dart';
import '../../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../../models/isar/models/isar_models.dart';
import '../../../../providers/global/trades_service_provider.dart';
import '../../../../route_generator.dart';
import '../../../../themes/stack_colors.dart';
import '../../../../utilities/text_styles.dart';
import '../../../../utilities/util.dart';
import '../../../../wallets/crypto_currency/crypto_currency.dart';
import '../../../../wallets/isar/providers/wallet_info_provider.dart';
import '../../../../widgets/breathing.dart';
import '../../../../widgets/desktop/desktop_dialog.dart';
import '../../../../widgets/desktop/desktop_dialog_close_button.dart';
import '../../../../widgets/trade_card.dart';
import '../../../exchange_view/trade_details_view.dart';
import 'fusion_tx_group_card.dart';
import 'transaction_v2_card.dart';

class TxListItem extends ConsumerWidget {
  const TxListItem({
    super.key,
    required this.tx,
    this.radius,
    this.grouped = false,
    required this.coin,
  }) : assert(tx is TransactionV2 || tx is FusionTxGroup);

  final Object tx;
  final BorderRadius? radius;
  final CryptoCurrency coin;

  /// Rendered inside one grouped card rather than as its own card.
  ///
  /// The list used to be a stack of separate cards, each with its own fill,
  /// radius and hairline. The design groups a day's rows into a single card,
  /// so each row drops its own chrome — otherwise it is a card inside a card,
  /// and the doubled edges read as a rendering fault.
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tx is TransactionV2) {
      final _tx = tx as TransactionV2;

      final Iterable<Trade> matchingTrades =
          _tx.type == TransactionType.outgoing && _tx.txid.isNotEmpty
          ? ref
                .read(tradesServiceProvider)
                .trades
                .where(
                  (e) => e.payInTxid == _tx.txid || e.payOutTxid == _tx.txid,
                )
          : [];

      final txKeyString = _tx.txid + _tx.type.name + _tx.hashCode.toString();

      if (matchingTrades.isNotEmpty) {
        final trade = matchingTrades.first;
        // Same card treatment as the plain row below — a tx with a matching
        // trade is still one item in the list and must not read as a
        // different kind of thing.
        return Container(
          margin: grouped ? EdgeInsets.zero : const EdgeInsets.only(bottom: 4),
          decoration: grouped
              ? null
              : BoxDecoration(
                  color: Theme.of(context).extension<StackColors>()!.popupBG,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).extension<StackColors>()!.textSubtitle1.withOpacity(0.1),
                    width: 1,
                  ),
                ),
          clipBehavior: grouped ? Clip.none : Clip.antiAlias,
          child: Breathing(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TransactionCardV2(key: Key(txKeyString), transaction: _tx),
                TradeCard(
                  key: Key(txKeyString + trade.uuid),
                  trade: trade,
                  onTap: () async {
                    if (Util.isDesktop) {
                      await showDialog<void>(
                        context: context,
                        builder: (context) => Navigator(
                          initialRoute: TradeDetailsView.routeName,
                          onGenerateRoute: RouteGenerator.generateRoute,
                          onGenerateInitialRoutes: (_, __) {
                            return [
                              FadePageRoute(
                                DesktopDialog(
                                  maxHeight: null,
                                  maxWidth: 580,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 32,
                                          bottom: 16,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              goTr(context, "Trade details"),
                                              style: STextStyles.desktopH3(
                                                context,
                                              ),
                                            ),
                                            DesktopDialogCloseButton(
                                              onPressedOverride: Navigator.of(
                                                context,
                                                rootNavigator: true,
                                              ).pop,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: TradeDetailsView(
                                          tradeId: trade.tradeId,
                                          // TODO: [prio:med]
                                          // transactionIfSentFromStack: tx,
                                          transactionIfSentFromStack: null,
                                          walletName: ref.watch(
                                            pWalletName(_tx.walletId),
                                          ),
                                          walletId: _tx.walletId,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const RouteSettings(
                                  name: TradeDetailsView.routeName,
                                ),
                              ),
                            ];
                          },
                        ),
                      );
                    } else {
                      unawaited(
                        Navigator.of(context).pushNamed(
                          TradeDetailsView.routeName,
                          arguments: Tuple4(
                            trade.tradeId,
                            _tx,
                            _tx.walletId,
                            ref.read(pWalletName(_tx.walletId)),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      } else {
        // Redesign: each transaction is its own card on the page background,
        // not a row divided by a hairline. popupBG is the "raised surface"
        // token — #FFFFFF in the light theme, #1A2130 in dark — so the card
        // reads correctly in both without hardcoding the design's #FFFFFF.
        return Container(
          margin: grouped ? EdgeInsets.zero : const EdgeInsets.only(bottom: 4),
          decoration: grouped
              ? null
              : BoxDecoration(
                  color: Theme.of(context).extension<StackColors>()!.popupBG,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).extension<StackColors>()!.textSubtitle1.withOpacity(0.1),
                    width: 1,
                  ),
                ),
          // The card clips its child so the row's own ink/splash cannot paint
          // over the rounded corners when tapped.
          clipBehavior: grouped ? Clip.none : Clip.antiAlias,
          child: Breathing(
            child: TransactionCardV2(
              // this may mess with combined firo transactions
              key: Key(txKeyString),
              transaction: _tx,
            ),
          ),
        );
      }
    }

    final group = tx as FusionTxGroup;

    return Container(
      decoration: grouped
          ? null
          : BoxDecoration(
              color: Theme.of(context).extension<StackColors>()!.popupBG,
              borderRadius: radius,
            ),
      child: Breathing(
        child: FusionTxGroupCard(key: ObjectKey(group), group: group),
      ),
    );
  }
}
