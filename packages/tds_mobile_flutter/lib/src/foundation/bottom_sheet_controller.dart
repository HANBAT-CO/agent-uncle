import 'dart:async';
import 'package:flutter/widgets.dart';
import '../components/bottom_sheet.dart';
import '../components/button.dart';

enum TdsTwoButtonSheetAction { leftButtonClick, rightButtonClick, cancel }

/// Native adapter for cloning a custom React button and its loading property.
typedef TdsSheetButtonBuilder =
    Widget Function(BuildContext context, TdsSheetButtonState state);

@immutable
class TdsSheetButtonState {
  const TdsSheetButtonState({
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });
  final bool loading, disabled;
  final Future<void> Function() onPressed;
}

class TdsBottomSheetOptions {
  const TdsBottomSheetOptions({
    required this.child,
    this.header,
    this.headerDescription,
    this.cta,
    this.onExited,
    this.onEntered,
    this.onClose,
    this.onDimmerClick,
    this.onExpanded,
    this.onHandlerTouchStart,
    this.onHandlerTouchEnd,
    this.maxHeight,
    this.expandedMaxHeight = const TdsBottomSheetHeight.viewport(1),
    this.disableDimmer = false,
    this.disableChildrenDragging = false,
    this.a11yIncludeHeaderInScroll = true,
    this.expandBottomSheet = false,
    this.expandBottomSheetWhenScroll = false,
    this.ctaContentGap = 34,
    this.semanticLabel = '바텀시트',
    this.ignoreDimmerClick = false,
    this.ignoreBackEvent = false,
    this.topAccessory,
    this.bottomAccessory,
  }) : assert(header == null || header is String || header is Widget);
  final Widget child;

  /// useBottomSheet wraps string headers in BottomSheet.Header in the source.
  final Object? header;
  final Widget? headerDescription, cta, topAccessory, bottomAccessory;
  final VoidCallback? onExited, onEntered, onClose;
  final VoidCallback? onDimmerClick,
      onExpanded,
      onHandlerTouchStart,
      onHandlerTouchEnd;
  final TdsBottomSheetHeight? maxHeight;
  final TdsBottomSheetHeight expandedMaxHeight;
  final bool disableDimmer, disableChildrenDragging, a11yIncludeHeaderInScroll;
  final bool expandBottomSheet, expandBottomSheetWhenScroll;
  final double ctaContentGap;
  final String semanticLabel;
  final bool ignoreDimmerClick, ignoreBackEvent;
}

class TdsBottomSheetController extends ChangeNotifier {
  _SheetRequest? _request;
  bool _disposed = false;
  void open(TdsBottomSheetOptions options) => _open(_SheetRequest(options));
  Future<bool> openOneButtonSheet({
    required TdsBottomSheetOptions options,
    String button = '확인',
    TdsSheetButtonBuilder? buttonBuilder,
    bool closeOnButtonClick = true,
  }) async =>
      await _open(
        _SheetRequest(
          options,
          right: button,
          rightBuilder: buttonBuilder,
          closeRight: closeOnButtonClick,
        ),
      ) ==
      TdsTwoButtonSheetAction.rightButtonClick;
  Future<TdsTwoButtonSheetAction> openTwoButtonSheet({
    required TdsBottomSheetOptions options,
    String leftButton = '취소',
    String rightButton = '확인',
    TdsSheetButtonBuilder? leftButtonBuilder,
    TdsSheetButtonBuilder? rightButtonBuilder,
    bool closeOnLeftButtonClick = true,
    bool closeOnRightButtonClick = true,
  }) => _open(
    _SheetRequest(
      options,
      left: leftButton,
      right: rightButton,
      leftBuilder: leftButtonBuilder,
      rightBuilder: rightButtonBuilder,
      closeLeft: closeOnLeftButtonClick,
      closeRight: closeOnRightButtonClick,
    ),
  );
  Future<bool> openAsyncOneButtonSheet({
    required TdsBottomSheetOptions options,
    required Future<void> Function() onClick,
    String button = '확인',
    TdsSheetButtonBuilder? buttonBuilder,
    void Function(Object, StackTrace)? onError,
  }) async =>
      await _open(
        _SheetRequest(
          options,
          right: button,
          rightBuilder: buttonBuilder,
          onRight: onClick,
          onError: onError,
        ),
      ) ==
      TdsTwoButtonSheetAction.rightButtonClick;
  Future<TdsTwoButtonSheetAction> openAsyncTwoButtonSheet({
    required TdsBottomSheetOptions options,
    Future<void> Function()? onLeftButtonClick,
    Future<void> Function()? onRightButtonClick,
    String leftButton = '취소',
    String rightButton = '확인',
    TdsSheetButtonBuilder? leftButtonBuilder,
    TdsSheetButtonBuilder? rightButtonBuilder,
    void Function(Object, StackTrace)? onError,
  }) => _open(
    _SheetRequest(
      options,
      left: leftButton,
      right: rightButton,
      leftBuilder: leftButtonBuilder,
      rightBuilder: rightButtonBuilder,
      onLeft: onLeftButtonClick,
      onRight: onRightButtonClick,
      onError: onError,
    ),
  );
  Future<TdsTwoButtonSheetAction> _open(_SheetRequest request) {
    if (_disposed) throw StateError('TdsBottomSheetController is disposed');
    _request?.resolve(TdsTwoButtonSheetAction.cancel);
    _request = request;
    notifyListeners();
    return request.result.future;
  }

