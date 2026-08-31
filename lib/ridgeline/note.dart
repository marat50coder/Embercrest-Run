import 'package:flutter/foundation.dart';

/// Debug-only logger. The closure is stripped from release (assert no-op).
void riftNote(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}
