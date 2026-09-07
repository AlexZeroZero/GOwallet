import 'package:bitfinite/gowallet/go_auth_guard.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
