import 'dart:async';
import 'package:flutter/widgets.dart';
import '../components/dialog.dart';

/// Stateful counterpart of useDialog. A provider owns the portal and cleans up
/// pending futures when removed. Async failures leave the dialog open for retry.
class TdsDialogController extends ChangeNotifier {
  _Request? _request;
  bool _disposed = false;

  Future<void> openAlert({
    required Widget title,
    Widget? description,
    String alertButton = '확인',
    bool closeOnDimmerClick = false,
    bool closeOnBackEvent = true,
  }) async {
    await _open(
      _Request(
        title: title,
        description: description,
        confirmText: alertButton,
        alert: true,
        closeOnDimmerClick: closeOnDimmerClick,
        closeOnBackEvent: closeOnBackEvent,
      ),
    );
  }

  Future<bool> openConfirm({
    required Widget title,
    Widget? description,
    String confirmButton = '확인',
    String cancelButton = '취소',
    bool closeOnDimmerClick = false,
    bool closeOnBackEvent = true,
  }) => _open(
    _Request(
      title: title,
      description: description,
      confirmText: confirmButton,
      cancelText: cancelButton,
      closeOnDimmerClick: closeOnDimmerClick,
      closeOnBackEvent: closeOnBackEvent,
    ),
  );
  Future<bool> openAsyncConfirm({
    required Widget title,
    Widget? description,
    required Future<void> Function() onConfirmClick,
    Future<void> Function()? onCancelClick,
    void Function(Object error, StackTrace stack)? onError,
    String confirmButton = '확인',
    String cancelButton = '취소',
    bool closeOnDimmerClick = false,
    bool closeOnBackEvent = true,
  }) => _open(
    _Request(
      title: title,
      description: description,
      confirmText: confirmButton,
      cancelText: cancelButton,
      onConfirm: onConfirmClick,
      onCancel: onCancelClick,
      onError: onError,
      closeOnDimmerClick: closeOnDimmerClick,
      closeOnBackEvent: closeOnBackEvent,
    ),
  );
  Future<bool> _open(_Request request) {
    if (_disposed) {
      return Future.error(StateError('TdsDialogController has been disposed'));
    }
    final previous = _request;
    if (previous != null && !previous.result.isCompleted) {
      previous.result.complete(false);
    }
    _request = request;
    notifyListeners();
    return request.result.future;
  }

  void close() => _finish(false);
  void _finish(bool result) {
    final request = _request;
    if (_disposed || request == null || !request.open) return;
    request.open = false;
    if (!request.result.isCompleted) request.result.complete(result);
    notifyListeners();
  }

  Future<void> _activate(_Request request, bool confirm) async {
    if (_disposed ||
        _request != request ||
        !request.open ||
        (confirm ? request.confirmBusy : request.cancelBusy)) {
      return;
    }
    final callback = confirm ? request.onConfirm : request.onCancel;
    if (callback == null) {
      _finish(confirm);
      return;
    }
    if (confirm) {
      request.confirmBusy = true;
    } else {
      request.cancelBusy = true;
    }
    notifyListeners();
    try {
      await callback();
      if (!_disposed && _request == request) _finish(confirm);
    } catch (error, stack) {
      if (request.onError != null) {
        request.onError!(error, stack);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'tds_mobile_flutter',
            context: ErrorDescription('while invoking an async dialog action'),
          ),
        );
      }
    } finally {
      if (confirm) {
        request.confirmBusy = false;
      } else {
        request.cancelBusy = false;
      }
      if (!_disposed && _request == request) notifyListeners();
    }
  }

  void _exited(_Request request) {
    if (_disposed || _request != request || request.open) return;
    _request = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_request != null && !_request!.result.isCompleted) {
      _request!.result.complete(false);
    }
    _request = null;
    super.dispose();
  }
}

class _Request {
  _Request({
    required this.title,
    this.description,
    required this.confirmText,
    this.cancelText = '취소',
    this.alert = false,
    required this.closeOnDimmerClick,
    required this.closeOnBackEvent,
    this.onConfirm,
    this.onCancel,
    this.onError,
  });
  final Widget title;
  final Widget? description;
  final String confirmText, cancelText;
  final bool alert, closeOnDimmerClick, closeOnBackEvent;
  final Future<void> Function()? onConfirm, onCancel;
  final void Function(Object error, StackTrace stack)? onError;
  final result = Completer<bool>();
  bool open = true, confirmBusy = false, cancelBusy = false;
}

class TdsDialogProvider extends StatefulWidget {
  const TdsDialogProvider({required this.child, this.controller, super.key});
  final Widget child;
  final TdsDialogController? controller;
  static TdsDialogController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DialogScope>();
    if (scope == null) {
      throw StateError('A TdsDialogProvider ancestor is required.');
    }
    return scope.controller;
  }

  @override
  State<TdsDialogProvider> createState() => _TdsDialogProviderState();
}

class _TdsDialogProviderState extends State<TdsDialogProvider> {
  late TdsDialogController _controller =
      widget.controller ?? TdsDialogController();
  @override
  void didUpdateWidget(TdsDialogProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      } else {
        _controller.close();
      }
      _controller = widget.controller ?? TdsDialogController();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogScope(
    controller: _controller,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final r = _controller._request;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (r != null)
              r.alert
                  ? TdsAlertDialog(
                      key: ObjectKey(r),
                      open: r.open,
                      title: r.title,
                      description: r.description,
                      closeOnDimmerClick: r.closeOnDimmerClick,
                      closeOnBackEvent: r.closeOnBackEvent,
                      onClose: _controller.close,
                      onExited: () => _controller._exited(r),
                      alertButton: TdsAlertDialogButton(
                        onPressed: () => _controller._activate(r, true),
                        child: Text(r.confirmText),
                      ),
                    )
                  : TdsConfirmDialog(
                      key: ObjectKey(r),
                      open: r.open,
                      title: r.title,
                      description: r.description,
                      closeOnDimmerClick: r.closeOnDimmerClick,
                      closeOnBackEvent: r.closeOnBackEvent,
                      onClose: _controller.close,
                      onExited: () => _controller._exited(r),
                      confirmButton: TdsConfirmDialogButton(
                        loading: r.confirmBusy,
                        onPressed: () => _controller._activate(r, true),
                        child: Text(r.confirmText),
                      ),
                      cancelButton: TdsConfirmDialogButton(
                        cancel: true,
                        loading: r.cancelBusy,
                        onPressed: () => _controller._activate(r, false),
                        child: Text(r.cancelText),
                      ),
                    ),
          ],
        );
      },
    ),
  );
}

class _DialogScope extends InheritedWidget {
  const _DialogScope({required this.controller, required super.child});
  final TdsDialogController controller;
  @override
  bool updateShouldNotify(_DialogScope oldWidget) =>
      controller != oldWidget.controller;
}
