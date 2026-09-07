import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/gowallet/pin_attempt_limiter.dart';

void main() {
  late String? stored;
  late DateTime now;
  PinAttemptLimiter limiter() => PinAttemptLimiter(
    read: () async => stored,
    write: (value) async {
      stored = value;
    },
    clock: () => now,
  );
  setUp(() {
    stored = null;
    now = DateTime.utc(2026, 9, 6);
  });
  test(
    'three failures persist a lock across fresh limiter instances',
    () async {
      for (var i = 0; i < 3; i++) {
        await limiter().verify(() async => false);
      }
      var checked = false;
      final result = await limiter().verify(() async {
        checked = true;
        return true;
      });
      expect(result.accepted, false);
      expect(result.waitSeconds, 30);
      expect(checked, false);
    },
  );
  test(
    'expired lock permits authentication and success resets failures',
    () async {
      for (var i = 0; i < 3; i++) {
        await limiter().verify(() async => false);
      }
      now = now.add(const Duration(seconds: 31));
      expect((await limiter().verify(() async => true)).accepted, true);
      expect(jsonDecode(stored!)['failures'], 0);
    },
  );
  test(
    'further failures escalate instead of resetting after the timer',
    () async {
      for (var i = 0; i < 3; i++) {
        await limiter().verify(() async => false);
      }
      now = now.add(const Duration(seconds: 31));
      expect((await limiter().verify(() async => false)).waitSeconds, 60);
    },
  );
  test(
    'attempt persisted before verifier crash and concurrent attempts serialize',
    () async {
      await expectLater(
        limiter().verify(() async => throw StateError('interrupted')),
        throwsStateError,
      );
      expect(jsonDecode(stored!)['failures'], 1);
      await Future.wait([
        limiter().verify(() async => false),
        limiter().verify(() async => false),
      ]);
      expect(jsonDecode(stored!)['failures'], 3);
      expect((await limiter().verify(() async => true)).accepted, false);
    },
  );
  test(
    'corrupt secure state fails closed and never invokes verifier',
    () async {
      stored = 'invalid';
      var checked = false;
      await expectLater(
        limiter().verify(() async {
          checked = true;
          return true;
        }),
        throwsFormatException,
      );
      expect(checked, false);
    },
  );
}
