import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/shake/shake.dart';

import '../../sample_data/theme_json.dart';

void main() {
  testWidgets("Widget build", (widgetTester) async {
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
        home: Material(
          child: Shake(
            animationRange: 10,
            controller: ShakeController(),
            animationDuration: const Duration(milliseconds: 200),
            child: const Column(
              children: [
                Center(
                  child: Text("Enter Pin"),
                )
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Shake), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
