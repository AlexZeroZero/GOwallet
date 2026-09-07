import 'dart:io';
import 'dart:ui' as ui;
import 'package:bitfinite/pages/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in ['zh', 'en']) {
    testWidgets(
      'launch page fits narrow display and respects reduced motion in $language',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const font = String.fromEnvironment('GO_PREVIEW_FONT');
        final originalShadows = debugDisableShadows;
        if (font.isNotEmpty) {
          debugDisableShadows = false;
          addTearDown(() => debugDisableShadows = originalShadows);
          await tester.runAsync(() async {
            final loader = FontLoader('GoPreview');
            loader.addFont(
              Future.value(
                ByteData.sublistView(await File(font).readAsBytes()),
              ),
            );
            await loader.load();
            final icons = FontLoader('MaterialIcons');
            icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
          });
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: font.isEmpty ? null : 'GoPreview'),
            locale: Locale(language),
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(font.isEmpty ? 1.5 : 1),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: const LoadingView(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('GOwallet'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .5,
        );
        expect(tester.takeException(), isNull);
        if (font.isNotEmpty) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'evidence/gowallet/go042-launch-widget-$language.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        debugDisableShadows = originalShadows;
      },
    );
  }
}
