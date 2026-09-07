import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/desktop/custom_text_button.dart';

import '../../sample_data/theme_json.dart';

void main() {
  testWidgets("Test text button ", (widgetTester) async {
    final key = UniqueKey();

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
          child: CustomTextButtonBase(
            key: key,
            width: 200,
            height: 300,
            textButton:
                const TextButton(onPressed: null, child: Text("Some Text")),
          ),
        ),
      ),
    );

    expect(find.byType(CustomTextButtonBase), findsOneWidget);
  });
}
