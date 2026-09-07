import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/themes/coin_card_provider.dart';
import 'package:bitfinite/themes/theme_providers.dart';
import 'package:bitfinite/wallets/crypto_currency/coins/bitfinite.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/widgets/coin_card.dart';

void main() {
  final coin = Bitfinite(CryptoCurrencyNetwork.main);

  Future<Color> colorFor(WidgetTester tester, Color cardColor) async {
    late Color result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pCoinColor(coin).overrideWithProvider(
            StateProvider((ref) => cardColor),
          ),
          // No themed card artwork, so the gradient path is exercised.
          coinCardFavoritesProvider(coin).overrideWithValue(null),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, __) {
              result = onCoinCardColor(context, ref, coin);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets("a dark card gets light text", (tester) async {
    // BitFinite's own blue, and the sort of saturated green an inherited
    // theme's primary yields - both too dark for the black text some themes
    // declare in textFavoriteCard.
    expect(await colorFor(tester, const Color(0xFF2F6BFF)), Colors.white);
    expect(await colorFor(tester, const Color(0xFF1B6B5A)), Colors.white);
  });

  testWidgets("a light card keeps dark text", (tester) async {
    // Upstream's pastel coin colours, which black text was authored against.
    expect(await colorFor(tester, const Color(0xFFFCC17B)), Colors.black87);
    expect(await colorFor(tester, const Color(0xFFFFE079)), Colors.black87);
  });
}
