import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import 'text_field.dart';

class TdsSplitInput {
  const TdsSplitInput({
    this.value,
    this.defaultValue,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.placeholder,
    this.disabled = false,
    this.readOnly = false,
  }) : assert(controller == null || (value == null && defaultValue == null));
  final String? value, defaultValue, placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool disabled, readOnly;
}

class TdsSplitTextField extends StatefulWidget {
  const TdsSplitTextField.rrn13({
    required this.variant,
    this.first = const TdsSplitInput(),
    this.second = const TdsSplitInput(),
    this.label = '주민등록번호',
    this.help,
    this.labelOption,
    this.focused = false,
    this.mask = true,
    this.hasError = false,
    this.paddingTop = 16,
    this.paddingBottom = 16,
    super.key,
  }) : first7 = false;
  const TdsSplitTextField.rrnFirst7({
    required this.variant,
    this.first = const TdsSplitInput(),
    this.second = const TdsSplitInput(),
    this.label = '주민등록번호',
    this.help,
    this.labelOption,
    this.focused = false,
    this.mask = false,
    this.hasError = false,
    this.paddingTop = 16,
    this.paddingBottom = 16,
    super.key,
  }) : first7 = true;
  final TdsTextFieldVariant variant;
  final TdsSplitInput first, second;
  final String label;
  final Widget? help;
  final TdsTextFieldLabelOption? labelOption;
  final bool focused, mask, hasError, first7;
  final double paddingTop, paddingBottom;
  @override
  State<TdsSplitTextField> createState() => _TdsSplitTextFieldState();
}

class _TdsSplitTextFieldState extends State<TdsSplitTextField> {
  late final controllers = <TextEditingController>[];
  late final nodes = <FocusNode>[];
  List<TdsSplitInput> get inputs => [widget.first, widget.second];
  @override
  void initState() {
    super.initState();
    for (final input in inputs) {
      controllers.add(
        input.controller ??
            TextEditingController(text: input.value ?? input.defaultValue),
      );
      nodes.add(input.focusNode ?? FocusNode());
    }
    for (final c in controllers) {
      c.addListener(update);
    }
    for (final n in nodes) {
      n.addListener(update);
    }
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(TdsSplitTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = [oldWidget.first, oldWidget.second];
    for (var i = 0; i < 2; i++) {
      if (old[i].controller != inputs[i].controller) {
        final previous = controllers[i].value;
        controllers[i].removeListener(update);
        if (old[i].controller == null) controllers[i].dispose();
        controllers[i] =
            inputs[i].controller ?? TextEditingController.fromValue(previous);
        controllers[i].addListener(update);
      }
      if (old[i].focusNode != inputs[i].focusNode) {
        nodes[i].removeListener(update);
        if (old[i].focusNode == null) nodes[i].dispose();
        nodes[i] = inputs[i].focusNode ?? FocusNode();
        nodes[i].addListener(update);
      }
      if (inputs[i].value != null && inputs[i].value != controllers[i].text) {
        controllers[i].value = TextEditingValue(
          text: inputs[i].value!,
          selection: TextSelection.collapsed(offset: inputs[i].value!.length),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < 2; i++) {
      controllers[i].removeListener(update);
      nodes[i].removeListener(update);
      if (inputs[i].controller == null) controllers[i].dispose();
      if (inputs[i].focusNode == null) nodes[i].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final focused = widget.focused || nodes.any((n) => n.hasFocus),
        hasValue = controllers.any((c) => c.text.isNotEmpty);
    final box = widget.variant == TdsTextFieldVariant.box;
    final style = theme.textStyle(
      typography: box ? TdsTypography.t5 : TdsTypography.t3,
    );
    Widget input(int i) {
      final config = inputs[i], controller = controllers[i];
      final placeholder =
          config.placeholder ??
          (i == 0
              ? box
                    ? '생년월일'
                    : '주민등록번호'
              : widget.first7
              ? '*'
              : box
              ? '뒷자리'
              : '');
      return Focus(
        onKeyEvent: (_, event) {
          if (i == 1 &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            nodes[0].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (controller.text.isEmpty)
              IgnorePointer(
                child: Text(
                  placeholder,
                  style: style.copyWith(color: theme.color('grey400')),
                ),
              ),
            EditableText(
              controller: controller,
              focusNode: nodes[i],
              style: style,
              cursorColor: theme.color('blue500'),
              backgroundCursorColor: theme.color('grey200'),
              readOnly: config.disabled || config.readOnly,
              keyboardType: TextInputType.number,
              obscureText: i == 1 && widget.mask,
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(
                  i == 0
                      ? 6
                      : widget.first7
                      ? 1
                      : 7,
                ),
              ],
              onChanged: (value) {
                config.onChanged?.call(value);
                if (i == 0 && value.length == 6 && !widget.second.disabled) {
                  nodes[1].requestFocus();
                }
                if (config.value != null && controller.text != config.value) {
                  controller.text = config.value!;
                }
              },
            ),
          ],
        ),
      );
    }

    return TdsTextFieldContainer(
      variant: widget.variant,
      label: widget.label,
      help: widget.help,
      focused: focused,
      hasValue: hasValue,
      hasError: widget.hasError,
      labelOption:
          widget.labelOption ??
          (box
              ? TdsTextFieldLabelOption.sustain
              : TdsTextFieldLabelOption.appear),
      paddingTop: widget.paddingTop,
      paddingBottom: widget.paddingBottom,
      child: TdsTextFieldSurface(
        variant: widget.variant,
        hasValue: hasValue,
        focused: focused,
        hasError: widget.hasError,
        child: Row(
          children: [
            Expanded(
              child: Semantics(label: '생년월일 6자리', child: input(0)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('-', style: style),
            ),
            Expanded(
              child: Row(
                children: [
                  if (widget.first7)
                    SizedBox(width: style.fontSize! * .8, child: input(1))
                  else
                    Expanded(child: input(1)),
                  if (widget.first7)
                    Flexible(
                      child: Text(
                        '******',
                        style: style.copyWith(color: theme.color('grey400')),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
