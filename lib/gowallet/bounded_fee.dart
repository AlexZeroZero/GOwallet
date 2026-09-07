import 'package:decimal/decimal.dart';

/// Bound untrusted numeric text before Decimal allocates powers of ten.
Decimal parseBoundedElectrumFee(Object? response) {
  if (response is! num && response is! String) {
    throw const FormatException('Invalid fee estimate');
  }
  final text = response.toString();
  if (text.length > 48) throw const FormatException('Invalid fee estimate');
  final match = RegExp(
    r'^-?\d{1,20}(?:\.\d{1,18})?(?:[eE]([+-]?\d{1,2}))?$',
  ).firstMatch(text);
  if (match == null ||
      (match.group(1) != null && int.parse(match.group(1)!).abs() > 18)) {
    throw const FormatException('Invalid fee estimate');
  }
  return Decimal.parse(text);
}
