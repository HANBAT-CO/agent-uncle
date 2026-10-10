import 'dart:async';
import 'dart:math';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import '../foundation/pressable.dart';
import '../foundation/host.dart';
import '../foundation/layout_adapters.dart';
import '../foundation/secure_keypad_layout.dart';
import '../foundation/line_box.dart';
import 'text.dart';

enum TdsNumberKey {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine;

  int get value => index;
}

@immutable
class TdsAlphabetKey {
  factory TdsAlphabetKey(String value) {
    if (!RegExp(r'^[A-Za-z]$').hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Expected one ASCII letter');
    }
    return TdsAlphabetKey._(value);
  }
  const TdsAlphabetKey._(this.value);
  final String value;
  static final values = List<TdsAlphabetKey>.unmodifiable([
    for (var code = 65; code <= 90; code++) ...[
      TdsAlphabetKey._(String.fromCharCode(code)),
      TdsAlphabetKey._(String.fromCharCode(code + 32)),
    ],
  ]);
  @override
  bool operator ==(Object other) =>
      other is TdsAlphabetKey && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

/// Native keypads delegate capture protection to the injected secure-screen
/// adapter. `secure` is not a promise of OS capture prevention on its own.
class TdsNumberKeypad extends StatelessWidget {
  const TdsNumberKeypad({
    required this.onKeyClick,
    required this.onBackspaceClick,
    this.numbers = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 0],
    this.secure = false,
    this.specialKey,
    this.onSpecialKeyClick,
    super.key,
  });
  final List<int> numbers;
  final bool secure;
  final String? specialKey;
  final ValueChanged<String> onKeyClick;
  final VoidCallback onBackspaceClick;
  final ValueChanged<String>? onSpecialKeyClick;
  factory TdsNumberKeypad.typed({
    required ValueChanged<TdsNumberKey> onKeyClick,
    required VoidCallback onBackspaceClick,
    List<TdsNumberKey>? numbers,
    bool secure = false,
    String? specialKey,
    ValueChanged<String>? onSpecialKeyClick,
    Key? key,
  }) => TdsNumberKeypad(
    numbers: (numbers ?? [...TdsNumberKey.values.skip(1), TdsNumberKey.zero])
        .map((k) => k.value)
        .toList(),
    onKeyClick: (value) => onKeyClick(TdsNumberKey.values[int.parse(value)]),
    onBackspaceClick: onBackspaceClick,
    secure: secure,
    specialKey: specialKey,
    onSpecialKeyClick: onSpecialKeyClick,
    key: key,
  );
  @override
  Widget build(BuildContext context) => _VirtualKeypad(
    characters: numbers.map((n) => '$n').toList(),
    columns: 3,
    secure: secure,
    specialKey: specialKey,
    onKeyClick: onKeyClick,
    onBackspaceClick: onBackspaceClick,
    onSpecialKeyClick: onSpecialKeyClick,
    touchEffect: true,
  );
}

class TdsAlphabetKeypad extends StatelessWidget {
  const TdsAlphabetKeypad({
    required this.onKeyClick,
    required this.onBackspaceClick,
    this.alphabets,
    this.secure = false,
    super.key,
  });
  final List<String>? alphabets;
  final bool secure;
  final ValueChanged<String> onKeyClick;
  final VoidCallback onBackspaceClick;
  factory TdsAlphabetKeypad.typed({
    required ValueChanged<TdsAlphabetKey> onKeyClick,
    required VoidCallback onBackspaceClick,
    List<TdsAlphabetKey>? alphabets,
    bool secure = false,
    Key? key,
  }) => TdsAlphabetKeypad(
    alphabets: alphabets?.map((k) => k.value).toList(),
    onKeyClick: (value) => onKeyClick(TdsAlphabetKey(value)),
    onBackspaceClick: onBackspaceClick,
    secure: secure,
    key: key,
  );
  @override
  Widget build(BuildContext context) => _VirtualKeypad(
    characters:
        alphabets ?? List.generate(26, (i) => String.fromCharCode(65 + i)),
    columns: 7,
    secure: secure,
    onKeyClick: onKeyClick,
    onBackspaceClick: onBackspaceClick,
    touchEffect: false,
  );
}

class _VirtualKeypad extends StatefulWidget {
  const _VirtualKeypad({
    required this.characters,
    required this.columns,
    required this.secure,
    required this.onKeyClick,
    required this.onBackspaceClick,
    required this.touchEffect,
    this.specialKey,
    this.onSpecialKeyClick,
  });
  final List<String> characters;
  final int columns;
  final bool secure, touchEffect;
  final ValueChanged<String> onKeyClick;
  final VoidCallback onBackspaceClick;
  final String? specialKey;
  final ValueChanged<String>? onSpecialKeyClick;
  @override
  State<_VirtualKeypad> createState() => _VirtualKeypadState();
}

