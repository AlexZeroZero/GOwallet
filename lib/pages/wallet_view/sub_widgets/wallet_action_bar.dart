import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../notifications/show_flush_bar.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/assets.dart';
import '../../../utilities/text_styles.dart';
import '../../../widgets/desktop/primary_button.dart';
import '../../../widgets/desktop/secondary_button.dart';
import '../../../widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';

/// Redesign of the wallet home's bottom controls: two full-width buttons —
/// Receive and Send — instead of the floating icon dock.
///
/// The coin-conditional actions the dock carried (Finalize, Sign, Swap, Buy,
/// Names, Tokens, …) are not dropped: whatever the wallet declares beyond
/// Receive/Send goes into a "more" sheet behind a third compact button, which
/// simply does not render for wallets that have nothing extra — the common
/// case, which then matches the mockups exactly. Hiding a working feature to
/// match a picture would be a regression, not a redesign.
///
/// On a view-only wallet Send renders locked rather than absent: the wallet
/// deliberately cannot sign, and a control that explains that beats one that
/// vanished. Tapping it says so instead of doing nothing.
///
/// Colour comes from the theme, not the coin. Chrome — buttons, links,
/// switches, the sync chip — is one set of controls that happens to be showing
/// a coin, so it stays put as you move between wallets; the coin colour is
/// reserved for the marks that identify the coin itself (its icon and its card
/// on the home list). Recolouring the accent per coin meant every theme's
/// contrast pairing had to be re-earned for each coin, which is how a
/// white-on-gold Save button shipped.
class WalletActionBar extends StatelessWidget {
  const WalletActionBar({
    super.key,
    required this.items,
    required this.moreItems,
    required this.viewOnly,
  });

  final List<WalletNavigationBarItemData> items;
  final List<WalletNavigationBarItemData> moreItems;
  final bool viewOnly;

  WalletNavigationBarItemData? _byAction(WalletAction action) {
    for (final e in items) {
      if (e.effectiveAction == action) return e;
    }
    return null;
  }

  void _showExtrasSheet(
    BuildContext context,
    List<WalletNavigationBarItemData> extras,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).extension<StackColors>()!.popupBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in extras)
                ListTile(
                  leading: item.icon,
                  title: Text(
                    item.label ?? "",
                    style: STextStyles.w500_14(context),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    item.onTap?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StackColors>()!;

    // The dock floats over a scrolling page, so it has to hide what passes
    // behind it. It used to be transparent and rely on a fade applied to the
    // whole page, which failed twice over: the fade began at 88% of the
    // viewport while the dock is taller than that, so rows arrived under the
    // buttons still at full opacity, and whatever cleared the dock was then
    // cut by the system navigation bar instead of ending anywhere.
    //
    // An opaque bar with a short gradient above it is the fix and is also
    // cheaper — the page-wide ShaderMask cost a saveLayer on every frame of
    // every scroll. The gradient fades a row into the bar rather than letting
    // it slide under a hard edge.
    //
    // Painted in popupBG, the card surface, not in `background`: a theme that
    // ships a background IMAGE leaves `background` transparent so the artwork
    // shows through, and a bar painted in it covers nothing at all — which is
    // exactly how the first cut of this shipped, opaque on the bundled themes
    // and see-through on a downloaded one. popupBG has to be opaque or the
    // transaction cards it paints would not be readable either. alphaBlend is
    // the backstop for a theme that makes even that translucent.
    final bar = _opaque(colors.popupBG, Theme.of(context).brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bar.withOpacity(0), bar],
            ),
          ),
        ),
        ColoredBox(color: bar, child: _buttons(context, colors)),
      ],
    );
  }

  /// [c] over the theme's own floor, so the result can be relied on to hide
  /// whatever scrolls behind it.
  static Color _opaque(Color c, Brightness brightness) => c.alpha == 255
      ? c
      : Color.alphaBlend(
          c,
          brightness == Brightness.dark ? Colors.black : Colors.white,
        );

  Widget _buttons(BuildContext context, StackColors colors) {
    final receive = _byAction(WalletAction.receive);
    final send = _byAction(WalletAction.send);
    final extras = [
      ...items.where((e) => e.effectiveAction == WalletAction.other),
      ...moreItems,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            if (receive != null)
              Expanded(
                child: SecondaryButton(
                  label: goTr(context, "收款"),
                  onPressed: receive.onTap,
                ),
              ),
            if (receive != null) const SizedBox(width: 12),
            Expanded(
              child: (viewOnly || send == null)
                  ? SecondaryButton(
                      label: goTr(context, "发送"),
                      icon: SvgPicture.asset(
                        Assets.svg.lock,
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(
                          colors.buttonTextSecondary.withOpacity(0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () {
                        showFloatingFlushBar(
                          type: FlushBarType.info,
                          message: goTr(context, "这是观察钱包，可收款和查看交易，但没有签名所需的私钥。"),
                          context: context,
                        );
                      },
                    )
                  : PrimaryButton(
                      label: goTr(context, "发送"),
                      onPressed: send.onTap,
                    ),
            ),
            if (extras.isNotEmpty) const SizedBox(width: 12),
            if (extras.isNotEmpty)
              SecondaryButton(
                width: 56,
                icon: Icon(
                  Icons.more_horiz,
                  size: 22,
                  color: colors.buttonTextSecondary,
                ),
                onPressed: () => _showExtrasSheet(context, extras),
              ),
          ],
        ),
      ),
    );
  }
}
