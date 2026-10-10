import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'button.dart';
import 'modal.dart';
import 'text_button.dart';

class TdsDialogTitle extends StatelessWidget {
  const TdsDialogTitle({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: DefaultTextStyle(
      style: TdsTheme.of(context)
          .textStyle(
            typography: TdsTypography.t4,
            fontWeight: TdsFontWeight.bold,
            color: TdsTheme.of(context).color('grey800'),
          )
          .copyWith(height: 1.35),
      child: child,
    ),
  );
}

class TdsDialogDescription extends StatelessWidget {
  const TdsDialogDescription({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TdsTheme.of(context)
        .textStyle(
          typography: TdsTypography.t6,
          fontWeight: TdsFontWeight.medium,
          color: TdsTheme.of(context).color('grey600'),
        )
        .copyWith(height: 1.5),
    child: child,
  );
}

class TdsAlertDialog extends StatelessWidget {
  const TdsAlertDialog({
    required this.open,
    required this.alertButton,
    this.title,
    this.description,
    this.closeOnDimmerClick = true,
    this.closeOnBackEvent = true,
    this.onClose,
    this.onEntered,
    this.onExited,
    super.key,
  });
  final bool open, closeOnDimmerClick, closeOnBackEvent;
  final Widget? title, description;
  final Widget alertButton;
  final VoidCallback? onClose, onEntered, onExited;
  @override
  Widget build(BuildContext context) => TdsModal(
    open: open,
    onClose: onClose,
    onEntered: onEntered,
    onExited: onExited,
    closeOnDimmerClick: closeOnDimmerClick,
    closeOnBackEvent: closeOnBackEvent,
    scaleOnEnter: true,
    child: _DialogBody(
      title: title,
      description: description,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Align(alignment: Alignment.centerRight, child: alertButton),
      ),
    ),
  );
}

class TdsConfirmDialog extends StatelessWidget {
  const TdsConfirmDialog({
    required this.open,
    required this.confirmButton,
    required this.cancelButton,
    this.title,
    this.description,
    this.closeOnDimmerClick = true,
    this.closeOnBackEvent = true,
    this.onClose,
    this.onEntered,
    this.onExited,
    super.key,
  });
  final bool open, closeOnDimmerClick, closeOnBackEvent;
  final Widget? title, description;
  final Widget confirmButton, cancelButton;
  final VoidCallback? onClose, onEntered, onExited;
  @override
  Widget build(BuildContext context) => TdsModal(
    open: open,
    onClose: onClose,
    onEntered: onEntered,
    onExited: onExited,
    closeOnDimmerClick: closeOnDimmerClick,
    closeOnBackEvent: closeOnBackEvent,
    scaleOnEnter: true,
    child: _DialogBody(
      title: title,
      description: description,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: TdsDialogFooter(
          cancelButton: cancelButton,
          confirmButton: confirmButton,
        ),
      ),
    ),
  );
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({this.title, this.description, required this.footer});
  final Widget? title, description;
  final Widget footer;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) TdsDialogTitle(child: title!),
              if (title != null && description != null)
                const SizedBox(height: 8),
              if (description != null)
                TdsDialogDescription(child: description!),
            ],
          ),
        ),
      ),
      footer,
    ],
  );
}

class TdsAlertDialogButton extends StatelessWidget {
  const TdsAlertDialogButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
    child: TdsTextButton(
      size: TdsTextButtonSize.medium,
      fontWeight: TdsFontWeight.bold,
      color: TdsPalette.blue500,
      disabled: disabled,
      onPressed: onPressed,
      child: child,
    ),
  );
}

class TdsConfirmDialogButton extends StatelessWidget {
  const TdsConfirmDialogButton({
    required this.child,
    this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.cancel = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool loading, disabled, cancel;
  @override
  Widget build(BuildContext context) => TdsButton(
    size: TdsButtonSize.large,
    display: TdsButtonDisplay.inline,
    color: cancel ? TdsButtonColor.dark : TdsButtonColor.primary,
    variant: cancel ? TdsButtonVariant.weak : TdsButtonVariant.fill,
    loading: loading,
    disabled: disabled,
    onPressed: onPressed,
    child: child,
  );
}

/// Source footer: flex-grow: 1; min-width: calc(50% - 8px); wrap-reverse.
/// Wrapping depends on actual child width, not a guessed font-scale threshold.
class TdsDialogFooter extends MultiChildRenderObjectWidget {
  TdsDialogFooter({
    required Widget cancelButton,
    required Widget confirmButton,
    super.key,
  }) : super(children: [cancelButton, confirmButton]);
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDialogFooter(Directionality.of(context));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderDialogFooter).textDirection = Directionality.of(
      context,
    );
  }
}

class _FooterParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDialogFooter extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FooterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FooterParentData> {
  _RenderDialogFooter(this._textDirection);
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterParentData) {
      child.parentData = _FooterParentData();
    }
  }

  @override
  void performLayout() {
    final cancel = firstChild!, confirm = lastChild!;
    final width = constraints.maxWidth;
    final cancelBase = cancel.getMaxIntrinsicWidth(double.infinity);
    final confirmBase = confirm.getMaxIntrinsicWidth(double.infinity);
    final minWidth = math.max(0.0, width / 2 - 8);
    final stacked =
        math.max(minWidth, cancelBase) + math.max(minWidth, confirmBase) + 8 >
        width;
    // CSS flex bases are the unclamped content widths. Only then freeze an
    // item violating min-width and redistribute the remaining free space.
    final extra = (width - cancelBase - confirmBase - 8) / 2;
    final cancelWidth = stacked
        ? width
        : (cancelBase + extra).clamp(minWidth, width - 8 - minWidth);
    final confirmWidth = stacked ? width : width - 8 - cancelWidth;
    cancel.layout(
      BoxConstraints.tightFor(width: cancelWidth),
      parentUsesSize: true,
    );
    confirm.layout(
      BoxConstraints.tightFor(width: confirmWidth),
      parentUsesSize: true,
    );
    final cancelData = cancel.parentData! as _FooterParentData;
    final confirmData = confirm.parentData! as _FooterParentData;
    if (stacked) {
      confirmData.offset = Offset.zero;
      cancelData.offset = Offset(0, confirm.size.height + 8);
      size = constraints.constrain(
        Size(width, cancel.size.height + confirm.size.height + 8),
      );
    } else {
      final height = math.max(cancel.size.height, confirm.size.height);
      cancel.layout(
        BoxConstraints.tightFor(width: cancelWidth, height: height),
      );
      confirm.layout(
        BoxConstraints.tightFor(width: confirmWidth, height: height),
      );
      final rtl = _textDirection == TextDirection.rtl;
      cancelData.offset = rtl ? Offset(confirmWidth + 8, 0) : Offset.zero;
      confirmData.offset = rtl ? Offset.zero : Offset(cancelWidth + 8, 0);
      size = constraints.constrain(Size(width, height));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
