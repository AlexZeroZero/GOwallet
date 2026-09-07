import 'package:flutter/foundation.dart';
import 'package:bitfinite/utilities/prefs.dart';

class PortfolioTestPrefs extends ChangeNotifier implements Prefs {
  @override
  String currency = 'USD';
  @override
  bool externalCalls = false;
  @override
  String language = 'English (US)';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
