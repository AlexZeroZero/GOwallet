import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:bitfinite/models/isar/models/contact_entry.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/pages/address_book_views/subviews/contact_popup.dart';
import 'package:bitfinite/providers/global/address_book_service_provider.dart';
import 'package:bitfinite/services/address_book_service.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/utilities/util.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/widgets/address_book_card.dart';

import '../sample_data/theme_json.dart';
import 'address_book_card_test.mocks.dart';

class MockedFunctions extends Mock {
  void showDialog();
}

@GenerateMocks([AddressBookService])
void main() {
  testWidgets('test returns Contact Address Entry', (widgetTester) async {
    final service = MockAddressBookService();
    const applicationThemesDirectoryPath = "";

    when(service.getContactById("default")).thenAnswer(
      (realInvocation) => ContactEntry(
        name: "John Doe",
        addresses: [
          ContactAddressEntry()
            ..coinName = Bitfinite(CryptoCurrencyNetwork.main).identifier
            ..address = "some bch address"
            ..label = "Bills"
            ..other = null,
        ],
        isFavorite: true,
        customId: '',
      ),
    );

    await widgetTester.pumpWidget(
      ProviderScope(
        overrides: [
          addressBookServiceProvider.overrideWithValue(
            service,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            extensions: [
              StackColors.fromStackColorTheme(
                StackTheme.fromJson(
                  json: lightThemeJsonMap,
                ),
              ),
            ],
          ),
          home: const AddressBookCard(
            contactId: "default",
          ),
        ),
      ),
    );

    expect(find.text("John Doe"), findsOneWidget);
    expect(find.text("BFX"), findsOneWidget);
    expect(
      find.text(Bitfinite(CryptoCurrencyNetwork.main).ticker),
      findsOneWidget,
    );

    if (Platform.isIOS || Platform.isAndroid) {
      await widgetTester.tap(find.byType(RawMaterialButton));
      expect(find.byType(ContactPopUp), findsOneWidget);
    } else if (Util.isDesktop) {
      expect(find.byType(RawMaterialButton), findsNothing);
    }
  });
}
