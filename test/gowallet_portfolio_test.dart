import 'portfolio_test_prefs.dart';
import 'package:bitfinite/providers/global/prefs_provider.dart';
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bitfinite/app_config.dart';
import 'package:bitfinite/gowallet/go_dashboard.dart';
import 'package:bitfinite/gowallet/go_portfolio.dart';
import 'package:bitfinite/models/balance.dart';
import 'package:bitfinite/themes/coin_icon_provider.dart';
import 'package:bitfinite/utilities/amount/amount.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/isar/models/wallet_info.dart';

WalletInfo fixture(CryptoCurrency coin, String id, String? balance) {
  final a = Amount.fromDecimal(
    Decimal.parse(balance ?? '0'),
    fractionDigits: coin.fractionDigits,
  );
  final zero = Amount.zeroWith(fractionDigits: coin.fractionDigits);
  return WalletInfo(
    walletId: id,
    name: 'Wallet $id',
    mainAddressType: coin.defaultAddressType,
    coinName: coin.identifier,
    cachedBalanceString: balance == null
        ? null
        : Balance(
            total: a,
            spendable: a,
            blockedTotal: zero,
            pendingSpendable: zero,
          ).toJsonIgnoreCoin(),
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 6, 10);
  final scash = AppConfig.coins.firstWhere((c) => c.identifier == 'scash');
  final shic = AppConfig.coins.firstWhere((c) => c.identifier == 'shibacoin');
  test('sub-display-unit estimates never appear as a known zero', () {
    expect(goFiat(Decimal.parse('0.0000000005'), 'en_US'), '<0.00000001');
    expect(goFiat(Decimal.zero, 'en_US'), '0.00');
  });
  test('multiple wallets aggregate without rounding tiny coin prices', () {
    final p = computeGoPortfolio(
      [
        fixture(scash, '1', '1.00000001'),
        fixture(scash, '2', '2'),
        fixture(shic, '3', '10000000'),
      ],
      {
        'scash': GoQuote(Decimal.parse('0.05'), now),
        'shibacoin': GoQuote(Decimal.parse('0.00000366'), now),
      },
      now,
    );
    expect(p.holdings.first.balance, Decimal.parse('3.00000001'));
    expect(p.estimate, Decimal.parse('36.7500000005'));
    expect(p.complete, isTrue);
  });
  test('unknown balance never becomes zero or a complete subtotal', () {
    final p = computeGoPortfolio(
      [fixture(scash, '1', '2'), fixture(scash, '2', null)],
      {'scash': GoQuote(Decimal.one, now)},
      now,
    );
    expect(p.holdings.single.balance, isNull);
    expect(p.estimate, isNull);
    expect(p.complete, isFalse);
  });
  test(
    'partial prices are explicitly incomplete; known zero needs no quote',
    () {
      final p = computeGoPortfolio(
        [fixture(scash, '1', '2'), fixture(shic, '2', '100')],
        {'scash': GoQuote(Decimal.parse('0.05'), now)},
        now,
      );
      expect(p.estimate, Decimal.parse('0.1'));
      expect(p.missingCount, 1);
      final zero = computeGoPortfolio([fixture(shic, '2', '0')], {}, now);
      expect(zero.estimate, Decimal.zero);
      expect(zero.complete, isTrue);
    },
  );
  test('reject stale, future, missing-currency and nonpositive quotes', () {
    String body(Object value, DateTime date) => jsonEncode({
      'shibacoin': {
        'usd': value,
        'last_updated_at': date.millisecondsSinceEpoch ~/ 1000,
      },
    });
    expect(
      parseGoQuotes(body(0.00000366, now), 'USD', now)['shibacoin']!.price,
      Decimal.parse('0.00000366'),
    );
    for (final value in [0, -1, 'NaN']) {
      expect(parseGoQuotes(body(value, now), 'USD', now), isEmpty);
    }
    expect(
      parseGoQuotes(
        body(1, now.subtract(const Duration(minutes: 16))),
        'USD',
        now,
      ),
      isEmpty,
    );
    expect(
      parseGoQuotes(body(1, now.add(const Duration(minutes: 3))), 'USD', now),
      isEmpty,
    );
    expect(parseGoQuotes(body(1, now), 'CNY', now), isEmpty);
  });
  test(
    'market request uses public IDs only and fails closed on rate limiting',
    () async {
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api.coingecko.com');
        expect(request.url.queryParameters, {
          'ids': 'satoshi-cash-network,shibacoin,pepecoin-network,dingocoin',
          'vs_currencies': 'cny',
          'include_last_updated_at': 'true',
        });
        return http.Response('{}', 429);
      });
      await expectLater(fetchGoQuotes(client, 'CNY'), throwsStateError);
      client.close();
    },
  );
  for (final scale in [1.0, 1.5]) {
    for (final language in ['zh', 'en']) {
      testWidgets(
        'funded asset card and drawer fit 320px at scale $scale in $language',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = computeGoPortfolio(
            [
              fixture(scash, '1', '987654321.12345678'),
              fixture(shic, '2', null),
            ],
            {'scash': GoQuote(Decimal.parse('0.12345678'), now)},
            now,
          );
          var opened = '';
          var added = '';
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                prefsChangeNotifierProvider.overrideWithValue(
                  PortfolioTestPrefs(),
                ),
                pGoPortfolio.overrideWithValue(p),
                pGoQuotes.overrideWithValue(const AsyncData({})),
                for (final c in AppConfig.coins)
                  coinIconProvider(c).overrideWithValue(
                    'assets/in_app_logo_icons/electrum-wallet.svg',
                  ),
              ],
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: const [Locale('zh'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      appBar: AppBar(title: const Text('GOwallet')),
                      drawer: GoCoinDrawer(
                        onOpen: (h) {
                          opened = h.coin.identifier;
                        },
                        onAdd: (c) {
                          added = c.identifier;
                        },
                      ),
                      body: const GoDashboard(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('121,932,622'), findsWidgets);
          if (scale == 1.0) {
            expect(
              tester.getSize(find.byKey(const Key('goAssetSummary'))).height,
              lessThan(235),
            );
            expect(
              tester.getSize(find.byKey(const Key('goHolding-scash'))).height,
              inInclusiveRange(48, 88),
            );
          }
          await tester.tap(find.byIcon(Icons.visibility_outlined));
          await tester.pumpAndSettle();
          expect(find.textContaining('121,932,622'), findsNothing);
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(GoCoinDrawer),
                  matching: find.text('SCASH'),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(opened, 'scash');
          await tester.drag(
            find
                .descendant(
                  of: find.byType(GoCoinDrawer),
                  matching: find.byType(ListView),
                )
                .first,
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .descendant(
                  of: find.byType(GoCoinDrawer),
                  matching: find.text('SHIC'),
                )
                .last,
          );
          await tester.pumpAndSettle();
          expect(added, 'shibacoin');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
