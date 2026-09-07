import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:flutter/cupertino.dart';
import '../../wallets/crypto_currency/crypto_currency.dart';
import '../desktop/primary_button.dart';
import '../desktop/secondary_button.dart';
import 'basic_dialog.dart';

class TorWarningDialog extends StatelessWidget {
  final CryptoCurrency coin;
  final VoidCallback? onContinue;
  final VoidCallback? onCancel;

  const TorWarningDialog({
    super.key,
    required this.coin,
    this.onContinue,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return BasicDialog(
      title: goTr(context, "Warning!  Tor not supported."),
      message: goTr(
        context,
        "{0} is not compatible with Tor.  Continuing will leak your IP address.\n\nAre you sure you want to continue?",
        [coin.prettyName],
      ),
      // A PrimaryButton widget:
      leftButton: PrimaryButton(
        label: goTr(context, "Cancel"),
        onPressed: () {
          onCancel?.call();
          Navigator.of(context).pop(false);
        },
      ),
      rightButton: SecondaryButton(
        label: goTr(context, "Continue"),
        onPressed: () {
          onContinue?.call();
          Navigator.of(context).pop(true);
        },
      ),
      flex: true,
    );
  }
}
