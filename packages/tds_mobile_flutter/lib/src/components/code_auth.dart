import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/portal.dart';
import 'loader.dart';
import 'post.dart';
import 'text.dart';
import 'text_button.dart';

enum TdsCodeAuthStep { typing, loading, success, error, retry }

typedef TdsCodeValidator = bool Function(String character);

class TdsCodeAuthController extends ChangeNotifier {
  TdsCodeAuthController({required this.length, TdsCodeValidator? validate})
    : assert(length > 0),
      validate = validate ?? _digits {
    editing.addListener(_changed);
    focusNode.addListener(_changed);
  }
  final int length;
  final TdsCodeValidator validate;
  final editing = TextEditingController();
  final focusNode = FocusNode();
  int _revision = 0;
  bool _disposed = false;
  String _lastText = '';
  int get revision => _revision;
  bool get disposed => _disposed;
  TdsCodeAuthStep _step = TdsCodeAuthStep.typing;
  TdsCodeAuthStep get step => _step;
  String get value => editing.text;
  bool get complete => value.characters.length == length;
  bool get locked => [
    TdsCodeAuthStep.loading,
    TdsCodeAuthStep.success,
    TdsCodeAuthStep.error,
  ].contains(step);
  static bool _digits(String value) => RegExp(r'^[0-9]$').hasMatch(value);
  void _changed() {
    if (_lastText != editing.text) {
      _lastText = editing.text;
      _revision++;
    }
    if (!_disposed) notifyListeners();
  }

  void setStep(TdsCodeAuthStep step) {
    if (_disposed) return;
    _step = step;
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    _revision++;
    _step = TdsCodeAuthStep.typing;
    editing.clear();
    notifyListeners();
    focusNode.requestFocus();
  }

