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

  int begin() => ++_generation;
  bool accepts(int ticket) =>
      !_disposed &&
      ticket == _generation &&
      _state == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _generation++;
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
  }
}
