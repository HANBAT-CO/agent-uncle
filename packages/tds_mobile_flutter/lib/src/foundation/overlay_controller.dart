import 'package:flutter/widgets.dart';
import 'overlay_presence.dart';

typedef TdsOverlayBuilder =
    Widget Function(
      BuildContext context,
      bool isOpen,
      VoidCallback close,
      VoidCallback exit,
    );

class TdsOverlayController extends ChangeNotifier {
  TdsOverlayBuilder? _builder;
  bool _open = false, _disposed = false;
  int _generation = 0;
  bool get isOpen => _open;
  void open(TdsOverlayBuilder builder) {
    if (_disposed) return;
    _generation++;
    _builder = builder;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (_disposed || !_open) return;
    _open = false;
    notifyListeners();
  }

  void exit() {
    if (_disposed) return;
    _generation++;
    _open = false;
    _builder = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _builder = null;
    super.dispose();
  }
}

class TdsOverlayProvider extends StatefulWidget {
  const TdsOverlayProvider({required this.child, this.controller, super.key});
  final Widget child;
  final TdsOverlayController? controller;
  static TdsOverlayController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_OverlayScope>()?.notifier ??
      (throw StateError('TdsOverlayProvider is required'));
  @override
  State<TdsOverlayProvider> createState() => _TdsOverlayProviderState();
}

class _OverlayScope extends InheritedNotifier<TdsOverlayController> {
  const _OverlayScope({
    required TdsOverlayController controller,
    required super.child,
  }) : super(notifier: controller);
}

class _TdsOverlayProviderState extends State<TdsOverlayProvider> {
  late TdsOverlayController controller =
      widget.controller ?? TdsOverlayController();
  @override
  void initState() {
    super.initState();
    controller.addListener(update);
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TdsOverlayProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      controller.removeListener(update);
      if (oldWidget.controller == null) controller.dispose();
      controller = widget.controller ?? TdsOverlayController();
      controller.addListener(update);
    }
  }

  @override
  void dispose() {
    controller.removeListener(update);
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = controller._generation;
    final builder = controller._builder;
    void close() {
      if (controller._generation == generation) controller.close();
    }

    void exit() {
      if (controller._generation == generation) controller.exit();
    }

    return _OverlayScope(
      controller: controller,
      child: Stack(
        children: [
          widget.child,
          if (builder != null)
            TdsOverlayPresence(
              key: ValueKey(generation),
              open: controller.isOpen,
              onExited: exit,
              builder: (context, animation) => Positioned.fill(
                child: FadeTransition(
                  opacity: animation,
                  child: builder(context, controller.isOpen, close, exit),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ignore: non_constant_identifier_names
TdsOverlayController useOverlay_will_be_deleted(BuildContext context) =>
    TdsOverlayProvider.of(context);
