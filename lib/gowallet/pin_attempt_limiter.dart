import 'dart:convert';
import 'package:mutex/mutex.dart';

/// Persist before checking a PIN so killing the app cannot erase an attempt.
/// A rooted or compromised OS is outside this app-level lock's protection.
class PinAttemptLimiter {
  PinAttemptLimiter({
    required this.read,
    required this.write,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Future<String?> Function() read;
  final Future<void> Function(String value) write;
  final DateTime Function() clock;
  static final _mutex = Mutex();
  static const storageKey = 'gowallet.pin.attempts.v1';

  Future<({bool accepted, int waitSeconds})> verify(
    Future<bool> Function() check,
  ) => _mutex.protect(() async {
    final raw = await read();
    final state = raw == null
        ? <String, dynamic>{'failures': 0, 'until': 0}
        : jsonDecode(raw) as Map<String, dynamic>;
    final failures = state['failures'] as int;
    final until = state['until'] as int;
    if (failures < 0 || until < 0)
      throw const FormatException('Invalid PIN lock state');
    final now = clock().millisecondsSinceEpoch;
    if (now < until)
      return (accepted: false, waitSeconds: ((until - now) / 1000).ceil());
    final next = failures + 1;
    final seconds = next < 3
        ? 0
        : switch (next) {
            3 => 30,
            4 => 60,
            5 => 300,
            6 => 600,
            _ => 3600,
          };
    await write(jsonEncode({'failures': next, 'until': now + seconds * 1000}));
    if (await check()) {
      await write(jsonEncode({'failures': 0, 'until': 0}));
      return (accepted: true, waitSeconds: 0);
    }
    return (accepted: false, waitSeconds: seconds);
  });
}