class _VirtualKeypadState extends State<_VirtualKeypad> {
  final random = Random.secure();
  Set<int> highlighted = {};
  List<String?> get keys {
    final result = <String?>[...widget.characters];
    final lastCount = result.isEmpty
        ? 0
        : (result.length - 1) % widget.columns + 1;
    final last = result.sublist(result.length - lastCount);
    result.removeRange(result.length - lastCount, result.length);
    final spaces = max(
      0,
      widget.columns - last.length - (widget.specialKey == null ? 1 : 2),
    );
    if (widget.specialKey != null) result.add(widget.specialKey);
    if (widget.specialKey == null) result.addAll(List.filled(spaces, null));
    result.addAll(last);
    if (widget.specialKey != null) result.addAll(List.filled(spaces, null));
    result.add('\b');
    return result;
  }

  void start(int index, List<String?> values) {
    if (!widget.touchEffect) return;
    tdsHapticOf(context).generate(TdsHapticType.softWeak);
    final candidates = [
      for (var i = 0; i < values.length; i++)
        if (values[i] != null && i != index) i,
    ]..shuffle(random);
    setState(
      () => highlighted = {index, if (widget.secure) ...candidates.take(2)},
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = keys;
    final theme = TdsTheme.of(context);
    return TdsSecureScreenScope(
      enabled: widget.secure,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var row = 0;
                  row < (values.length / widget.columns).ceil();
                  row++
                )
                  Row(
                    children: [
                      for (var column = 0; column < widget.columns; column++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final index = row * widget.columns + column;
                              final value = index < values.length
                                  ? values[index]
                                  : null;
                              if (value == null) {
                                return const SizedBox(height: 66);
                              }
                              final active = highlighted.contains(index);
                              return TdsPressable(
                                activateOnPressStart: true,
                                semanticLabel: value == '\b'
                                    ? '지우기'
                                    : value == '.'
                                    ? '마침표'
                                    : value == ','
                                    ? '쉼표'
                                    : value,
                                onPressStart: () => start(index, values),
                                onPressEnd: () =>
                                    setState(() => highlighted = {}),
                                onPressed: () {
                                  if (value == '\b') {
                                    widget.onBackspaceClick();
                                  } else if (value == widget.specialKey &&
                                      widget.onSpecialKeyClick != null) {
                                    widget.onSpecialKeyClick!(value);
                                  } else {
                                    widget.onKeyClick(value);
                                  }
                                },
                                builder: (context, pressed, hovered, focused) =>
                                    ExcludeSemantics(
                                      child: AnimatedScale(
                                        scale: active
                                            ? (widget.secure ? .96 : .85)
                                            : 1,
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        child: Container(
                                          // Source table cells retain 1px UA
                                          // padding above/below the 64px line.
                                          height: 66,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            color: active || focused
                                                ? theme.color('greyOpacity100')
                                                : null,
                                          ),
                                          child: value == '\b'
                                              ? _KeypadBackArrow(
                                                  color: theme.color('grey700'),
                                                )
                                              : TdsText(
                                                  value,
                                                  typography: TdsTypography.t1,
                                                  style: const TextStyle(
                                                    fontSize: 30,
                                                    height: 64 / 30,
                                                  ),
                                                  color: theme.color(
                                                    active
                                                        ? 'grey800'
                                                        : 'grey700',
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadBackArrow extends StatelessWidget {
  const _KeypadBackArrow({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="20" height="20"><path d="m14.9989 7.00018h-11.58998l4.3-4.29c.39212-.39212.39212-1.0279 0-1.42-.39212-.392116-1.0279-.392116-1.42 0l-5.999999 6c-.091041.09511-.16241.20725-.2099997.33-.10002.24346-.10002.51654 0 .76.0458137.12364.1173997.23613.2099997.33l5.999999 6.00002c.18777.1893.44336.2958.71.2958s.52223-.1065.71-.2958c.18931-.1878.2958-.4434.2958-.71 0-.2667-.10649-.5222-.2958-.71l-4.3-4.29002h11.58998c.5523 0 1-.44772 1-1s-.4477-1-1-1z"/></svg>',
    width: 20,
    height: 20,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _SecureBackArrow extends StatelessWidget {
  const _SecureBackArrow();
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="white" fill-rule="evenodd" d="M20.966 10.8H6.93l5.451-5.451a1.2 1.2 0 10-1.697-1.697l-7.5 7.5c-.003.002-.004.006-.007.009a1.2 1.2 0 00-.252 1.298c.06.143.145.27.252.38l.007.01 7.5 7.5c.235.234.542.35.848.35a1.2 1.2 0 00.849-2.048L6.931 13.2h14.036a1.2 1.2 0 100-2.4"/></svg>',
    width: 20,
    height: 20,
    excludeFromSemantics: true,
  );
}

class _SecureShiftArrow extends StatelessWidget {
  const _SecureShiftArrow({required this.filled, required this.disabled});
  final bool filled, disabled;
  static const path =
      'M 10.286 1.761 C 10.68 1.347 11.341 1.347 11.735 1.762 L 19.395 9.82 C 20 10.457 19.548 11.509 18.67 11.509 L 15.579 11.509 L 15.579 19 C 15.579 19.552 15.131 20 14.579 20 L 7.487 20 C 6.935 20 6.487 19.552 6.487 19 L 6.487 11.509 L 3.334 11.509 C 2.455 11.509 2.003 10.456 2.61 9.819 Z';
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" width="21" height="20" viewBox="0 0 21 20">'
    '${filled ? '<path d="$path" fill="white"/>' : '<defs><clipPath id="shift"><path d="$path"/></clipPath></defs><path d="$path" fill="none" stroke="white" stroke-width="3" stroke-miterlimit="10" clip-path="url(#shift)"/>'}'
    '</svg>',
    width: 21,
    height: 20,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(
      disabled ? TdsPalette.grey500 : TdsPalette.white,
      BlendMode.srcIn,
    ),
  );
}

enum TdsSecureKeypadMode { alphabet, capitalized, special }

class TdsSecureKeypadController extends ChangeNotifier {
  void reorderEmptyCells() => notifyListeners();
}

class TdsFullSecureKeypad extends StatefulWidget {
  const TdsFullSecureKeypad({
    required this.onKeyClick,
    required this.onBackspaceClick,
    required this.onSpaceClick,
    required this.onSubmit,
    this.submitDisabled = false,
    this.submitButtonText = '입력 완료',
    this.open = true,
    this.controller,
    super.key,
  });
  final ValueChanged<String> onKeyClick;
  final VoidCallback onBackspaceClick, onSpaceClick, onSubmit;
  final bool submitDisabled, open;
  final String submitButtonText;
  final TdsSecureKeypadController? controller;
  @override
  State<TdsFullSecureKeypad> createState() => _TdsFullSecureKeypadState();
}

class _TdsFullSecureKeypadState extends State<TdsFullSecureKeypad> {
  TdsSecureKeypadMode mode = TdsSecureKeypadMode.alphabet;
  final random = Random.secure();
  late List<List<int?>> alphabetLayout, specialLayout;
  static const alphabet = [
    '1234567890',
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm\b',
  ];
  static const subtext = ['', 'ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ', 'ㅁㄴㅇㄹㅎㅗㅓㅏㅣ', 'ㅋㅌㅊㅍㅠㅜㅡ'];
  static const special = [r'!@#$%^&*()', r"`-=\[];',", './~+|{}:', '₩_"<>?\b'];
  void reorder() {
    alphabetLayout = [
      for (final row in alphabet) secureKeypadRow(row.length, 1, random),
    ];
    specialLayout = [
      for (var i = 0; i < special.length; i++)
        secureKeypadRow(special[i].length, i == 0 ? 1 : 2, random),
    ];
    // Source imperative ref mutates the cached templates without scheduling a
    // render. The next mode change or owner rebuild applies the new layout.
  }

  @override
  void initState() {
    super.initState();
    reorder();
    widget.controller?.addListener(reorder);
  }

  @override
  void didUpdateWidget(TdsFullSecureKeypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(reorder);
      widget.controller?.addListener(reorder);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(reorder);
    super.dispose();
  }

  Widget keyButton(
    String label,
    VoidCallback action, {
    bool disabled = false,
    int flex = 1,
    Color? color,
    Widget? content,
    bool? selected,
    bool control = false,
  }) => Expanded(
    flex: flex,
    child: Semantics(
      selected: selected,
      child: TdsPressable(
        enabled: !disabled,
        activateOnPressStart: true,
        semanticLabel: label,
        onPressed: action,
        builder: (context, pressed, hovered, focused) => Container(
          alignment: Alignment.center,
          height: double.infinity,
          decoration: BoxDecoration(
            color: color ?? (control ? const Color(0xff283447) : null),
          ),
          // CSS inset shadow does not consume layout space, unlike a border.
          foregroundDecoration: control && color == null
              ? BoxDecoration(
                  border: Border.all(color: const Color(0x29000021)),
                )
              : null,
          child: ExcludeSemantics(
            child: content ?? _SecureKeyText(label, fontSize: 17),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox();
    final rows = mode == TdsSecureKeypadMode.special ? special : alphabet;
    final layout = mode == TdsSecureKeypadMode.special
        ? specialLayout
        : alphabetLayout;
    return TdsSecureScreenScope(
      enabled: true,
      child: Stack(
        children: [
          ColoredBox(
            color: const Color(0xff283447),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: Column(
                    children: [
                      for (var row = 0; row < rows.length; row++)
                        SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              for (final index in layout[row])
                                if (index == null)
                                  const Expanded(child: SizedBox())
                                else
                                  Builder(
                                    builder: (context) {
                                      final raw = rows[row][index],
                                          value =
                                              mode ==
                                                  TdsSecureKeypadMode
                                                      .capitalized
                                              ? raw.toUpperCase()
                                              : raw;
                                      final korean =
                                          mode != TdsSecureKeypadMode.special &&
                                              index < subtext[row].length
                                          ? subtext[row][index]
                                          : null;
                                      return keyButton(
                                        value == '\b' ? '지우기' : value,
                                        () => value == '\b'
                                            ? widget.onBackspaceClick()
                                            : widget.onKeyClick(value),
                                        flex: value == '\b' ? 2 : 1,
                                        content: value == '\b'
                                            ? const _SecureBackArrow()
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  _SecureKeyText(
                                                    value,
                                                    fontSize: 20,
                                                    boxHeight: 25,
                                                  ),
                                                  if (korean != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 2,
                                                          ),
                                                      child: _SecureKeyText(
                                                        korean,
                                                        fontSize: 13,
                                                        boxHeight: 16,
                                                        color: const Color(
                                                          0xff93939f,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      keyButton(
                        'shift',
                        () => setState(
                          () => mode = mode == TdsSecureKeypadMode.alphabet
                              ? TdsSecureKeypadMode.capitalized
                              : TdsSecureKeypadMode.alphabet,
                        ),
                        disabled: mode == TdsSecureKeypadMode.special,
                        selected: mode == TdsSecureKeypadMode.capitalized,
                        flex: 2,
                        control: true,
                        content: _SecureShiftArrow(
                          filled: mode == TdsSecureKeypadMode.capitalized,
                          disabled: mode == TdsSecureKeypadMode.special,
                        ),
                      ),
                      keyButton(
                        mode == TdsSecureKeypadMode.special
                            ? '영문으로 전환'
                            : '특수로 전환',
                        () => setState(
                          () => mode = mode == TdsSecureKeypadMode.special
                              ? TdsSecureKeypadMode.alphabet
                              : TdsSecureKeypadMode.special,
                        ),
                        content: _SecureKeyText(
                          mode == TdsSecureKeypadMode.special ? '영문' : '특수',
                          fontSize: 17,
                        ),
                        flex: 2,
                        control: true,
                      ),
                      keyButton(
                        'space',
                        widget.onSpaceClick,
                        flex: 5,
                        control: true,
                        content: const _SecureKeyText('Space', fontSize: 17),
                      ),
                      keyButton(
                        widget.submitButtonText,
                        widget.onSubmit,
                        flex: 5,
                        control: true,
                        disabled: widget.submitDisabled,
                        color: widget.submitDisabled
                            ? TdsPalette.blue100
                            : TdsPalette.blue500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: 0, left: 0, child: _SecureKeypadAnnouncement()),
        ],
      ),
    );
  }
}

/// Source spans have a fixed box height but retain the inherited 1.5em line
/// height. Text overflows below that box; it must not be vertically compressed.
class _SecureKeyText extends StatelessWidget {
  const _SecureKeyText(
    this.text, {
    required this.fontSize,
    this.boxHeight,
    this.color = TdsPalette.white,
  });
  final String text;
  final double fontSize;
  final double? boxHeight;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final line = TdsLineBox(
      lineHeight: fontSize * 1.5,
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
    );
    if (boxHeight == null) return line;
    return SizedBox(
      height: boxHeight,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        fit: OverflowBoxFit.deferToChild,
        minHeight: 0,
        maxHeight: double.infinity,
        child: line,
      ),
    );
  }
}

class _SecureKeypadAnnouncement extends StatefulWidget {
  const _SecureKeypadAnnouncement();
  @override
  State<_SecureKeypadAnnouncement> createState() =>
      _SecureKeypadAnnouncementState();
}

class _SecureKeypadAnnouncementState extends State<_SecureKeypadAnnouncement> {
  bool visible = false;
  late final Timer show, hide;
  @override
  void initState() {
    super.initState();
    show = Timer(
      const Duration(milliseconds: 200),
      () => setState(() => visible = true),
    );
    hide = Timer(
      const Duration(seconds: 1),
      () => setState(() => visible = false),
    );
  }

  @override
  void dispose() {
    show.cancel();
    hide.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: visible,
    label: visible ? '보안 키패드가 화면에 표시됐어요.' : null,
    child: const SizedBox(width: 1, height: 1),
  );
}
