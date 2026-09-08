import 'package:bitfinite/gowallet/go_auth_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'biometric success before resumed completes without a second PIN',
    () async {
      final guard = GoAuthGuard();
      addTearDown(guard.dispose);
      final ticket = guard.begin();
      guard.didChangeAppLifecycleState(AppLifecycleState.inactive);
      var unlocked = false;
      final pending = guard.waitUntilResumed(ticket).then((accepted) {
        unlocked = accepted;
      });
      await Future<void>.delayed(Duration.zero);
      expect(unlocked, isFalse);
      guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pending;
      expect(unlocked, isTrue);
    },
  );
  test(
    'pending biometric success is invalidated by background or a new PIN attempt',
    () async {
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        final guard = GoAuthGuard();
        final ticket = guard.begin();
        guard.didChangeAppLifecycleState(AppLifecycleState.inactive);
        final pending = guard.waitUntilResumed(ticket);
        guard.didChangeAppLifecycleState(state);
        guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(await pending, isFalse);
        guard.dispose();
      }
      final guard = GoAuthGuard();
      final ticket = guard.begin();
      guard.didChangeAppLifecycleState(AppLifecycleState.inactive);
      final pending = guard.waitUntilResumed(ticket);
      guard.begin();
      guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(await pending, isFalse);
      guard.dispose();
    },
  );
  test('pending result expires and disposal cannot authorize it', () async {
    final guard = GoAuthGuard();
    final ticket = guard.begin();
    guard.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(
      await guard.waitUntilResumed(ticket, timeout: Duration.zero),
      isFalse,
    );
    final pending = guard.waitUntilResumed(ticket);
    guard.dispose();
    expect(await pending, isFalse);
  });
  test('delayed success cannot unlock after background and resume', () async {
    final guard = GoAuthGuard();
    addTearDown(guard.dispose);
    final ticket = guard.begin();
    final pending = Future(() => guard.accepts(ticket));
    guard.didChangeAppLifecycleState(AppLifecycleState.paused);
    guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(await pending, isFalse);
    expect(guard.accepts(guard.begin()), isTrue);
  });
  test('OS inactive prompt may resume; no authorization while inactive', () {
    final guard = GoAuthGuard();
    addTearDown(guard.dispose);
    final ticket = guard.begin();
    guard.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(guard.accepts(ticket), isFalse);
    guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(guard.accepts(ticket), isTrue);
  });
  test('hidden, detached, disposed and superseded attempts fail closed', () {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      final guard = GoAuthGuard();
      final old = guard.begin();
      guard.didChangeAppLifecycleState(state);
      guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(guard.accepts(old), isFalse);
      final latest = guard.begin();
      expect(guard.accepts(old), isFalse);
      expect(guard.accepts(latest), isTrue);
      guard.dispose();
      expect(guard.accepts(latest), isFalse);
    }
  });
}