  void focus(int index) {
    if (locked) return;
    if (step == TdsCodeAuthStep.retry && complete) clear();
    focusNode.requestFocus();
    final offset = index.clamp(0, editing.text.length);
    editing.selection = TextSelection(
      baseOffset: offset,
      extentOffset: math.min(offset + 1, editing.text.length),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    editing.removeListener(_changed);
    focusNode.removeListener(_changed);
    editing.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class _CodeScope extends InheritedNotifier<TdsCodeAuthController> {
  const _CodeScope({
    required TdsCodeAuthController controller,
    required super.child,
  }) : super(notifier: controller);
  static TdsCodeAuthController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CodeScope>()?.notifier ??
      (throw StateError('AuthField requires TdsCodeAuthFieldController'));
}

class _ModuleStep extends InheritedNotifier<ValueNotifier<TdsCodeAuthStep>> {
  const _ModuleStep({
    required ValueNotifier<TdsCodeAuthStep> step,
    required super.child,
  }) : super(notifier: step);
  static TdsCodeAuthStep of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ModuleStep>()
          ?.notifier
          ?.value ??
      TdsCodeAuthStep.typing;
}

class TdsCodeAuthModule extends StatefulWidget {
  const TdsCodeAuthModule({required this.child, super.key});
  final Widget child;
  @override
  State<TdsCodeAuthModule> createState() => _TdsCodeAuthModuleState();
}

class _TdsCodeAuthModuleState extends State<TdsCodeAuthModule> {
  final step = ValueNotifier(TdsCodeAuthStep.typing);
  @override
  void dispose() {
    step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ModuleStep(step: step, child: widget.child);
}

class TdsCodeAuthFieldController extends StatefulWidget {
  const TdsCodeAuthFieldController({
    required this.length,
    required this.builder,
    this.validate,
    this.controller,
    super.key,
  });
  final int length;
  final TdsCodeValidator? validate;
  final TdsCodeAuthController? controller;
  final Widget Function(BuildContext, VoidCallback clear) builder;
  @override
  State<TdsCodeAuthFieldController> createState() =>
      _TdsCodeAuthFieldControllerState();
}

class _TdsCodeAuthFieldControllerState
    extends State<TdsCodeAuthFieldController> {
  late TdsCodeAuthController controller =
      widget.controller ??
      TdsCodeAuthController(length: widget.length, validate: widget.validate);
  @override
  void didUpdateWidget(TdsCodeAuthFieldController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.length != oldWidget.length ||
        widget.validate != oldWidget.validate) {
      if (oldWidget.controller == null) controller.dispose();
      controller =
          widget.controller ??
          TdsCodeAuthController(
            length: widget.length,
            validate: widget.validate,
          );
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CodeScope(
    controller: controller,
    child: Builder(
      builder: (context) => widget.builder(context, controller.clear),
    ),
  );
}

class TdsCodeAuthField<T> extends StatefulWidget {
  const TdsCodeAuthField({
    this.error,
    this.numeric = true,
    this.successMessage = '인증 성공!',
    this.onSubmit,
    this.onSuccess,
    this.onFailure,
    this.onError,
    super.key,
  });
  final Widget? error;
  final bool numeric;
  final String successMessage;
  final FutureOr<T> Function(String value)? onSubmit;
  final ValueChanged<T?>? onSuccess;
  final VoidCallback? onFailure;
  final void Function(Object, StackTrace)? onError;
  @override
  State<TdsCodeAuthField<T>> createState() => _TdsCodeAuthFieldState<T>();
}

class _TdsCodeAuthFieldState<T> extends State<TdsCodeAuthField<T>> {
  TdsCodeAuthController? controller;
  ValueNotifier<TdsCodeAuthStep>? moduleStep;
  int generation = 0;
  Timer? retryTimer, successTimer;
  String? submitted;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = _CodeScope.of(context);
    moduleStep = context
        .dependOnInheritedWidgetOfExactType<_ModuleStep>()
        ?.notifier;
    if (current != controller) {
      controller?.removeListener(onChanged);
      generation++;
      retryTimer?.cancel();
      successTimer?.cancel();
      submitted = null;
      controller = current..addListener(onChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onChanged();
    });
  }

  void onChanged() {
    final current = controller!;
    if (current.disposed) return;
    if (moduleStep?.value != current.step) {
      final currentStep = current.step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !current.disposed && current.step == currentStep) {
          moduleStep?.value = currentStep;
        }
      });
    }
    if (current.step == TdsCodeAuthStep.typing && current.value.isEmpty) {
      submitted = null;
    }
    if (!current.complete || current.locked || current.value == submitted) {
      return;
    }
    submit(current);
  }

  void step(TdsCodeAuthStep value) {
    controller?.setStep(value);
    moduleStep?.value = value;
  }

  Future<void> submit(TdsCodeAuthController current) async {
    final request = ++generation, revision = current.revision;
    submitted = current.value;
    step(TdsCodeAuthStep.loading);
    T? result;
    Object? failure;
    StackTrace? trace;
    final minimum = Future<void>.delayed(const Duration(seconds: 1));
    try {
      result = await widget.onSubmit?.call(current.value);
    } catch (error, stack) {
      failure = error;
      trace = stack;
    }
    await minimum;
    bool valid() =>
        mounted &&
        request == generation &&
        !current.disposed &&
        revision == current.revision;
    if (!valid()) return;
    final success = failure == null && result != null && result != false;
    step(success ? TdsCodeAuthStep.success : TdsCodeAuthStep.error);
    if (success) {
      successTimer = Timer(const Duration(milliseconds: 600), () {
        if (valid()) widget.onSuccess?.call(result);
      });
    } else {
      widget.onFailure?.call();
      if (failure != null) widget.onError?.call(failure, trace!);
      retryTimer = Timer(const Duration(milliseconds: 1300), () {
        if (!valid()) return;
        step(TdsCodeAuthStep.retry);
        current.focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    generation++;
    controller?.removeListener(onChanged);
    retryTimer?.cancel();
    successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _CodeScope.of(context), theme = TdsTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math
                  .min(
                    48.0,
                    (constraints.maxWidth - 8 * (model.length - 1)) /
                        model.length,
                  )
                  .clamp(20.0, 48.0);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: model.step == TdsCodeAuthStep.success ? 0 : 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < model.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: i == model.length - 1 ? 0 : 8,
                            ),
                            child: Container(
                              width: width,
                              height: width == 48 ? 60 : 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: theme.color('grey50'),
                                border: Border.all(
                                  color: theme.color(
                                    model.step == TdsCodeAuthStep.error
                                        ? 'red500'
                                        : 'grey200',
                                  ),
                                ),
                              ),
                              child: TdsText(
                                i < model.value.length ? model.value[i] : '',
                                typography: TdsTypography.t1,
                                fontWeight: TdsFontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (model.step == TdsCodeAuthStep.loading) const TdsLoader(),
                  if (model.step == TdsCodeAuthStep.success)
                    Semantics(
                      liveRegion: true,
                      child: TdsText(
                        widget.successMessage,
                        color: theme.color('blue500'),
                        fontWeight: TdsFontWeight.bold,
                      ),
                    ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: Semantics(
                        label: '인증번호 ${model.length}자리',
                        textField: true,
                        child: EditableText(
                          controller: model.editing,
                          focusNode: model.focusNode,
                          style: theme.textStyle(),
                          cursorColor: theme.color('blue500'),
                          backgroundCursorColor: theme.color('grey200'),
                          readOnly: model.locked,
                          autofocus: true,
                          keyboardType: widget.numeric
                              ? TextInputType.number
                              : TextInputType.text,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          enableSuggestions: false,
                          autocorrect: false,
                          inputFormatters: [
                            TextInputFormatter.withFunction((old, next) {
                              if (model.locked) return old;
                              final text = next.text.characters
                                  .where(model.validate)
                                  .take(model.length)
                                  .join();
                              return TextEditingValue(
                                text: text,
                                selection: TextSelection.collapsed(
                                  offset: text.length,
                                ),
                              );
                            }),
                          ],
                          onTapOutside: (_) => model.focusNode.unfocus(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (model.step == TdsCodeAuthStep.error && widget.error != null)
          widget.error!,
      ],
    );
  }
}

class TdsCodeAuthModuleField extends StatelessWidget {
  const TdsCodeAuthModuleField({
    required this.length,
    this.validate,
    this.numeric = true,
    this.error,
    this.onSubmit,
    this.onSuccess,
    this.onFailure,
    this.onError,
    super.key,
  });
  final int length;
  final TdsCodeValidator? validate;
  final bool numeric;
  final Widget? error;
  final FutureOr<bool> Function(String)? onSubmit;
  final VoidCallback? onSuccess, onFailure;
  final void Function(Object, StackTrace)? onError;
  @override
  Widget build(BuildContext context) => TdsCodeAuthFieldController(
    length: length,
    validate: validate,
    builder: (_, clear) => TdsCodeAuthField<bool>(
      numeric: numeric,
      error: error,
      onSubmit: onSubmit,
      onSuccess: (_) => onSuccess?.call(),
      onFailure: onFailure,
      onError: onError,
    ),
  );
}

class TdsCodeAuthError extends StatelessWidget {
  const TdsCodeAuthError(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TdsText(
        text,
        typography: TdsTypography.t6,
        color: TdsTheme.of(context).color('red500'),
      ),
    ),
  );
}

class TdsCodeAuthTop extends StatelessWidget {
  const TdsCodeAuthTop({this.title, this.subtitle, super.key});
  final Widget? title, subtitle;
  @override
  Widget build(BuildContext context) {
    final hidden = _ModuleStep.of(context) == TdsCodeAuthStep.success;
    return ExcludeSemantics(
      excluding: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: Column(children: [?title, ?subtitle]),
      ),
    );
  }
}

class TdsCodeAuthTopTitle extends TdsPostH2 {
  const TdsCodeAuthTopTitle(
    super.text, {
    super.paddingBottom,
    super.color,
    super.key,
  });
}

class TdsCodeAuthTopSubtitle extends StatelessWidget {
  const TdsCodeAuthTopSubtitle(
    this.text, {
    this.paddingBottom = 0,
    this.color,
    super.key,
  });
  final String text;
  final double paddingBottom;
  final Color? color;
  @override
  Widget build(BuildContext context) => TdsPostParagraph(
    text,
    paddingBottom: paddingBottom,
    color: color ?? TdsTheme.of(context).color('grey500'),
  );
}

class TdsCodeAuthFixedBottomTextButton extends StatelessWidget {
  const TdsCodeAuthFixedBottomTextButton({
    required this.child,
    this.onPressed,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final hidden = [
      TdsCodeAuthStep.loading,
      TdsCodeAuthStep.success,
    ].contains(_ModuleStep.of(context));
    return TdsFixedPanel(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ExcludeFocus(
            excluding: hidden,
            child: ExcludeSemantics(
              excluding: hidden,
              child: IgnorePointer(
                ignoring: hidden,
                child: AnimatedOpacity(
                  opacity: hidden ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: TdsTextButton(
                      size: TdsTextButtonSize.small,
                      variant: TdsTextButtonVariant.underline,
                      onPressed: onPressed,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