  void close() {
    if (_disposed || _request == null || !_request!.open) return;
    _request!.resolve(TdsTwoButtonSheetAction.cancel);
    _request!.open = false;
    notifyListeners();
  }

  Future<void> _activate(_SheetRequest request, bool right) async {
    if (_disposed ||
        request != _request ||
        !request.open ||
        request.busy != null) {
      return;
    }
    final callback = right ? request.onRight : request.onLeft;
    request.busy = right;
    notifyListeners();
    try {
      await callback?.call();
      if (_disposed || request != _request || !request.open) return;
      request.resolve(
        right
            ? TdsTwoButtonSheetAction.rightButtonClick
            : TdsTwoButtonSheetAction.leftButtonClick,
      );
      if (right ? request.closeRight : request.closeLeft) request.open = false;
    } catch (error, stack) {
      if (request.onError != null) {
        request.onError!(error, stack);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'tds_mobile_flutter',
          ),
        );
      }
    } finally {
      request.busy = null;
      if (!_disposed && request == _request) notifyListeners();
    }
  }

  void _detach() {
    _request?.resolve(TdsTwoButtonSheetAction.cancel);
    _request = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _detach();
    super.dispose();
  }
}

class _SheetRequest {
  _SheetRequest(
    this.options, {
    this.left,
    this.right,
    this.leftBuilder,
    this.rightBuilder,
    this.closeLeft = true,
    this.closeRight = true,
    this.onLeft,
    this.onRight,
    this.onError,
  });
  final TdsBottomSheetOptions options;
  final String? left, right;
  final TdsSheetButtonBuilder? leftBuilder, rightBuilder;
  final bool closeLeft, closeRight;
  final Future<void> Function()? onLeft, onRight;
  final void Function(Object, StackTrace)? onError;
  final result = Completer<TdsTwoButtonSheetAction>();
  bool open = true;
  bool? busy;
  void resolve(TdsTwoButtonSheetAction value) {
    if (!result.isCompleted) result.complete(value);
  }
}

class TdsBottomSheetProvider extends StatefulWidget {
  const TdsBottomSheetProvider({
    required this.child,
    this.controller,
    super.key,
  });
  final Widget child;
  final TdsBottomSheetController? controller;
  static TdsBottomSheetController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SheetScope>();
    if (scope == null) throw StateError('TdsBottomSheetProvider is required');
    return scope.controller;
  }

  @override
  State<TdsBottomSheetProvider> createState() => _TdsBottomSheetProviderState();
}

