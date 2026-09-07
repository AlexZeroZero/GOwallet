/*
 * This file is part of BitFinite Wallet.
 *
 * Shortening balances that are too large to read at full precision.
 */

/// [formatted] with its sub-coin decimals removed, or null when the amount is
/// small enough to show in full.
///
/// The hero balance sits in a FittedBox, so an over-long number does not clip,
/// it shrinks: 4,946,461,530.06954205 is twenty two characters and squeezed
/// the headline figure down until it stopped reading as the headline.
///
/// This drops ONLY the fraction, never the magnitude, so the result stays
/// exact to a whole coin and still reads as money: 4,946,461,530 PEP. An
/// earlier version abbreviated to 4.9464B, which was worse on both counts. It
/// hid 46,153 PEP behind a notation nobody uses for balances, and four
/// decimals on a "B" implied a precision it did not have. Grouping already
/// gives the eye the magnitude without anyone having to trust an abbreviation.
///
/// Works on the formatted string rather than the number so it inherits the
/// user's locale: the separators are wherever the formatter put them.
String? withoutDustDecimals(String formatted, {int minWholeDigits = 8}) {
  final sepIdx = formatted.lastIndexOf(RegExp(r"[.,]"));
  if (sepIdx <= 0) return null;

  // A grouping separator is always followed by exactly three digits, so a
  // longer tail means this one is the decimal separator. Without this check a
  // locale that groups with "." (1.234.567) would have its number truncated
  // rather than its decimals dropped.
  final decimals = formatted.substring(sepIdx + 1);
  if (decimals.length <= 3) return null;

  final whole = formatted.substring(0, sepIdx);

  // The default eight digits is set from what actually rendered rather than a
  // round number. On the device 1,698,563.93476559 (seven digits) sat at full
  // size and read fine, while 4,167,211,864.71684370 (ten digits) was visibly
  // shrunk. Anything that fits keeps every digit it had.
  //
  // Callers showing a summary rather than the balance pass a lower threshold:
  // on the payouts row the eight decimals were pure noise, and they squeezed
  // the payout count down to "99...".
  final digitCount = whole.replaceAll(RegExp(r"[^0-9]"), "").length;
  if (digitCount < minWholeDigits) return null;

  return whole;
}
