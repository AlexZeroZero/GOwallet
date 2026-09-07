import '../../gowallet/go_auth_guard.dart';
import 'package:bitfinite/gowallet/l10n/go_localizations.dart';
import '../../gowallet/pin_attempt_limiter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/global/duress_provider.dart';
import '../../providers/global/prefs_provider.dart';
import '../../providers/global/secure_store_provider.dart';
import '../../themes/stack_colors.dart';
import '../../utilities/biometrics.dart';
import '../../utilities/flutter_secure_storage_interface.dart';
import '../../utilities/text_styles.dart';
import '../../widgets/custom_pin_put/custom_pin_put.dart';
import '../../widgets/shake/shake.dart';
import '../../widgets/stack_dialog.dart';
import 'lock_screen_view.dart';

class PinpadDialog extends ConsumerStatefulWidget {
  const PinpadDialog({
    super.key,
    required this.biometricsAuthenticationTitle,
    required this.biometricsLocalizedReason,
    required this.biometricsCancelButtonString,
    this.biometrics = const Biometrics(),
    this.customKeyLabel = "Button",
  });

  final String biometricsAuthenticationTitle;
  final String biometricsLocalizedReason;
  final String biometricsCancelButtonString;
  final Biometrics biometrics;
  final String customKeyLabel;

  @override
  ConsumerState<PinpadDialog> createState() => _PinpadDialogState();
}

class _PinpadDialogState extends ConsumerState<PinpadDialog> {
  final _authGuard = GoAuthGuard();
  late final ShakeController _shakeController;

  bool _submitting = false;
  String? _pinError;

  final FocusNode _pinFocusNode = FocusNode();

  late SecureStorageInterface _secureStore;
  late Biometrics biometrics;
  int pinCount = 1;

  final _pinTextController = TextEditingController();

  BoxDecoration get _pinPutDecoration {
    return BoxDecoration(
      color: Theme.of(context).extension<StackColors>()!.infoItemIcons,
      border: Border.all(
        width: 1,
        color: Theme.of(context).extension<StackColors>()!.infoItemIcons,
      ),
      borderRadius: BorderRadius.circular(6),
    );
  }

  Future<void> _onUnlock(int ticket) async {
    if (!mounted || !_authGuard.accepts(ticket)) return;
    final now = DateTime.now().toUtc();
    ref.read(prefsChangeNotifierProvider).lastUnlocked =
        now.millisecondsSinceEpoch ~/ 1000;

    Navigator.of(context).pop("verified success");
  }

  Future<void> _checkUseBiometrics() async {
    final ticket = _authGuard.begin();
    if (!ref.read(prefsChangeNotifierProvider).isInitialized) {
      await ref.read(prefsChangeNotifierProvider).init();
    }

    if (!mounted || !_authGuard.accepts(ticket)) return;
    final bool useBiometrics = ref
        .read(prefsChangeNotifierProvider)
        .useBiometrics;

    final title = widget.biometricsAuthenticationTitle;
    final localizedReason = widget.biometricsLocalizedReason;
    final cancelButtonText = widget.biometricsCancelButtonString;

    if (useBiometrics) {
      if (await biometrics.authenticate(
        title: title,
        localizedReason: localizedReason,
        cancelButtonText: cancelButtonText,
      )) {
        unawaited(_onUnlock(ticket));
      }
      // leave this commented to enable pin fall back should biometrics not work properly
      // else {
      //   Navigator.pop(context);
      // }
    }
  }

  Future<void> _onSubmit(String pin) async {
    if (_submitting) return;
    final ticket = _authGuard.begin();
    _submitting = true;
    try {
      final limiter = PinAttemptLimiter(
        read: () => _secureStore.read(key: PinAttemptLimiter.storageKey),
        write: (value) =>
            _secureStore.write(key: PinAttemptLimiter.storageKey, value: value),
      );
      final result = await limiter.verify(
        () async =>
            pin ==
            await _secureStore.read(
              key: ref.read(pDuress) ? kDuressPinKey : kPinKey,
            ),
      );
      if (!mounted || !_authGuard.accepts(ticket)) return;
      _pinTextController.clear();
      if (result.accepted) {
        await _onUnlock(ticket);
      } else {
        unawaited(_shakeController.shake());
        setState(
          () => _pinError = result.waitSeconds > 0
              ? goTr(context, '请等待 {0} 秒后重试', [result.waitSeconds])
              : goTr(context, 'PIN 不正确，请重试'),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _pinError = goTr(context, '无法读取安全存储，请重试'));
    } finally {
      _submitting = false;
    }
  }

  @override
  void initState() {
    _shakeController = ShakeController();

    _secureStore = ref.read(secureStoreProvider);
    biometrics = widget.biometrics;

    _checkUseBiometrics();
    super.initState();
  }

  @override
  dispose() {
    _authGuard.dispose();
    // _shakeController.dispose();
    _pinTextController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StackDialogBase(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shake(
            animationDuration: const Duration(milliseconds: 700),
            animationRange: 12,
            controller: _shakeController,
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      goTr(context, "输入 PIN 解锁"),
                      style: STextStyles.pageTitleH1(context),
                    ),
                  ),
                  if (_pinError != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_pinError!, textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 40),
                  CustomPinPut(
                    fieldsCount: pinCount,
                    eachFieldHeight: 12,
                    eachFieldWidth: 12,
                    textStyle: STextStyles.label(context).copyWith(fontSize: 1),
                    focusNode: _pinFocusNode,
                    controller: _pinTextController,
                    useNativeKeyboard: false,
                    obscureText: "",
                    inputDecoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      fillColor: Theme.of(
                        context,
                      ).extension<StackColors>()!.popupBG,
                      counterText: "",
                    ),
                    submittedFieldDecoration: _pinPutDecoration,
                    isRandom: ref
                        .read(prefsChangeNotifierProvider)
                        .randomizePIN,
                    onSubmit: _onSubmit,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
