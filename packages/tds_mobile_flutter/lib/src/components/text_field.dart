import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/line_box.dart';
import '../foundation/pressable.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'asset.dart';

enum TdsTextFieldVariant { box, line, big, hero }

enum TdsTextFieldLabelOption { appear, sustain }

/// Mirrors TextField.format's raw/display pair. A Flutter controller holds the
/// displayed string, while value/defaultValue and onChanged use the raw string.
class TdsTextFieldFormat {
  const TdsTextFieldFormat({required this.transform, this.reset});
  final String Function(String value) transform;
  final String Function(String value)? reset;
  static final phoneNumber = TdsTextFieldFormat(
    transform: (value) {
      final input = value.substring(
        0,
        value.length.clamp(0, value.startsWith('02') ? 10 : 11),
      );
      for (final pattern in [
        r'^(010)(\d{1,4})(\d{0,4})$',
        r'^(02)(\d{1,3})(\d{0,4})$',
        r'^(02)(\d{1,4})(\d{0,4})$',
        r'^(\d{3})(\d{1,3})(\d{0,4})$',
        r'^(\d{3})(\d{1,4})(\d{0,4})$',
      ]) {
        final match = RegExp(pattern).firstMatch(input);
        if (match != null) {
          return [
            match[1]!,
            match[2]!,
            match[3]!,
          ].where((s) => s.isNotEmpty).join('-');
        }
      }
      return RegExp(r'(\d*)').firstMatch(input)![1]!;
    },
    reset: (value) => value.replaceAll(RegExp(r'\D'), ''),
  );
  static final price = TdsTextFieldFormat(
    transform: (value) {
      final dot = value.indexOf('.');
      final integer = dot < 0 ? value : value.substring(0, dot);
      return integer.replaceAllMapped(
            RegExp(r'(\d)(?=(\d\d\d)+(?!\d))'),
            (m) => '${m[1]},',
          ) +
          (dot < 0 ? '' : value.substring(dot));
    },
    reset: (value) => value.replaceAll(',', ''),
  );
}

class _TdsFormatter extends TextInputFormatter {
  const _TdsFormatter(this.format);
  final TdsTextFieldFormat format;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Never rewrite an IME composing region (Korean input in particular).
    if (!newValue.composing.isCollapsed) return newValue;
    String raw(String value) => format.reset?.call(value) ?? value;
    final text = format.transform(raw(newValue.text));
    int offset(int index) => index < 0
        ? text.length
        : format
              .transform(
                raw(
                  newValue.text.substring(
                    0,
                    index.clamp(0, newValue.text.length),
                  ),
                ),
              )
              .length
              .clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}

class TdsTextField extends StatefulWidget {
  const TdsTextField({
    required this.variant,
    this.value,
    this.defaultValue,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onFocus,
    this.onBlur,
    this.label,
    this.placeholder,
    this.help,
    this.labelOption = TdsTextFieldLabelOption.appear,
    this.hasError = false,
    this.disabled = false,
    this.readOnly = false,
    this.autofocus = false,
    this.prefix,
    this.suffix,
    this.right,
    this.format,
    this.paddingTop = 16,
    this.paddingBottom = 16,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters = const [],
    this.clearable = false,
    this.password = false,
    this.onClear,
    this.onVisibilityChange,
    this.clearButtonLabel,
    this.visibilityButtonLabel,
    this.semanticLabel,
    this.multiline = false,
    this.minHeight,
    this.height,
    this.autofillHints,
    this.selectionControls,
    super.key,
  }) : assert(controller == null || (value == null && defaultValue == null)),
       assert(value == null || defaultValue == null),
       assert(!password || !multiline);
  final TdsTextFieldVariant variant;
  final String? value, defaultValue, label, placeholder, prefix, suffix;
  final String? clearButtonLabel, visibilityButtonLabel, semanticLabel;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onFocus, onBlur, onClear;
  final ValueChanged<bool>? onVisibilityChange;
  final Widget? help, right;
  final TdsTextFieldLabelOption labelOption;
  final bool hasError,
      disabled,
      readOnly,
      autofocus,
      clearable,
      password,
      multiline;
  final double paddingTop, paddingBottom;
  final double? minHeight, height;
  final TdsTextFieldFormat? format;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final List<TextInputFormatter> inputFormatters;
  final Iterable<String>? autofillHints;
  final TextSelectionControls? selectionControls;
  @override
  State<TdsTextField> createState() => _TdsTextFieldState();
}

