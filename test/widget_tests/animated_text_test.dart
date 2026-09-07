import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/animated_text.dart';

import '../sample_data/theme_json.dart';

void main() {
  testWidgets("Widget displays first word in strings list",
      (widgetTester) async {
    const animatedText = AnimatedText(
        stringsToLoopThrough: [
          "Calculating",
          "Calculating.",
          "Calculating..",
          "Calculating...",
        ],
        style: TextStyle(
          color: null,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ));
    await widgetTester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            StackColors.fromStackColorTheme(
              StackTheme.fromJson(
                json: lightThemeJsonMap,
              ),
            ),
          ],
        ),
        home: const Material(
          child: animatedText,
        ),
      ),
    );

    expect(find.text("Calculating"), findsOneWidget);
    expect(find.byWidget(animatedText), findsOneWidget);
  });
}
