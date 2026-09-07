import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/utilities/text_styles.dart';
import 'package:bitfinite/widgets/stack_dialog.dart';

import '../sample_data/theme_json.dart';

void main() {
  testWidgets("a wide footer does not squeeze the dialog title into wrapping", (
    tester,
  ) async {
    final theme = StackTheme.fromJson(json: lightThemeJsonMap);

    // Phone width, where the squeeze showed up.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late double singleLineHeight;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [StackColors.fromStackColorTheme(theme)]),
        home: Builder(
          builder: (context) {
            singleLineHeight = (TextPainter(
              text: TextSpan(
                text: "Attention",
                style: STextStyles.pageTitleH2(context),
              ),
              textDirection: TextDirection.ltr,
            )..layout()).height;

            return Scaffold(
              body: StackDialog(
                title: "Attention",
                message:
                    "You are about to view this transaction in a block "
                    "explorer. The explorer may log your IP address and link "
                    "it to the transaction.",
                footer: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(value: false, onChanged: (_) {}),
                    Text(
                      "Never show again",
                      style: STextStyles.smallMed14(context),
                    ),
                  ],
                ),
                leftButton: TextButton(onPressed: () {}, child: const Text("Cancel")),
                rightButton: TextButton(onPressed: () {}, child: const Text("Continue")),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleHeight = tester.getSize(find.text("Attention")).height;

    // If the title wrapped it would be at least two lines tall.
    expect(
      titleHeight,
      lessThan(singleLineHeight * 1.5),
      reason:
          "title rendered ${titleHeight}px tall vs ${singleLineHeight}px for a "
          "single line - it wrapped",
    );

    // The checkbox row must still be present, just relocated.
    expect(find.text("Never show again"), findsOneWidget);
  });
}
