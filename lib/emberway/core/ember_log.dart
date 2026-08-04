import 'package:flutter/foundation.dart';

/// Debug-only logger. The closure AND its string literals are stripped from
/// release builds (assert is a no-op in release), so no `[EMB.*]` tag ships.
void embTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}
