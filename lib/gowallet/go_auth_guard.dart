import 'dart:async';

import 'package:flutter/widgets.dart';

/// An authentication result belongs to one foreground attempt only.
/// `inactive` can be the OS biometric prompt; backgrounding invalidates it.
class GoAuthGuard with WidgetsBindingObserver {
  GoAuthGuard() {
    _state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  late AppLifecycleState _state;
  int _generation = 0;
  bool _disposed = false;
  final _waiters = <Completer<void>>{};

  int begin() {
    _generation++;
    _wakeWaiters();
    return _generation;
  }

  bool accepts(int ticket) =>
      !_disposed &&
      ticket == _generation &&
      _state == AppLifecycleState.resumed;

  /// The native biometric callback can precede Flutter's resumed event.
  /// Wait only for that transient inactive state, never across backgrounding.
  Future<bool> waitUntilResumed(
    int ticket, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (accepts(ticket)) return true;
    if (_disposed ||
        ticket != _generation ||
        _state != AppLifecycleState.inactive) {
      return false;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    try {
      await waiter.future.timeout(timeout);
      return accepts(ticket);
    } on TimeoutException {
      return false;
    } finally {
      _waiters.remove(waiter);
    }
  }

  void _wakeWaiters() {
    for (final waiter in _waiters.toList()) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _generation++;
    }
    if (state != AppLifecycleState.inactive) _wakeWaiters();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _wakeWaiters();
    WidgetsBinding.instance.removeObserver(this);
  }
}
