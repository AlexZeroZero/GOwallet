import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/isar/models/contract.dart';
import '../../providers/global/locale_provider.dart';
import '../../providers/global/prefs_provider.dart';
import '../../wallets/crypto_currency/crypto_currency.dart';
import 'amount.dart';
import 'amount_unit.dart';

final pAmountUnit = Provider.family<AmountUnit, CryptoCurrency>(
  (ref, coin) => ref.watch(
    prefsChangeNotifierProvider.select((value) => value.amountUnit(coin)),
  ),
);
final pMaxDecimals = Provider.family<int, CryptoCurrency>(
  (ref, coin) => ref.watch(
    prefsChangeNotifierProvider.select((value) => value.maxDecimals(coin)),
  ),
);

final pAmountFormatter = Provider.family<AmountFormatter, CryptoCurrency>((
  ref,
  coin,
) {
  final locale = ref.watch(
    localeServiceChangeNotifierProvider.select((value) => value.locale),
  );

  return AmountFormatter(
    unit: ref.watch(pAmountUnit(coin)),
    locale: locale,
    coin: coin,
    maxDecimals: ref.watch(pMaxDecimals(coin)),
  );
});

class AmountFormatter {
  final AmountUnit unit;
  final String locale;
  final CryptoCurrency coin;
  final int maxDecimals;

  AmountFormatter({
    required this.unit,
    required this.locale,
    required this.coin,
    required this.maxDecimals,
  });

  String format(
    Amount amount, {
    String? overrideUnit,
    Contract? tokenContract,
    bool withUnitName = true,
    // Off by default. This prefixed a "~" whenever the displayed decimals
    // hid a non-zero digit, which put a tilde in front of most balances on a
    // coin with eight decimals. The user chooses how many decimals to show
    // (Settings > Advanced > Manage coin units), so annotating their own
    // choice as imprecise tells them nothing and reads as noise on the one
    // number they came to look at. The two token send screens that genuinely
    // mean "approximately this much" pass true explicitly.
    bool indicatePrecisionLoss = false,
    // Drop decimals that are only zeros: 10,000.00000000 becomes 10,000, and
    // 10,000.00226000 becomes 10,000.00226. Never adds precision — the user's
    // own maxDecimals is still the ceiling — and never changes the value,
    // since trailing zeros carry no information.
    //
    // Off by default so balances keep their fixed width, which is what makes
    // a column of them scannable. The transaction list turns it on: there the
    // amount shares a row with a label, and eight zeros of nothing were wide
    // enough to push "Mining payout" into "Mining p...".
    bool trimTrailingZeros = false,
  }) {
    return unit.displayAmount(
      amount: amount,
      locale: locale,
      coin: coin,
      maxDecimalPlaces: trimTrailingZeros
          ? _significantDecimals(amount, maxDecimals)
          : maxDecimals,
      withUnitName: withUnitName,
      indicatePrecisionLoss: indicatePrecisionLoss,
      overrideUnit: overrideUnit,
      tokenContract: tokenContract,
    );
  }

  /// Decimal places [amount] actually needs, never more than [ceiling].
  ///
  /// Counted on the raw integer rather than by trimming the formatted string,
  /// because which character is the decimal separator depends on the locale —
  /// a de-DE 1.234,50 would have its thousands mark read as the decimal point
  /// and lose three orders of magnitude.
  static int _significantDecimals(Amount amount, int ceiling) {
    final digits = amount.fractionDigits;
    if (digits <= 0) return 0;

    var fraction = amount.raw.abs() % BigInt.from(10).pow(digits);
    if (fraction == BigInt.zero) return 0;

    var places = digits;
    final ten = BigInt.from(10);
    while (places > 0 && fraction % ten == BigInt.zero) {
      fraction = fraction ~/ ten;
      places--;
    }
    return places < ceiling ? places : ceiling;
  }

  Amount? tryParse(String string, {Contract? tokenContract}) {
    return unit.tryParse(
      string,
      locale: locale,
      coin: coin,
      tokenContract: tokenContract,
    );
  }
}
