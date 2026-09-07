import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/progress_bar.dart';

import '../sample_data/theme_json.dart';

void main() {
  testWidgets("Widget build", (widgetTester) async {
    final theme = StackTheme.fromJson(
      json: lightThemeJsonMap,
    );
    await widgetTester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            StackColors.fromStackColorTheme(theme),
          ],
        ),
        home: Material(
          child: ProgressBar(
              width: 20,
              height: 10,
              fillColor: StackColors.fromStackColorTheme(theme).accentColorRed,
              backgroundColor:
                  StackColors.fromStackColorTheme(theme).accentColorYellow,
              percent: 30),
        ),
      ),
    );

    expect(find.byType(ProgressBar), findsOneWidget);
  });
}
