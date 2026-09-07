import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';
import 'package:bitfinite/widgets/wallet_navigation_bar/wallet_navigation_bar.dart';

import '../sample_data/theme_json.dart';

void main() {
  testWidgets("floating dock stretches its actions across the full width", (
    tester,
  ) async {
    final theme = StackTheme.fromJson(json: lightThemeJsonMap);

    WalletNavigationBarItemData item(String label) =>
        WalletNavigationBarItemData(
          label: label,
          icon: const SizedBox(width: 20, height: 20),
          onTap: () {},
        );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            extensions: [StackColors.fromStackColorTheme(theme)],
          ),
          home: Scaffold(
            body: WalletNavigationBar(
              floating: true,
              items: [item("Receive"), item("Send")],
              moreItems: [item("Anything")],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The pill itself. Keyed rather than found by type, because the surface is
    // wrapped in a BackdropFilter only on iOS - Android gets a solid fill.
    final dock = tester.getRect(find.byKey(const Key("walletDockSurface")));

    // Two items + the generated "More" button.
    final buttons = find.byType(InkWell);
    expect(buttons, findsNWidgets(3));

    final centers = <double>[
      for (int i = 0; i < 3; i++) tester.getCenter(buttons.at(i)).dx,
    ];

    // The dock's 6px horizontal padding plus its 1px hairline border, both of
    // which inset the content box the actions are laid out in.
    const hPadding = 6.0 + 1.0;
    const buttonSize = 48.0;

    // The outer actions sit flush against the content box's edges, so the
    // icons genuinely span the pill rather than clustering in the middle.
    expect(
      centers.first,
      closeTo(dock.left + hPadding + buttonSize / 2, 0.5),
      reason: "first action should be flush with the dock's left edge",
    );
    expect(
      centers.last,
      closeTo(dock.right - hPadding - buttonSize / 2, 0.5),
      reason: "last action should be flush with the dock's right edge",
    );

    // ...and the remaining ones are evenly spread between them.
    expect(
      (centers[1] - centers[0]) - (centers[2] - centers[1]),
      closeTo(0, 0.5),
      reason: "actions should be evenly spaced across the dock",
    );

    // Symmetric: the dock reads as balanced, with the outer actions the same
    // distance from their respective edges.
    expect(
      (centers.first - dock.left) - (dock.right - centers.last),
      closeTo(0, 0.5),
      reason: "outer actions should be inset equally from both edges",
    );
  });
}
