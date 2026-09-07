import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/material.dart';
import '../pages/pinpad_views/lock_screen_view.dart';

/// Separate from the navigation stack: asynchronous wallet routes cannot pop it.
final goSessionLocked = ValueNotifier(false);

class GoSessionGate extends StatelessWidget {
  const GoSessionGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: goSessionLocked,
    child: child,
    builder: (context, locked, content) => Stack(
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: ExcludeFocus(
            excluding: locked,
            child: AbsorbPointer(absorbing: locked, child: content!),
          ),
        ),
        if (locked)
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => LockscreenView(
                    embedded: true,
                    routeOnSuccess: '',
                    biometricsAuthenticationTitle: goTr(context, "解锁 GOwallet"),
                    biometricsLocalizedReason: goTr(context, "验证身份后继续操作钱包"),
                    biometricsCancelButtonString: goTr(context, "使用 PIN"),
                    onSuccess: () => goSessionLocked.value = false,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
