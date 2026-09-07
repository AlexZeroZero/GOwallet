import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/gowallet/go_custom_coin_page.dart';
import 'package:bitfinite/gowallet/go_add_network.dart';
import 'package:bitfinite/gowallet/l10n/go_localizations.dart';

void main() {
  for (final lang in ['zh','en']) {
    for (final page in [const GoCustomCoinPage(),const GoAddNetwork()]) {
      testWidgets('$lang ${page.runtimeType} fits narrow display with larger text', (tester) async {
        tester.view.physicalSize=const Size(320,640);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(child:MaterialApp(
          locale:Locale(lang),supportedLocales:const [Locale('zh'),Locale('en')],
          localizationsDelegates:GlobalMaterialLocalizations.delegates,
          builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.5)),child:child!),home:page)));
        await tester.pumpAndSettle();
        expect(find.text(goTranslate(lang,page is GoCustomCoinPage ? '自定义币种' : '新增网络')),findsOneWidget);
        expect(tester.takeException(),isNull);
        // Exercise every portion of the long profile form and its final controls.
        for(var i=0;i<18;i++) { await tester.drag(find.byType(ListView).first,const Offset(0,-400));await tester.pumpAndSettle();expect(tester.takeException(),isNull); }
        if(page is GoCustomCoinPage) {
          final button=tester.widget<FilledButton>(find.widgetWithText(FilledButton,goTranslate(lang,'验证并添加币种')));
          expect(button.onPressed,isNull);
        }
      });
    }
  }
}
