/// Internal synchronous input boundary, shared by TDS controls and imperative
/// effect controllers. This deliberately does not propagate through async
/// continuations: a callback after await belongs to a later update batch.
abstract final class TdsInputDispatch {
  static int _depth = 0;
  static bool get active => _depth > 0;

  static void run(void Function() callback) {
    _depth++;
    try {
      callback();
    } finally {
      _depth--;
    }
  }
}
