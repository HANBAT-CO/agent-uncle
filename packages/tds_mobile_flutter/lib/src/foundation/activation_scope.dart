import 'package:flutter/widgets.dart';

/// A DOM-style activation boundary for compound triggers. Flutter's gesture
/// arena chooses the inner button; it does not bubble its accepted tap.
/// Only TDS pressables participate. Arbitrary third-party gesture recognizers
/// must explicitly forward their activation to the enclosing trigger.
class TdsActivationController extends ChangeNotifier {
  TdsActivationController(this.onActivate);
  final void Function(FocusNode source) onActivate;
  final Set<Object> _members = {};
  bool _disposed = false, _scheduled = false;
  bool get hasMembers => _members.isNotEmpty;

  void register(Object member) {
    if (!_disposed && _members.add(member)) _changed();
  }

  void unregister(Object member) {
    if (!_disposed && _members.remove(member)) _changed();
  }

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    // Registration occurs while children build/unmount. Notify ancestors after
    // this frame, never by calling setState on an ancestor during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void activate(FocusNode source) {
    if (!_disposed) onActivate(source);
  }

  @override
  void dispose() {
    _disposed = true;
    _members.clear();
    super.dispose();
  }
}

class TdsActivationScope extends InheritedWidget {
  const TdsActivationScope({
    required this.controller,
    required super.child,
    super.key,
  });
  final TdsActivationController controller;
  static TdsActivationController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TdsActivationScope>()
      ?.controller;
  @override
  bool updateShouldNotify(TdsActivationScope old) =>
      controller != old.controller;
}
