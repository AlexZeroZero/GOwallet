/// Best-effort national flag emoji for an ISO-4217 currency code.
///
/// The first two letters of a currency code are almost always the ISO-3166
/// country code (USD -> US, AUD -> AU, EUR -> EU), which maps directly onto the
/// regional-indicator code points that render as a flag. Returns null for codes
/// that have no country (X-prefixed metals/special drawing rights such as XAU,
/// XAG, XDR) so callers can fall back gracefully.
/// Crypto / non-country units that appear in the base-currency list. Their
/// first two letters collide with real country codes (BTC -> BT Bhutan,
/// ETH -> ET Ethiopia, LTC -> LT Lithuania, BNB -> BN Brunei, DOT -> DO
/// Dominican Republic, LINK -> LI Liechtenstein), so they must be excluded
/// rather than flagged.
const Set<String> _nonCountryCodes = {
  "BTC",
  "ETH",
  "LTC",
  "BCH",
  "BNB",
  "EOS",
  "XRP",
  "XLM",
  "LINK",
  "DOT",
  "YFI",
  "SATS",
};

String? currencyFlagEmoji(String currencyCode) {
  if (currencyCode.length < 2) return null;

  if (_nonCountryCodes.contains(currencyCode.toUpperCase())) return null;

  final code = currencyCode.substring(0, 2).toUpperCase();

  // X-prefixed codes are metals / special units, not countries.
  if (code.startsWith("X")) return null;

  final first = code.codeUnitAt(0);
  final second = code.codeUnitAt(1);

  const a = 0x41; // 'A'
  const z = 0x5A; // 'Z'
  if (first < a || first > z || second < a || second > z) return null;

  const regionalIndicatorA = 0x1F1E6;
  return String.fromCharCodes([
    regionalIndicatorA + (first - a),
    regionalIndicatorA + (second - a),
  ]);
}
