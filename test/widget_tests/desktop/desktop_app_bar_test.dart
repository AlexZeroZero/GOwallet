import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/pages_desktop_specific/my_stack_view/exit_to_my_stack_button.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/custom_buttons/app_bar_icon_button.dart';
import 'package:bitfinite/widgets/desktop/desktop_app_bar.dart';

import '../../sample_data/theme_json.dart';

void main() {
  testWidgets("Test DesktopAppBar widget", (widgetTester) async {
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
          child: DesktopAppBar(
            key: key,
            isCompactHeight: false,
            leading: const AppBarBackButton(),
            trailing: const ExitToMyStackButton(),
            center: const Text("Some Text"),
          ),
        ),
      ),
    );

    expect(find.byType(DesktopAppBar), findsOneWidget);
  });
}
