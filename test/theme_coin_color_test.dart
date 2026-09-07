import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/theme_providers.dart';
import 'package:bitfinite/wallets/crypto_currency/coins/bitfinite.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';

import 'sample_data/theme_json.dart';

void main() {
  test("a theme with no BitFinite coin colour falls back to its own primary", () {
    // Themes inherited from upstream (Forest, etc.) only define colours for
    // the coins upstream ships, so they have no "bitfinite" entry - which is
    // exactly what this sample theme looks like.
    final theme = StackTheme.fromJson(json: lightThemeJsonMap);
    expect(
      theme.coinColors.containsKey("bitfinite"),
      isFalse,
      reason: "fixture must lack a bitfinite colour for this test to mean much",
    );

    final container = ProviderContainer(
      overrides: [
        themeProvider.overrideWithProvider(StateProvider((ref) => theme)),
      ],
    );
    addTearDown(container.dispose);

    final color = container.read(pCoinColor(Bitfinite(CryptoCurrencyNetwork.main)));

    expect(
      color,
      theme.buttonBackPrimary,
      reason: "should follow the active theme, not a fixed colour",
    );
    expect(
      color,
      isNot(Colors.deepOrangeAccent),
      reason: "the old hardcoded orange clashed with every non-orange theme",
    );
  });
}