class _TdsBottomSheetProviderState extends State<TdsBottomSheetProvider> {
  late TdsBottomSheetController _controller;
  void _change() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TdsBottomSheetController();
    _controller.addListener(_change);
  }

  @override
  void didUpdateWidget(TdsBottomSheetProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == oldWidget.controller) return;
    _controller.removeListener(_change);
    _controller._detach();
    if (oldWidget.controller == null) _controller.dispose();
    _controller = widget.controller ?? TdsBottomSheetController();
    _controller.addListener(_change);
  }

  @override
  void dispose() {
    _controller.removeListener(_change);
    _controller._detach();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _controller._request;
    Widget? scoped(Widget? child) => child == null
        ? null
        : _SheetScope(controller: _controller, child: child);
    Widget? cta = request?.options.cta;
    if (request?.right != null) {
      Widget customButton(TdsSheetButtonBuilder builder, bool right) => Builder(
        builder: (context) => builder(
          context,
          TdsSheetButtonState(
            loading: request!.busy == right,
            disabled: request.busy != null && request.busy != right,
            onPressed: () => _controller._activate(request, right),
          ),
        ),
      );
      Widget button(bool right) {
        final builder = right ? request!.rightBuilder : request!.leftBuilder;
        return builder != null
            ? customButton(builder, right)
            : TdsButton(
                variant: right ? TdsButtonVariant.fill : TdsButtonVariant.weak,
                loading: request.busy == right,
                disabled: request.busy != null && request.busy != right,
                onPressed: () => _controller._activate(request, right),
                child: Text((right ? request.right : request.left)!),
              );
      }

      cta = request!.left == null
          ? request.rightBuilder != null
                ? customButton(request.rightBuilder!, true)
                : TdsBottomSheetCTA(
                    loading: request.busy != null,
                    onPressed: () => _controller._activate(request, true),
                    topAccessory: request.options.topAccessory,
                    bottomAccessory: request.options.bottomAccessory,
                    child: Text(request.right!),
                  )
          : TdsBottomSheetDoubleCTA(
              leftButton: button(false),
              rightButton: button(true),
              topAccessory: request.options.topAccessory,
              bottomAccessory: request.options.bottomAccessory,
            );
    }
    return _SheetScope(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          if (request != null)
            TdsBottomSheet(
              open: request.open,
              header: scoped(
                request.options.header is String
                    ? TdsBottomSheetHeader(request.options.header! as String)
                    : request.options.header as Widget?,
              ),
              headerDescription: scoped(request.options.headerDescription),
              cta: scoped(cta),
              maxHeight: request.options.maxHeight,
              expandedMaxHeight: request.options.expandedMaxHeight,
              disableDimmer: request.options.disableDimmer,
              disableChildrenDragging: request.options.disableChildrenDragging,
              a11yIncludeHeaderInScroll:
                  request.options.a11yIncludeHeaderInScroll,
              expandBottomSheet: request.options.expandBottomSheet,
              expandBottomSheetWhenScroll:
                  request.options.expandBottomSheetWhenScroll,
              ctaContentGap: request.options.ctaContentGap,
              semanticLabel: request.options.semanticLabel,
              onDimmerClick: request.options.onDimmerClick,
              onExpanded: request.options.onExpanded,
              onHandlerTouchStart: request.options.onHandlerTouchStart,
              onHandlerTouchEnd: request.options.onHandlerTouchEnd,
              ignoreDimmerClick: request.options.ignoreDimmerClick,
              ignoreBackEvent: request.options.ignoreBackEvent,
              onEntered: request.options.onEntered,
              // Plain open forwards onClose; promise helpers replace it in vw.
              onClose: request.right == null
                  ? request.options.onClose
                  : _controller.close,
              onExited: () {
                request.options.onExited?.call();
                if (mounted &&
                    _controller._request == request &&
                    !request.open) {
                  setState(() => _controller._request = null);
                }
              },
              child: scoped(request.options.child)!,
            ),
        ],
      ),
    );
  }
}

class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.controller, required super.child});
  final TdsBottomSheetController controller;
  @override
  bool updateShouldNotify(_SheetScope oldWidget) =>
      controller != oldWidget.controller;
}

TdsBottomSheetController useBottomSheet(BuildContext context) =>
    TdsBottomSheetProvider.of(context);
