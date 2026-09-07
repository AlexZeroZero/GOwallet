import 'package:flutter/widgets.dart';
import 'go_catalog.dart';

/// The input comes only from TransactionV2.statusLabel, never a user note.
String goTransactionStatus(BuildContext context, String status) {
  final match = RegExp(
    r'^(Receiving|Sending|Sent to self|Anonymizing) (\(-?\d+/\d+\))$',
  ).firstMatch(status);
  if (match != null) return '${goTr(context, match[1]!)} ${match[2]}';
  return goTr(context, status);
}

/// Only presentation literals are translated. Arguments (addresses, wallet
/// names, amounts and other user data) are substituted verbatim, once.
String goTr(
  BuildContext context,
  String source, [
  List<Object?> args = const [],
]) => goTranslate(Localizations.localeOf(context).languageCode, source, args);

String goTranslate(
  String language,
  String source, [
  List<Object?> args = const [],
]) {
  final pair = goCatalog[source];
  final template = pair == null ? source : pair[language == 'zh' ? 0 : 1];
  return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final index = int.parse(match[1]!);
    return index < args.length ? '${args[index]}' : match[0]!;
  });
}
