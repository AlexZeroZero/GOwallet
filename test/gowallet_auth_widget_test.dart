import 'dart:async';
import 'package:bitfinite/pages/pinpad_views/pinpad_dialog.dart';
import 'package:bitfinite/widgets/custom_pin_put/custom_pin_put.dart';
import 'package:bitfinite/models/isar/stack_theme.dart';
import 'package:bitfinite/themes/stack_colors.dart';
import 'package:bitfinite/themes/theme_providers.dart';
import 'package:bitfinite/pages/pinpad_views/lock_screen_view.dart';
import 'package:bitfinite/providers/global/prefs_provider.dart';
import 'package:bitfinite/providers/global/secure_store_provider.dart';
import 'package:bitfinite/utilities/biometrics.dart';
import 'package:bitfinite/utilities/flutter_secure_storage_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'portfolio_test_prefs.dart';
import 'sample_data/theme_json.dart';

class AuthPrefs extends PortfolioTestPrefs {
  @override
  bool get isInitialized => true;
  @override
  bool get useBiometrics => true;
  @override
  bool get randomizePIN => false;
  @override
  int lastUnlocked = 0;
}

class PendingBiometrics extends Biometrics {
  final result = Completer<bool>();
  @override
  Future<bool> authenticate({
    required String cancelButtonText,
    required String localizedReason,
    required String title,
  }) => result.future;
}

class UnusedSecureStore implements SecureStorageInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestPinStore implements SecureStorageInterface {
  final values = <String, String?>{kPinKey: '123456'};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #read)
      return Future<String?>.value(values[key]);
    if (invocation.memberName == #write) {
      values[key!] = invocation.namedArguments[#value] as String?;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  for (final scenario in [
    'foreground',
    'inactive',
    'background',
    'cancel',
    'starting_inactive',
  ]) {
    final background = scenario == 'background';
    testWidgets(
      'real lockscreen accepts delayed biometrics only in original foreground: scenario=$scenario',
      (tester) async {
        tester.view.physicalSize = const Size(430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.handleAppLifecycleStateChanged(
          scenario == 'starting_inactive'
              ? AppLifecycleState.inactive
              : AppLifecycleState.resumed,
        );
        final bio = PendingBiometrics();
        var unlocked = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeProvider.overrideWithValue(
                StateController(StackTheme.fromJson(json: lightThemeJsonMap)),
              ),
              prefsChangeNotifierProvider.overrideWithValue(AuthPrefs()),
              secureStoreProvider.overrideWithValue(TestPinStore()),
            ],
            child: MaterialApp(
              theme: ThemeData(
                extensions: [
                  StackColors.fromStackColorTheme(
                    StackTheme.fromJson(json: lightThemeJsonMap),
                  ),
                ],
              ),
              home: LockscreenView(
                embedded: true,
                routeOnSuccess: '',
                biometrics: bio,
                biometricsAuthenticationTitle: 'Unlock',
                biometricsLocalizedReason: 'Unlock',
                biometricsCancelButtonString: 'Cancel',
                onSuccess: () => unlocked = true,
              ),
            ),
          ),
        );
        await tester.pump();
        if (scenario == 'starting_inactive') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }
        if (background) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        if (scenario == 'inactive') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        bio.result.complete(scenario != 'cancel');
        if (scenario == 'inactive') {
          await tester.pump();
          expect(unlocked, isFalse);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(unlocked, !background && scenario != 'cancel');
        if (scenario == 'cancel') {
          tester
              .widget<CustomPinPut>(find.byType(CustomPinPut))
              .onSubmit
              ?.call('654321');
          await tester.pumpAndSettle();
          expect(unlocked, isFalse);
          tester
              .widget<CustomPinPut>(find.byType(CustomPinPut))
              .onSubmit
              ?.call('123456');
          await tester.pumpAndSettle();
          expect(unlocked, isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'sensitive-action PIN dialog closes on biometric success before resume',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final bio = PendingBiometrics();
      String? result;
      final theme = StackTheme.fromJson(json: lightThemeJsonMap);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWithValue(StateController(theme)),
            prefsChangeNotifierProvider.overrideWithValue(AuthPrefs()),
            secureStoreProvider.overrideWithValue(UnusedSecureStore()),
          ],
          child: MaterialApp(
            theme: ThemeData(
              extensions: [StackColors.fromStackColorTheme(theme)],
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => PinpadDialog(
                        biometrics: bio,
                        biometricsAuthenticationTitle: 'Verify',
                        biometricsLocalizedReason: 'Verify',
                        biometricsCancelButtonString: 'PIN',
                      ),
                    );
                  },
                  child: const Text('Open verification'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open verification'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      bio.result.complete(true);
      await tester.pump();
      expect(result, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(result, 'verified success');
      expect(find.byType(PinpadDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
