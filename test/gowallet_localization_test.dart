import 'portfolio_test_prefs.dart';
import 'package:bitfinite/providers/global/prefs_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/gowallet/l10n/go_catalog.dart';
import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import 'package:bitfinite/gowallet/go_dashboard.dart';
import 'package:bitfinite/db/hive/db.dart';
import 'package:bitfinite/utilities/prefs.dart';
import 'package:bitfinite/services/locale_service.dart';
import 'package:bitfinite/wallets/isar/providers/all_wallets_info_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'startup and system locale refresh preserve the chosen app language',
    () async {
      final locale = LocaleService();
      for (final language in ['简体中文', 'English (US)']) {
        locale.setAppLanguage(language);
        await locale.loadLocale();
        expect(locale.locale, language == '简体中文' ? 'zh_CN' : 'en_US');
      }
      locale.dispose();
    },
  );
  test('all catalog translations preserve placeholders', () {
    final pattern = RegExp(r'\{\d+\}');
    for (final entry in goCatalog.entries) {
      final original = pattern.allMatches(entry.key).map((m) => m[0]).toList()
        ..sort();
      for (final translation in entry.value) {
        final actual = pattern.allMatches(translation).map((m) => m[0]).toList()
          ..sort();
        expect(actual, original, reason: entry.key);
      }
    }
  });
  test('user data is substituted once without translation or recursion', () {
    for (final value in [
      'Send',
      '收款',
      'scash1qabc',
      '{1}',
      r'$50',
      'abandon about',
    ]) {
      expect(goTranslate('zh', 'Wallet {0}', [value]), '钱包 $value');
      expect(goTranslate('en', '发送全部 {0}', [value]), 'Send all $value');
    }
    expect(
      goTranslate('zh', 'Unknown server error: 127.0.0.1'),
      'Unknown server error: 127.0.0.1',
    );
  });
  test(
    'screenshot choice and language are persisted without touching security settings',
    () async {
      final directory = await Directory.systemTemp.createTemp('go-prefs-');
      final hive = DB.instance.hive;
      hive.init(directory.path);
      final box = await hive.openBox<dynamic>(DB.boxNamePrefs);
      try {
        await Prefs.instance.init();
        final prefs = Prefs.instance;
        expect(prefs.disableScreenShots, isTrue);
        expect(prefs.language, '简体中文');
        final lock = prefs.autoLockInfo;
        prefs.disableScreenShots = false;
        prefs.language = 'English (US)';
        await DB.instance.mutex.protect(() async => box.flush());
        expect(prefs.disableScreenShots, isFalse);
        expect(box.get('disableScreenShots'), isFalse);
        expect(box.get('goLanguage'), 'English (US)');
        expect(prefs.autoLockInfo, lock);
        prefs.disableScreenShots = true;
        await DB.instance.mutex.protect(() async => box.flush());
        expect(box.get('disableScreenShots'), isTrue);
      } finally {
        await hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'locale rebuild preserves navigator route and entered user text',
    (tester) async {
      final locale = ValueNotifier(const Locale('zh', 'CN'));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, value, _) => MaterialApp(
            navigatorKey: navigator,
            locale: value,
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Scaffold(),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(goTr(context, 'Language'))),
            body: const TextField(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Send {0} 我的钱包');
      locale.value = const Locale('en', 'US');
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Send {0} 我的钱包'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      locale.dispose();
    },
  );
  for (final language in ['zh', 'en']) {
    testWidgets('home fits 320px and large text in $language', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsChangeNotifierProvider.overrideWithValue(PortfolioTestPrefs()),
            pAllWalletsInfo.overrideWithValue([]),
          ],
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: const Scaffold(body: GoDashboard()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
