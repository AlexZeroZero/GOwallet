import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/material.dart';

import '../../utilities/util.dart';
import '../stack_dialog.dart';

class FiroExchangeAddressDialog extends StatelessWidget {
  const FiroExchangeAddressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return StackOkDialog(
      title: goTr(context, "Firo exchange address detected"),
      message: goTr(
        context,
        "Sending to an exchange address from a Spark balance is not allowed. Please send from your transparent balance.",
      ),
      desktopPopRootNavigator: Util.isDesktop,
      maxWidth: Util.isDesktop ? 500 : null,
    );
  }
}

Future<void> showFiroExchangeAddressWarning(
  BuildContext context,
  VoidCallback onClosed,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const FiroExchangeAddressDialog(),
  );
  onClosed();
}