class _TdsTextFieldState extends State<TdsTextField> {
  late TextEditingController _controller;
  late FocusNode _focus;
  bool _visible = false, _clearFocused = false;
  Timer? _blurTimer;
  String _display(String value) => widget.format?.transform(value) ?? value;
  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        TextEditingController(
          text: _display(widget.value ?? widget.defaultValue ?? ''),
        );
    _focus = widget.focusNode ?? FocusNode();
    _controller.addListener(_valueChanged);
    _focus.addListener(_focusChanged);
  }

  void _valueChanged() {
    if (mounted) setState(() {});
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _blurTimer?.cancel();
      _clearFocused = true;
      widget.onFocus?.call();
    } else {
      widget.onBlur?.call();
      _blurTimer?.cancel();
      _blurTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _clearFocused = false);
      });
    }
    if (mounted) setState(() {});
  }

  void _replace(String value) {
    if (_controller.text == value) return;
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(
        offset: _controller.selection.extentOffset.clamp(0, value.length),
      ),
    );
  }

  void _change(String displayed) {
    if (!_controller.value.composing.isCollapsed && widget.format != null) {
      return;
    }
    final raw = widget.format?.reset?.call(displayed) ?? displayed;
    widget.onChanged?.call(raw);
    if (widget.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.value != null &&
            _controller.value.composing.isCollapsed) {
          _replace(_display(widget.value!));
        }
      });
    }
  }

  @override
  void didUpdateWidget(TdsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previous = _controller.value;
      _controller.removeListener(_valueChanged);
      if (oldWidget.controller == null) _controller.dispose();
      _controller =
          widget.controller ?? TextEditingController.fromValue(previous);
      _controller.addListener(_valueChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_focusChanged);
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_focusChanged);
    }
    if (widget.value != null && _controller.value.composing.isCollapsed) {
      _replace(_display(widget.value!));
    }
    if (widget.disabled && _focus.hasFocus) _focus.unfocus();
    if (widget.hasError && !oldWidget.hasError) {
      tdsHapticOf(context).generate(TdsHapticType.error);
    }
  }

  @override
  void dispose() {
    _blurTimer?.cancel();
    _controller.removeListener(_valueChanged);
    _focus.removeListener(_focusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final style = tdsTextFieldStyle(theme, widget.variant, widget.disabled);
    final hasValue = _controller.text.isNotEmpty;
    final iconSize =
        widget.variant == TdsTextFieldVariant.big ||
            widget.variant == TdsTextFieldVariant.hero
        ? 24.0
        : 20.0;
    Widget? right = widget.right;
    if (widget.clearable && hasValue && _clearFocused && !widget.disabled) {
      right = Focus(
        onFocusChange: (focused) {
          _blurTimer?.cancel();
          if (focused) {
            _clearFocused = true;
          } else {
            _focusChanged();
          }
        },
        child: TdsPressable(
          semanticLabel:
              widget.clearButtonLabel ??
              '${widget.label ?? widget.placeholder ?? ''}${widget.label == null && widget.placeholder == null ? '' : ' '}값 지우기',
          onPressed: () {
            _controller.clear();
            _change('');
            widget.onClear?.call();
            _focus.requestFocus();
          },
          builder: (context, p, h, f) => TdsAssetIcon(
            name: 'icon-x-circle-mono',
            size: iconSize,
            color: theme.color('grey400'),
          ),
        ),
      );
    }
    if (widget.password) {
      right = Semantics(
        toggled: _visible,
        child: TdsPressable(
          enabled: !widget.disabled,
          semanticLabel:
              widget.visibilityButtonLabel ??
              '${widget.label ?? widget.placeholder ?? '비밀번호'} 표시',
          onPressed: () {
            setState(() => _visible = !_visible);
            widget.onVisibilityChange?.call(_visible);
          },
          builder: (context, p, h, f) => TdsAssetIcon(
            name: _visible ? 'icon-eye-on-mono' : 'icon-eye-off-mono',
            size: iconSize,
            color: _visible ? TdsPalette.blue500 : theme.color('grey400'),
          ),
        ),
      );
    }
    Widget editor = Semantics(
      label: widget.semanticLabel ?? widget.label ?? widget.placeholder,
      enabled: !widget.disabled,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (!hasValue && widget.placeholder != null)
            ExcludeSemantics(
              child: Text(
                widget.placeholder!,
                maxLines: widget.multiline ? null : 1,
                overflow: widget.multiline ? null : TextOverflow.clip,
                style: style.copyWith(
                  color: theme.color(widget.disabled ? 'grey400' : 'grey500'),
                ),
              ),
            ),
          IgnorePointer(
            ignoring: widget.disabled,
            child: ExcludeFocus(
              excluding: widget.disabled,
              child: EditableText(
                controller: _controller,
                focusNode: _focus,
                style: style,
                cursorColor: TdsPalette.blue500,
                backgroundCursorColor: theme.color('grey400'),
                selectionColor: TdsPalette.blue400.withValues(alpha: .3),
                selectionControls: widget.selectionControls,
                readOnly: widget.readOnly || widget.disabled,
                autofocus: widget.autofocus,
                obscureText: widget.password && !_visible,
                autocorrect: false,
                enableSuggestions: !widget.password,
                maxLines: widget.multiline ? null : 1,
                minLines: 1,
                keyboardType:
                    widget.keyboardType ??
                    (widget.multiline
                        ? TextInputType.multiline
                        : TextInputType.text),
                textInputAction: widget.textInputAction,
                textAlign: widget.maxLength == 1
                    ? TextAlign.center
                    : TextAlign.start,
                autofillHints: widget.autofillHints,
                inputFormatters: [
                  ...widget.inputFormatters,
                  if (widget.maxLength != null)
                    LengthLimitingTextInputFormatter(widget.maxLength),
                  if (widget.format != null) _TdsFormatter(widget.format!),
                ],
                onChanged: _change,
                onSubmitted: (text) => widget.onSubmitted?.call(
                  widget.format?.reset?.call(text) ?? text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!widget.multiline) {
      editor = TdsLineBox(
        lineHeight: style.fontSize! * style.height!,
        child: editor,
      );
    }
    if (widget.height != null || widget.minHeight != null) {
      editor = ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
        child: SizedBox(height: widget.height, child: editor),
      );
    }
    return TdsTextFieldContainer(
      variant: widget.variant,
      label: widget.label,
      labelOption: widget.labelOption,
      hasValue: hasValue,
      focused: _focus.hasFocus,
      hasError: widget.hasError,
      help: widget.help,
      paddingTop: widget.paddingTop,
      paddingBottom: widget.paddingBottom,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (!widget.disabled) {
            _focus.requestFocus();
          } else {
            tdsHapticOf(context).generate(TdsHapticType.wiggle);
          }
        },
        child: TdsTextFieldSurface(
          variant: widget.variant,
          hasValue: hasValue,
          focused: _focus.hasFocus,
          hasError: widget.hasError,
          disabled: widget.disabled,
          prefix: widget.prefix,
          suffix: widget.suffix,
          right: right,
          child: editor,
        ),
      ),
    );
  }
}

TextStyle tdsTextFieldStyle(
  TdsThemeData theme,
  TdsTextFieldVariant variant,
  bool disabled,
) => theme.textStyle(
  typography: switch (variant) {
    TdsTextFieldVariant.box => TdsTypography.t5,
    TdsTextFieldVariant.line => TdsTypography.t3,
    _ => TdsTypography.t1,
  },
  fontWeight: variant == TdsTextFieldVariant.box
      ? TdsFontWeight.regular
      : TdsFontWeight.semibold,
  color: theme.color(disabled ? 'grey400' : 'grey800'),
);

class TdsTextFieldContainer extends StatelessWidget {
  const TdsTextFieldContainer({
    required this.variant,
    required this.child,
    this.label,
    this.help,
    this.labelOption = TdsTextFieldLabelOption.appear,
    this.hasValue = false,
    this.focused = false,
    this.hasError = false,
    this.paddingTop = 16,
    this.paddingBottom = 16,
    super.key,
  });
  final TdsTextFieldVariant variant;
  final Widget child;
  final String? label;
  final Widget? help;
  final TdsTextFieldLabelOption labelOption;
  final bool hasValue, focused, hasError;
  final double paddingTop, paddingBottom;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final labelColor = hasError
        ? TdsPalette.red600
        : focused
        ? TdsPalette.blue600
        : theme.color('grey800');
    return Padding(
      padding: EdgeInsets.only(top: paddingTop, bottom: paddingBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Visibility(
              visible:
                  labelOption == TdsTextFieldLabelOption.sustain || hasValue,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                child: TdsLineBox(
                  lineHeight: theme.platform.lineHeight(TdsTypography.t7),
                  child: Text(
                    label!,
                    style: theme.textStyle(
                      typography: TdsTypography.t7,
                      color: labelColor,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: variant == TdsTextFieldVariant.box ? 20 : 24,
            ),
            child: child,
          ),
          if (help != null)
            Semantics(
              liveRegion: hasError,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: DefaultTextStyle(
                  style: theme.textStyle(
                    typography: TdsTypography.t7,
                    color: hasError
                        ? TdsPalette.red600
                        : theme.color('grey600'),
                  ),
                  child: help is Text
                      ? TdsLineBox(
                          lineHeight: theme.platform.lineHeight(
                            TdsTypography.t7,
                          ),
                          child: help!,
                        )
                      : help!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TdsTextFieldSurface extends StatelessWidget {
  const TdsTextFieldSurface({
    required this.variant,
    required this.child,
    this.hasValue = false,
    this.focused = false,
    this.hasError = false,
    this.disabled = false,
    this.prefix,
    this.suffix,
    this.right,
    super.key,
  });
  final TdsTextFieldVariant variant;
  final Widget child;
  final bool hasValue, focused, hasError, disabled;
  final String? prefix, suffix;
  final Widget? right;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context),
        box = variant == TdsTextFieldVariant.box;
    final underline =
        variant == TdsTextFieldVariant.line ||
        variant == TdsTextFieldVariant.big;
    final border = disabled
        ? theme.color('grey100')
        : hasError
        ? TdsPalette.red600
        : focused
        ? TdsPalette.blue400
        : theme.color('grey100');
    final background = !box
        ? const Color(0x00000000)
        : theme.color(disabled ? 'grey200' : 'greyOpacity50');
    final tint = !box || disabled
        ? const Color(0x00000000)
        : hasError
        ? TdsPalette.red900.withValues(alpha: .05)
        : focused
        ? TdsPalette.blue900.withValues(alpha: .05)
        : const Color(0x00000000);
    return ClipRRect(
      borderRadius: BorderRadius.circular(box ? 14 : 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        padding: box
            ? const EdgeInsets.symmetric(vertical: 14, horizontal: 16)
            : EdgeInsets.only(bottom: underline ? 4 : 0),
        decoration: BoxDecoration(
          color: Color.alphaBlend(tint, background),
          borderRadius: BorderRadius.circular(box ? 14 : 0),
          border: box
              ? Border.all(color: TdsPalette.greyOpacity100)
              : underline
              ? Border(bottom: BorderSide(color: border, width: 2))
              : null,
        ),
        child: DefaultTextStyle(
          style: tdsTextFieldStyle(theme, variant, disabled),
          child: Row(
            children: [
              if (prefix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    prefix!,
                    style: TextStyle(color: theme.color('grey800')),
                  ),
                ),
              Expanded(child: child),
              if (suffix != null)
                Text(
                  suffix!,
                  style: TextStyle(
                    color: theme.color(hasValue ? 'grey800' : 'grey500'),
                  ),
                ),
              if (right != null)
                Padding(padding: const EdgeInsets.only(left: 8), child: right!),
            ],
          ),
        ),
      ),
    );
  }
}

class TdsTextFieldClearable extends TdsTextField {
  const TdsTextFieldClearable({
    required super.variant,
    super.controller,
    super.focusNode,
    super.value,
    super.defaultValue,
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.clearButtonLabel,
    super.label,
    super.placeholder,
    super.help,
    super.hasError,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.prefix,
    super.suffix,
    super.format,
    super.paddingTop,
    super.paddingBottom,
    super.labelOption,
    super.keyboardType,
    super.textInputAction,
    super.maxLength,
    super.inputFormatters,
    super.semanticLabel,
    super.autofillHints,
    super.selectionControls,
    super.onFocus,
    super.onBlur,
    super.key,
  }) : super(clearable: true);
}

class TdsTextFieldPassword extends TdsTextField {
  const TdsTextFieldPassword({
    required super.variant,
    super.controller,
    super.focusNode,
    super.value,
    super.defaultValue,
    super.onChanged,
    super.onSubmitted,
    super.onVisibilityChange,
    super.visibilityButtonLabel,
    super.label,
    super.placeholder,
    super.help,
    super.hasError,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.prefix,
    super.suffix,
    super.paddingTop,
    super.paddingBottom,
    super.labelOption,
    super.textInputAction,
    super.maxLength,
    super.inputFormatters,
    super.semanticLabel,
    super.autofillHints,
    super.selectionControls,
    super.onFocus,
    super.onBlur,
    super.key,
  }) : super(password: true);
}

class TdsTextArea extends TdsTextField {
  const TdsTextArea({
    required super.variant,
    super.controller,
    super.focusNode,
    super.value,
    super.defaultValue,
    super.onChanged,
    super.onSubmitted,
    super.label,
    super.placeholder,
    super.help,
    super.hasError,
    super.disabled,
    super.readOnly,
    super.autofocus,
    super.format,
    super.paddingTop,
    super.paddingBottom,
    super.labelOption,
    super.keyboardType,
    super.textInputAction,
    super.maxLength,
    super.inputFormatters,
    super.semanticLabel,
    super.minHeight,
    super.height,
    super.autofillHints,
    super.selectionControls,
    super.onFocus,
    super.onBlur,
    super.key,
  }) : super(multiline: true);
}

class TdsTextFieldButton extends StatelessWidget {
  const TdsTextFieldButton({
    required this.variant,
    this.value,
    this.placeholder,
    this.label,
    this.labelOption = TdsTextFieldLabelOption.appear,
    this.help,
    this.hasError = false,
    this.focused = false,
    this.disabled = false,
    this.prefix,
    this.suffix,
    this.right,
    this.onPressed,
    this.format,
    this.paddingTop = 16,
    this.paddingBottom = 16,
    super.key,
  });
  final TdsTextFieldVariant variant;
  final String? value, placeholder, label, prefix, suffix;
  final Widget? help, right;
  final TdsTextFieldLabelOption labelOption;
  final bool hasError, focused, disabled;
  final VoidCallback? onPressed;
  final TdsTextFieldFormat? format;
  final double paddingTop, paddingBottom;
  @override
  Widget build(BuildContext context) {
    final hasValue = value?.isNotEmpty ?? false;
    final text = hasValue
        ? format?.transform(value!) ?? value!
        : placeholder ?? '';
    return TdsTextFieldContainer(
      variant: variant,
      label: label,
      labelOption: labelOption,
      help: help,
      hasValue: hasValue,
      focused: focused,
      hasError: hasError,
      paddingTop: paddingTop,
      paddingBottom: paddingBottom,
      child: TdsPressable(
        enabled: !disabled,
        onPressed: onPressed,
        semanticLabel: label,
        builder: (context, pressed, hovered, focus) => TdsTextFieldSurface(
          variant: variant,
          hasValue: hasValue,
          focused: focused || focus,
          hasError: hasError,
          disabled: disabled,
          prefix: prefix,
          suffix: suffix,
          right:
              right ??
              TdsAssetIcon(
                name: 'icon-arrow-down-mono',
                size: 24,
                color: TdsTheme.of(context).color('grey400'),
              ),
          child: Text(
            text,
            style: hasValue
                ? null
                : TextStyle(color: TdsTheme.of(context).color('grey500')),
          ),
        ),
      ),
    );
  }
}
