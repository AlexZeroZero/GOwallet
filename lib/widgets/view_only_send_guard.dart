import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
/*
 * Refuses a send screen for a wallet that cannot sign.
 *
 * Hiding the Send control is a convention: it holds only as long as every place
 * that can reach the send flow remembers to check. That already failed once —
 * the wallet view gated its dock item on `!viewOnly` while the Receive/Send
 * dock did not, so opening Receive on a watched address put Send straight back
 * on screen.
 *
 * This is the guarantee behind that convention. It sits on the route, so the
 * send form cannot be reached whatever pushes it: a dock that forgets the
 * check, a deep link, a restored navigation stack, or a screen added later.
 *
 * It explains rather than bounces. Popping on sight would look like a crash or
 * a dead tap, and the person did not do anything wrong — the wallet simply has
 * no keys.
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/global/wallets_provider.dart';
import '../themes/stack_colors.dart';
import '../utilities/text_styles.dart';
import '../wallets/wallet/wallet_mixin_interfaces/view_only_option_interface.dart';
import 'background.dart';
import 'custom_buttons/app_bar_icon_button.dart';
import 'desktop/primary_button.dart';

class ViewOnlySendGuard extends ConsumerWidget {
  const ViewOnlySendGuard({
    super.key,
    required this.walletId,
    required this.child,
  });

  final String walletId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Looked up by hand rather than through getWallet, which throws on an
    // unknown id. A route this guard cannot resolve is not the guard's problem
    // to report, so it steps aside and lets the page handle it.
    Object? wallet;
    for (final w in ref.watch(pWallets).wallets) {
      if (w.walletId == walletId) {
        wallet = w;
        break;
      }
    }
    if (wallet == null) return child;
    if (!(wallet is ViewOnlyOptionInterface && wallet.isViewOnly)) return child;

    final colors = Theme.of(context).extension<StackColors>()!;

    return Background(
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: AppBarBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            goTr(context, "Send"),
            style: STextStyles.navBarTitle(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    goTr(context, "This wallet is view only"),
                    textAlign: TextAlign.center,
                    style: STextStyles.pageTitleH2(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    // Says what is missing and what it would take, rather than
                    // only that the door is shut.
                    goTr(
                      context,
                      "It was added from an address, so it holds no private key and cannot sign a transaction. Restore this wallet from its recovery phrase to send from it.",
                    ),
                    textAlign: TextAlign.center,
                    style: STextStyles.itemSubtitle(context),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: goTr(context, "Go back"),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
