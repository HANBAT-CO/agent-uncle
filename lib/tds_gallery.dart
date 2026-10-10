import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

/// Local comparison fixture. Run with flutter run -t lib/tds_gallery.dart.
void main() => runApp(const TdsGalleryApp());

class TdsGalleryApp extends StatelessWidget {
  const TdsGalleryApp({super.key});
  @override
  Widget build(BuildContext context) {
    final parameters = Uri.base.queryParameters;
    final theme = TdsThemeData(
      colorScheme: parameters['theme'] == 'dark'
          ? TdsColorPreference.dark
          : TdsColorPreference.light,
      platform: TdsPlatform(
        os: parameters['os'] == 'ios' ? TdsOS.ios : TdsOS.android,
        fontScale: double.tryParse(parameters['scale'] ?? '') ?? 100,
      ),
    );
    final state = parameters['state'] ?? 'initial';
    final family = parameters['family'] ?? 'buttons';
    final child = family == 'checkbox' || family == 'switch'
        ? TdsCheckableReferenceFixture(
            family: family,
            state: state,
            checked: parameters['checked'] == 'true',
          )
        : family == 'full-tooltip'
        ? TdsFullTooltipReferenceFixture(state: state)
        : family == 'visual-typography'
        ? TdsVisualTypographyFixture(
            weight: TdsFontWeight.values.firstWhere(
              (weight) => weight.name == parameters['weight'],
              orElse: () => TdsFontWeight.regular,
            ),
            multiline: state == 'multiline',
          )
        : family == 'visual-footer'
        ? TdsVisualFooterFixture(
            variant: parameters['variant'] ?? 'default',
            width: double.tryParse(parameters['width'] ?? '') ?? 342,
          )
        : family == 'highlight'
        ? const TdsHighlightReferenceFixture()
        : family == 'text-buttons'
        ? TdsTextButtonReferenceFixture(state: state)
        : family == 'sheet-select'
        ? const TdsSheetSelectReferenceFixture()
        : family == 'sheet'
        ? TdsSheetReferenceFixture(state: state)
        : family == 'slider-tooltip'
        ? const SizedBox(
            width: 390,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 124, 24, 24),
              child: TdsSlider(
                defaultValue: 25,
                tooltip: TdsSliderTooltip(),
                label: TdsSliderLabel(min: '0', mid: '50', max: '100'),
              ),
            ),
          )
        : family == 'wiki-viewport'
        ? SizedBox(
            width: 390,
            height: 2048,
            child: Stack(
              children: [
                Positioned(
                  top: 24 + (double.tryParse(parameters['y'] ?? '') ?? 320),
                  left: 24,
                  width: 230,
                  child: DefaultTextStyle(
                    style: theme.textStyle(typography: TdsTypography.t5),
                    child: TdsWikiText(
                      '금융 용어',
                      hasPaddingAnimation: parameters['padding'] != 'false',
                      description: '첫 번째 줄의 설명이에요.\n두 번째 줄의 설명도 확인해요.',
                    ),
                  ),
                ),
              ],
            ),
          )
        : family == 'wiki'
        ? SizedBox(
            width: 390,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 230,
                  child: DefaultTextStyle(
                    style: theme.textStyle(typography: TdsTypography.t5),
                    child: TdsWikiText(
                      state == 'multiline'
                          ? '여러 줄로 이어지는 아주 긴 금융 용어의 뜻을 확인해요'
                          : '금융 용어',
                      description: const Text('이 단어의 자세한 설명을 확인해요.'),
                    ),
                  ),
                ),
              ),
            ),
          )
        : family == 'tooltips'
        ? const TdsTooltipReferenceFixture()
        : family == 'menus'
        ? const TdsMenuReferenceFixture()
        : family == 'paragraphs'
        ? const TdsParagraphReferenceFixture()
        : family == 'bottom-cta'
        ? TdsBottomCTAReferenceFixture(state: state)
        : family == 'list-assets'
        ? const TdsListAssetReferenceFixture()
        : family == 'list-effects'
        ? const TdsListEffectsReferenceFixture()
        : family == 'list-footer-colors'
        ? const TdsListFooterColorsReferenceFixture()
        : family == 'list-footer-contexts'
        ? const TdsListFooterContextsReferenceFixture()
        : family == 'list-footer-undefined' || family == 'list-footer-nested'
        ? TdsListFooterEdgesReferenceFixture(
            nested: family == 'list-footer-nested',
          )
        : family == 'compounds'
        ? const TdsCompoundsReferenceFixture()
        : family == 'keypad'
        ? TdsNumberKeypad(onKeyClick: (_) {}, onBackspaceClick: () {})
        : family == 'secure-keypad'
        ? TdsFullSecureKeypad(
            onKeyClick: (_) {},
            onBackspaceClick: () {},
            onSpaceClick: () {},
            onSubmit: () {},
            submitDisabled: state == 'disabled',
          )
        : family == 'lists'
        ? TdsListReferenceFixture(state: state)
        : family == 'toast'
        ? TdsToastReferenceFixture(state: state)
        : family == 'fields'
        ? TdsFieldReferenceFixture(state: state)
        : family == 'extended-controls'
        ? const TdsExtendedControlsFixture()
        : TdsButtonReferenceFixture(
            size: TdsButtonSize.values.firstWhere(
              (s) => s.name == parameters['size'],
              orElse: () => TdsButtonSize.xlarge,
            ),
            disabled: state.contains('disabled'),
            loading: state.contains('loading'),
          );
    return WidgetsApp(
      color: TdsPalette.background,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, a, s) => builder(context),
      ),
      builder: (context, navigator) =>
          TdsMobileProvider(theme: theme, child: navigator!),
      home: ColoredBox(
        color: theme.color('background'),
        child: SingleChildScrollView(
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }
}

/// Same block flow as VisualTypographyFixture in the original-source harness.
class TdsVisualTypographyFixture extends StatelessWidget {
  const TdsVisualTypographyFixture({
    this.weight = TdsFontWeight.regular,
    this.multiline = false,
    super.key,
  });
  final TdsFontWeight weight;
  final bool multiline;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in [
            TdsTypography.t7,
            TdsTypography.t5,
            TdsTypography.t2,
            TdsTypography.t1,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TdsText(
                multiline ? '토스 Ag 012\n둘째 줄 xyz' : '토스 Ag 012',
                key: ValueKey('type-${type.name}'),
                typography: type,
                fontWeight: weight,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Direct flex slots, a wrapping label and a non-animated gradient specimen.
class TdsVisualFooterFixture extends StatelessWidget {
  const TdsVisualFooterFixture({
    this.variant = 'default',
    this.width = 342,
    super.key,
  });
  final String variant;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: SizedBox(
      width: width,
      child: TdsListFooter(
        key: const ValueKey('visual-footer'),
        onPressed: () {},
        iconName: variant == 'shadow' ? null : 'icon-arrow-right-mono',
        shadow: variant == 'shadow'
            ? const TdsListFooterShadow(visible: true)
            : null,
        child: variant == 'shadow'
            ? const SizedBox(height: 120, width: double.infinity)
            : Text(
                variant == 'multiline'
                    ? '글자와 화살표의 위치를 확인하고 다음 안내를 읽어요'
                    : '더 보기 Ag',
              ),
      ),
    ),
  );
}

class TdsListEffectsReferenceFixture extends StatefulWidget {
  const TdsListEffectsReferenceFixture({super.key});
  @override
  State<TdsListEffectsReferenceFixture> createState() =>
      _TdsListEffectsReferenceFixtureState();
}

class _TdsListEffectsReferenceFixtureState
    extends State<TdsListEffectsReferenceFixture> {
  final controller = TdsListRowController();
  bool resized = false;
  bool? dark;
  String inputMode = 'none';
  int clicks = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inherited = TdsTheme.of(context);
    final isDark = dark ?? inherited.isDark;
    final theme = TdsThemeData(
      colorScheme: isDark ? TdsColorPreference.dark : TdsColorPreference.light,
      platform: inherited.platform,
    );
    return TdsMobileProvider(
      theme: theme,
      child: ColoredBox(
        color: theme.color('background'),
        child: SizedBox(
          width: 390,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: resized ? 240.6 : 320.4,
                  child: Listener(
                    onPointerDown: (_) {
                      if (inputMode == 'ancestor') controller.shine();
                    },
                    onPointerUp: (_) {
                      if (inputMode == 'ancestor') controller.shine();
                    },
                    child: TdsListRow(
                      controller: controller,
                      border: TdsListRowBorder.indented,
                      onPressed: inputMode == 'none'
                          ? null
                          : () {
                              setState(() => clicks++);
                              if (inputMode == 'click') controller.blink();
                            },
                      contents: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {
                          if (inputMode == 'child') controller.shine();
                        },
                        child: SizedBox(
                          height: resized ? 120.2 : 80.4,
                          child: const TdsListRowTexts(
                            type: TdsListRowTextType.row2TypeA,
                            top: Text('토스뱅크'),
                            bottom: Text('입출금 통장'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: controller.shine,
                  child: const Text('빛 효과'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => controller.shine(playCount: 2),
                  child: const Text('두 번 재생 요청'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => resized = !resized),
                  child: const Text('크기 변경'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => dark = !isDark),
                  child: const Text('테마 변경'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: controller.blink,
                  child: const Text('깜빡임'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => controller.blink(
                    duration: const Duration(milliseconds: 100),
                  ),
                  child: const Text('짧게 깜빡임'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () {
                    controller.shine();
                    controller.blink();
                  },
                  child: const Text('빛 효과 → 깜빡임'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () {
                    controller.blink();
                    controller.shine();
                  },
                  child: const Text('깜빡임 → 빛 효과'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () {
                    controller.shine();
                    controller.shine(playCount: 3);
                  },
                  child: const Text('빛 효과 1 → 3회'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () async {
                    controller.shine();
                    await Future<void>.value();
                    if (mounted) controller.blink();
                  },
                  child: const Text('비동기 빛 → 깜빡임'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () async {
                    controller.blink();
                    await Future<void>.value();
                    if (mounted) controller.shine();
                  },
                  child: const Text('비동기 깜빡임 → 빛'),
                ),
                for (final mode in ['child', 'ancestor', 'click'])
                  TdsTextButton(
                    size: TdsTextButtonSize.medium,
                    onPressed: () => setState(() => inputMode = mode),
                    child: Text(switch (mode) {
                      'child' => '하위 입력',
                      'ancestor' => '상위 입력',
                      _ => '클릭 후 깜빡임',
                    }),
                  ),
                TdsText('클릭 $clicks', typography: TdsTypography.t7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TdsListFooterColorsReferenceFixture extends StatefulWidget {
  const TdsListFooterColorsReferenceFixture({super.key});
  @override
  State<TdsListFooterColorsReferenceFixture> createState() =>
      _TdsListFooterColorsReferenceFixtureState();
}

class _TdsListFooterColorsReferenceFixtureState
    extends State<TdsListFooterColorsReferenceFixture> {
  bool? dark;
  bool explicitLast = true, showExplicit = true, green = false;
  int generation = 0, clicks = 0;

  @override
  Widget build(BuildContext context) {
    final inherited = TdsTheme.of(context);
    final isDark = dark ?? inherited.isDark;
    final theme = TdsThemeData(
      colorScheme: isDark ? TdsColorPreference.dark : TdsColorPreference.light,
      platform: inherited.platform,
    );
    final adaptive = Uri.base.queryParameters['adaptive'] == 'true';
    final children = <Widget>[
      const TdsListFooterText(key: ValueKey('inherit'), child: Text('상속')),
      if (showExplicit)
        Padding(
          key: const ValueKey('custom-wrapper'),
          padding: EdgeInsets.zero,
          child: TdsListFooterText(
            color: adaptive
                ? null
                : green
                ? TdsPalette.green500
                : TdsPalette.red500,
            colorToken: adaptive ? (green ? 'green500' : 'red500') : null,
            child: const Text('명시'),
          ),
        ),
    ];
    return TdsMobileProvider(
      theme: theme,
      child: ColoredBox(
        color: theme.color('background'),
        child: SizedBox(
          width: 390,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TdsListFooter(
                  key: ValueKey(generation),
                  onPressed: () => setState(() => clicks++),
                  icon: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TdsListFooterIcon(name: 'icon-arrow-right-mono'),
                      TdsListFooterIcon(
                        name: 'icon-arrow-right-mono',
                        color: TdsPalette.blue500,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: explicitLast
                        ? children
                        : children.reversed.toList(),
                  ),
                ),
                const SizedBox(height: 24),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => green = !green),
                  child: const Text('색상 변경'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => dark = !isDark),
                  child: const Text('테마 변경'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => showExplicit = !showExplicit),
                  child: const Text('명시 색상 전환'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() {
                    explicitLast = !explicitLast;
                    generation++;
                  }),
                  child: const Text('등록 순서 변경'),
                ),
                TdsTextButton(
                  size: TdsTextButtonSize.medium,
                  onPressed: () => setState(() => generation++),
                  child: const Text('초기화'),
                ),
                TdsText('클릭 $clicks', typography: TdsTypography.t7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Independent press/release context changes, paired with the original
/// list-footer-colors fixture through its updateFooter API.
class TdsListFooterContextsReferenceFixture extends StatefulWidget {
  const TdsListFooterContextsReferenceFixture({super.key});
  @override
  State<TdsListFooterContextsReferenceFixture> createState() =>
      _TdsListFooterContextsReferenceFixtureState();
}

class _TdsListFooterContextsReferenceFixtureState
    extends State<TdsListFooterContextsReferenceFixture> {
  String textToken = 'grey200';
  bool lateText = false;
  int generation = 0, clicks = 0;

  void reset(String token) => setState(() {
    textToken = token;
    lateText = false;
    generation++;
    clicks = 0;
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TdsListFooter(
            key: ValueKey(generation),
            onPressed: () => setState(() => clicks++),
            icon: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TdsListFooterIcon(name: 'icon-arrow-right-mono'),
                TdsListFooterIcon(
                  name: 'icon-arrow-right-mono',
                  colorToken: 'green500',
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TdsListFooterText(child: Text('상속')),
                TdsListFooterText(
                  colorToken: textToken,
                  child: const Text('명시'),
                ),
                if (lateText)
                  TdsListFooterText(
                    colorToken: textToken,
                    child: const Text('추가'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => setState(() => textToken = 'hairlineBorder'),
            child: const Text('누름 설정만 변경'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => setState(() => textToken = 'blue500'),
            child: const Text('두 설정 변경'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => setState(() {
              textToken = 'grey200';
              lateText = true;
            }),
            child: const Text('하위 텍스트 추가'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => reset('hairlineBorder'),
            child: const Text('선 색상으로 초기화'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => reset('grey200'),
            child: const Text('기본 초기화'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => reset('greyBackground'),
            child: const Text('별칭 초기화'),
          ),
          TdsTextButton(
            size: TdsTextButtonSize.medium,
            onPressed: () => setState(() => textToken = 'backgroundLevelB01'),
            child: const Text('동일 색상 별칭'),
          ),
          TdsText('클릭 $clicks', typography: TdsTypography.t7),
        ],
      ),
    ),
  );
}

/// Original from-only color and nested selector cases. This native fixture is
/// also used by Android/iOS integration tests, not just CanvasKit captures.
class TdsListFooterEdgesReferenceFixture extends StatefulWidget {
  const TdsListFooterEdgesReferenceFixture({required this.nested, super.key});
  final bool nested;
  @override
  State<TdsListFooterEdgesReferenceFixture> createState() =>
      _TdsListFooterEdgesReferenceFixtureState();
}

class _TdsListFooterEdgesReferenceFixtureState
    extends State<TdsListFooterEdgesReferenceFixture> {
  String outer = 'blue500', inner = 'red500';
  String textToken = 'disabledBlue500', iconToken = 'disabledBlue500';
  bool showInner = true;
  int generation = 0;
  final events = <String>[];

  void clicked(String name) => setState(() => events.add(name));
  Widget icon(String id, [String? token]) => TdsListFooterIcon(
    key: ValueKey(id),
    name: 'icon-arrow-right-mono',
    colorToken: token,
  );
  Widget control(String label, VoidCallback action) => TdsTextButton(
    size: TdsTextButtonSize.medium,
    onPressed: () => setState(action),
    child: Text(label),
  );
  void reset() {
    outer = 'blue500';
    inner = 'red500';
    showInner = true;
    textToken = iconToken = 'disabledBlue500';
    generation++;
    events.clear();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: ValueKey(generation),
            child: widget.nested
                ? TdsListFooter(
                    key: const ValueKey('outer-footer'),
                    onPressed: () => clicked('바깥'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TdsListFooterText(
                              colorToken: outer,
                              child: const Text('바깥'),
                            ),
                            icon('outer-icon', 'green500'),
                          ],
                        ),
                        if (showInner)
                          TdsListFooter(
                            key: const ValueKey('inner-footer'),
                            onPressed: () => clicked('안쪽'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TdsListFooterText(
                                  colorToken: inner,
                                  child: const Text('안쪽'),
                                ),
                                icon('inner-icon', 'orange500'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                : TdsListFooter(
                    key: const ValueKey('undefined-footer'),
                    onPressed: () => clicked('footer'),
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon('inherit-icon'),
                        icon('different-icon', 'red500'),
                        icon('last-icon', iconToken),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TdsListFooterText(child: Text('상속')),
                        const TdsListFooterText(
                          colorToken: 'red500',
                          child: Text('명시'),
                        ),
                        TdsListFooterText(
                          colorToken: textToken,
                          child: const Text('마지막'),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          if (widget.nested) ...[
            control('안쪽 숨기기', () => showInner = false),
            control('안쪽 복원', () => showInner = true),
            control('바깥 색상 변경', () => outer = 'teal500'),
            control('안쪽 색상 변경', () => inner = 'purple500'),
          ] else ...[
            control('색상 변경', () {
              textToken = 'blue500';
              iconToken = 'green500';
            }),
            control('색상 복원', () => textToken = iconToken = 'disabledBlue500'),
          ],
          control('초기화', reset),
          TdsText(
            widget.nested ? '순서 ${events.join(' → ')}' : '클릭 ${events.length}',
            typography: TdsTypography.t7,
          ),
        ],
      ),
    ),
  );
}

class TdsFullTooltipReferenceFixture extends StatelessWidget {
  const TdsFullTooltipReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) {
    final p = Uri.base.queryParameters;
    return SizedBox(
      width: 390,
      child: Padding(
        padding: const EdgeInsets.only(top: 124),
        child: TdsFullTooltip(
          open: true,
          floating: p['floating'] == 'true',
          placement: switch (p['side']) {
            'top' => TdsOverlayPlacement.top,
            'bottom' => TdsOverlayPlacement.bottom,
            _ => null,
          },
          anchorOverlapped: p['overlap'] == 'true',
          anchorPositionByRatio: double.tryParse(p['ratio'] ?? ''),
          offset: double.tryParse(p['offset'] ?? ''),
          messageAlign: switch (p['align']) {
            'left' => TextAlign.left,
            'right' => TextAlign.right,
            _ => TextAlign.center,
          },
          message: Text(
            state == 'resized'
                ? '첫 번째 안내\n두 번째 안내\n세 번째 안내'
                : state == 'multiline'
                ? '새로운 기능을 확인하고\n안내를 계속 읽어 보세요'
                : '새로운 기능을 확인해 보세요',
          ),
          child: const SizedBox(
            height: 48,
            child: ColoredBox(
              color: TdsPalette.grey100,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  '대상',
                  style: TextStyle(
                    fontFamily: 'Toss Product Sans',
                    package: 'tds_mobile_flutter',
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xff212529),
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TdsHighlightReferenceFixture extends StatelessWidget {
  const TdsHighlightReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Uri.base.queryParameters;
    return SizedBox(
      width: 390,
      height: MediaQuery.sizeOf(context).height,
      child: TdsHighlightUI(
        rect: Rect.fromLTWH(
          double.tryParse(p['x'] ?? '') ?? 40,
          double.tryParse(p['y'] ?? '') ?? 160,
          160,
          48,
        ),
        padding: double.tryParse(p['padding'] ?? '') ?? 8,
        message: const Text('여기에서 새로운 기능을\n확인할 수 있어요'),
        messageXAlignment: switch (p['align']) {
          'left' => TdsHighlightXAlignment.left,
          'center' => TdsHighlightXAlignment.center,
          'right' => TdsHighlightXAlignment.right,
          _ => null,
        },
        messageYAlignment: switch (p['side']) {
          'top' => TdsHighlightYAlignment.top,
          'bottom' => TdsHighlightYAlignment.bottom,
          _ => null,
        },
      ),
    );
  }
}

class TdsTextButtonReferenceFixture extends StatelessWidget {
  const TdsTextButtonReferenceFixture({required this.state, super.key});
  final String state;

  @override
  Widget build(BuildContext context) {
    final parameters = Uri.base.queryParameters;
    final hex = parameters['color']?.replaceFirst('#', '');
    final color = hex != null ? int.tryParse(hex, radix: 16) : null;
    return SizedBox(
      width: 390,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final size in TdsTextButtonSize.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: state == 'multiline' ? 130 : null,
                  child: TdsTextButton(
                    size: size,
                    variant: TdsTextButtonVariant.values.firstWhere(
                      (value) => value.name == parameters['variant'],
                      orElse: () => TdsTextButtonVariant.arrow,
                    ),
                    arrowPlacement: parameters['placement'] == 'inline'
                        ? TdsArrowPlacement.inline
                        : TdsArrowPlacement.block,
                    disabled: state == 'disabled',
                    color: color == null ? null : Color(0xff000000 | color),
                    onPressed: () {},
                    child: Text(state == 'multiline' ? '자세한 내용을 확인하기' : '확인하기'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TdsCheckableReferenceFixture extends StatefulWidget {
  const TdsCheckableReferenceFixture({
    required this.family,
    required this.state,
    required this.checked,
    super.key,
  });
  final String family, state;
  final bool checked;
  @override
  State<TdsCheckableReferenceFixture> createState() =>
      _TdsCheckableReferenceFixtureState();
}

class _TdsCheckableReferenceFixtureState
    extends State<TdsCheckableReferenceFixture> {
  late bool _checked = widget.checked;
  void _change(bool value) {
    if (widget.state != 'reject') setState(() => _checked = value);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        // React fixture's plain strings inherit body 16px/24px, independently
        // of TDS token scaling. No component typography is overridden here.
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Color(0xff212529),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.family == 'switch')
              TdsSwitch(
                checked: _checked,
                disabled: widget.state == 'disabled',
                inert: widget.state == 'inert',
                hasTouchEffect: widget.state != 'no-effect',
                onChanged: _change,
              ),
            if (widget.family == 'checkbox')
              for (final variant in TdsCheckboxVariant.values)
                Padding(
                  // The original inline-block label has a bottom-edge baseline.
                  // Its parent div adds 6px of 16px/24px body-strut descent.
                  padding: const EdgeInsets.only(bottom: 24 + 6),
                  child: TdsCheckbox(
                    variant: variant,
                    checked: _checked,
                    disabled: widget.state == 'disabled',
                    inert: widget.state == 'inert',
                    inputType: widget.state == 'radio'
                        ? TdsCheckboxInputType.radio
                        : TdsCheckboxInputType.checkbox,
                    onChanged: _change,
                    child: const Text('동의하기'),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class TdsSheetSelectReferenceFixture extends StatefulWidget {
  const TdsSheetSelectReferenceFixture({super.key});
  @override
  State<TdsSheetSelectReferenceFixture> createState() =>
      _TdsSheetSelectReferenceFixtureState();
}

class _TdsSheetSelectReferenceFixtureState
    extends State<TdsSheetSelectReferenceFixture> {
  String _value = 'a';
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TdsBottomSheetHeader('계좌를 선택해요'),
        const TdsBottomSheetHeaderDescription('사용할 계좌를 선택해 주세요.'),
        TdsBottomSheetSelect(
          value: _value,
          animation: Uri.base.queryParameters['state'] != 'static',
          animationDelay: Uri.base.queryParameters['state'] == 'delayed'
              ? const Duration(milliseconds: 500)
              : Duration.zero,
          onChange: (value) => setState(() => _value = value),
          options: const [
            TdsBottomSheetSelectOption(name: '토스뱅크', value: 'a'),
            TdsBottomSheetSelectOption(name: '다른 계좌', value: 'b'),
            TdsBottomSheetSelectOption(
              name: '사용할 수 없는 계좌',
              value: 'c',
              disabled: true,
            ),
            TdsBottomSheetSelectOption(
              name: '체크 표시를 숨긴 계좌',
              value: 'd',
              hideUncheckedCheckbox: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class TdsSheetReferenceFixture extends StatelessWidget {
  const TdsSheetReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) => TdsBottomSheet(
    open: true,
    onClose: () {},
    header: const TdsBottomSheetHeader('계좌를 선택해요'),
    headerDescription: const TdsBottomSheetHeaderDescription(
      '사용할 계좌를 선택해 주세요.',
    ),
    cta: state == 'no-cta'
        ? null
        : TdsBottomSheetCTA(
            background: state == 'none'
                ? false
                : state == 'background'
                ? true
                : null,
            child: const Text('확인'),
          ),
    child: TdsBottomSheetSelect(
      animation: false,
      value: 'a',
      onChange: (_) {},
      options: List.generate(
        state == 'long' ? 14 : 3,
        (i) => TdsBottomSheetSelectOption(
          name: '계좌 ${i + 1}',
          value: i == 0 ? 'a' : '$i',
        ),
      ),
    ),
  );
}

class TdsTooltipReferenceFixture extends StatelessWidget {
  const TdsTooltipReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          for (final size in TdsTooltipSize.values)
            for (final placement in [
              TdsOverlayPlacement.top,
              TdsOverlayPlacement.bottom,
            ])
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    for (final clip in TdsTooltipClip.values)
                      Expanded(
                        child: Center(
                          child: TdsTooltip(
                            open: true,
                            size: size,
                            placement: placement,
                            clipToEnd: clip,
                            anchorPositionByRatio: clip == TdsTooltipClip.none
                                ? .5
                                : clip == TdsTooltipClip.left
                                ? 0
                                : 1,
                            message: const Text('도움말'),
                            child: const SizedBox(width: 80, height: 20),
                          ),
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

class TdsMenuReferenceFixture extends StatelessWidget {
  const TdsMenuReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TdsMenuDropdown(
            header: const TdsMenuHeader('계좌 관리'),
            children: [
              TdsMenuDropdownItem(
                onPressed: () {},
                child: const Text('내 계좌 확인'),
              ),
              TdsMenuDropdownItem(
                left: const TdsMenuDropdownIcon(name: 'icn-delete'),
                onPressed: () {},
                child: const Text('계좌 삭제'),
              ),
              TdsMenuDropdownItem(
                right: const TdsMenuDropdownIcon(name: 'icon-arrow-right-mono'),
                onPressed: () {},
                child: const Text('자세히 보기'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const TdsMenuDropdown(
            header: TdsMenuHeader('표시 설정'),
            children: [
              TdsMenuDropdownCheckItem(checked: true, child: Text('선택한 계좌')),
              TdsMenuDropdownCheckItem(child: Text('모든 계좌')),
            ],
          ),
        ],
      ),
    ),
  );
}

class TdsParagraphReferenceFixture extends StatelessWidget {
  const TdsParagraphReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final size in [13, 15, 17]) ...[
            TdsTopSubtitleParagraph.rich(
              size: size,
              children: [
                const TdsParagraphText(text: '내 자산 '),
                const WidgetSpan(
                  child: TdsParagraphIcon(name: 'icon-arrow-right-mono'),
                ),
                const TdsParagraphText(text: ' '),
                const WidgetSpan(
                  child: TdsParagraphBadge(
                    color: TdsBadgeColor.blue,
                    variant: TdsBadgeVariant.weak,
                    child: Text('새 소식'),
                  ),
                ),
                const TdsParagraphText(text: ' '),
                WidgetSpan(
                  child: TdsParagraphLink(text: '자세히 보기', onPressed: () {}),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          for (final size in TdsBadgeSize.values) ...[
            TdsBadge(
              size: size,
              color: TdsBadgeColor.blue,
              variant: TdsBadgeVariant.weak,
              child: const Text('배지 크기'),
            ),
            const SizedBox(height: 16),
          ],
          const TdsParagraph(
            typography: TdsTypography.t5,
            children: [
              TdsParagraphText(
                text: '여러 줄에 걸쳐서 이어지는 문장과 ',
                children: [
                  TdsParagraphText(
                    text: '조금 더 크게 강조하는 구간',
                    typography: TdsTypography.t3,
                    fontWeight: TdsFontWeight.bold,
                  ),
                ],
              ),
              TdsParagraphText(text: '도 같은 문단 안에서 자연스럽게 흘러가야 해요.'),
            ],
          ),
        ],
      ),
    ),
  );
}

class TdsBottomCTAReferenceFixture extends StatelessWidget {
  const TdsBottomCTAReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Column(
      children: [
        TdsBottomCTA.single(
          disabled: state == 'disabled',
          topAccessory: const Text('안전하게 보관해요'),
          bottomAccessory: const Text('언제든 변경할 수 있어요'),
          child: const Text('확인'),
        ),
        const SizedBox(height: 16),
        const TdsBottomCTA.double(
          background: false,
          leftButton: TdsButton(
            color: TdsButtonColor.dark,
            variant: TdsButtonVariant.weak,
            child: Text('나중에'),
          ),
          rightButton: TdsButton(child: Text('확인하기')),
        ),
        const SizedBox(height: 16),
        const TdsBottomCTA.double(
          leftButton: TdsButton(
            color: TdsButtonColor.dark,
            variant: TdsButtonVariant.weak,
            child: Text('다음에 다시 확인할게요'),
          ),
          rightButton: TdsButton(child: Text('지금 바로 확인할게요')),
        ),
        const TdsBottomCTA.double(
          background: false,
          leftButton: null,
          rightButton: null,
          bottomAccessory: Text('버튼 없이 안내만 표시해요'),
        ),
      ],
    ),
  );
}

class TdsListAssetReferenceFixture extends StatelessWidget {
  const TdsListAssetReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TdsListHeader(
            title: TdsListHeaderTitleParagraph('내 계좌'),
            right: TdsListHeaderRightIconButton(
              name: 'icon-star-mono',
              semanticLabel: '즐겨찾기',
            ),
          ),
          for (final shape in TdsListRowAssetIconShape.values)
            TdsListRow(
              left: TdsListRowAssetIcon(
                name: 'icon-star-mono',
                shape: shape,
                color: TdsPalette.blue500,
                paddingX: true,
              ),
              contents: const TdsListRowTexts(
                type: TdsListRowTextType.row2TypeA,
                top: Text('토스뱅크'),
                bottom: Text('입출금 통장'),
              ),
            ),
          TdsListRow(
            left: const TdsListRowAssetText(
              'T',
              accessory: SizedBox.square(
                dimension: 11,
                child: ColoredBox(color: TdsPalette.blue500),
              ),
            ),
            contents: const TdsListRowTexts(
              type: TdsListRowTextType.row1TypeA,
              top: Text('보조 배지가 있는 계좌'),
            ),
          ),
          const TdsListRow(
            left: TdsListRowFillIcon(
              name: 'icon-star-mono',
              shape: TdsListRowFillIconShape.circleBackground,
            ),
            contents: TdsListRowTexts(
              type: TdsListRowTextType.row1TypeA,
              top: Text('관심 계좌'),
            ),
          ),
        ],
      ),
    ),
  );
}

class TdsCompoundsReferenceFixture extends StatelessWidget {
  const TdsCompoundsReferenceFixture({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TdsTop(
            title: TdsTopTitleParagraph('내 자산을 확인해요'),
            subtitleTop: TdsTopSubtitleParagraph('토스 디자인', size: 13),
            subtitleBottom: TdsTopSubtitleParagraph('모든 계좌를 한곳에서', size: 15),
            right: TdsTopRightArrow(),
            lower: TdsTopLowerCTA(
              children: [
                TdsTopLowerCTAButton(child: Text('확인')),
                TdsTopLowerCTAButton(
                  color: TdsButtonColor.dark,
                  variant: TdsButtonVariant.weak,
                  child: Text('나중에'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: TdsBubble(
              background: TdsBubbleBackground.grey,
              child: Text('궁금한 점을 물어보세요'),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerRight,
            child: TdsBubble(
              background: TdsBubbleBackground.blue,
              child: Text('내 자산을 확인하고 싶어요'),
            ),
          ),
          const SizedBox(height: 16),
          const TdsListRow(
            left: TdsListRowLeftText('1', border: true),
            contents: TdsListRowText('첫 번째 계좌'),
          ),
          const TdsListRow(
            left: TdsListRowLeftText('2', border: true),
            contents: TdsListRowText('두 번째 계좌'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TdsParagraphLink(
              text: '이용 약관 보기',
              typography: TdsTypography.t6,
              onPressed: () {},
            ),
          ),
        ],
      ),
    ),
  );
}

class TdsListReferenceFixture extends StatelessWidget {
  const TdsListReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: TdsList(
        children: [
          const TdsListHeader(
            title: TdsListHeaderTitleParagraph('내 계좌'),
            description: TdsListHeaderDescriptionParagraph('자산을 확인해요'),
            right: TdsListHeaderRightText('전체 보기'),
          ),
          for (final type in [
            TdsListRowTextType.row1TypeA,
            TdsListRowTextType.row2TypeA,
            TdsListRowTextType.row2TypeD,
            TdsListRowTextType.row3TypeA,
          ])
            TdsListRow(
              border: TdsListRowBorder.indented,
              withArrow: true,
              disabled: state == 'disabled',
              contents: TdsListRowTexts(
                type: type,
                top: const Text('토스뱅크'),
                middle: const Text('입출금 통장'),
                bottom: const Text('계좌 정보를 확인해요'),
              ),
              right: const TdsListRowTexts(
                type: TdsListRowTextType.right1RowTypeA,
                top: Text('12,000원'),
              ),
            ),
          const TdsTableRow(
            align: TdsTableRowAlign.spaceBetween,
            left: Text('은행'),
            right: Text('토스뱅크'),
            leftRatio: 40,
          ),
          const TdsListFooter(child: Text('더 보기')),
        ],
      ),
    ),
  );
}

class TdsToastReferenceFixture extends StatelessWidget {
  const TdsToastReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const TdsToast(
        open: true,
        persistent: true,
        position: TdsToastPosition.top,
        text: '변경 사항을 저장했어요',
      ),
      TdsToast(
        open: true,
        persistent: true,
        text: state == 'multiline'
            ? '토스 디자인 시스템으로 네이티브 Flutter 위젯을 만들고 원본과 비교하고 있어요'
            : '변경 사항을 저장했어요',
        button: state == 'action'
            ? const TdsToastButton(child: Text('실행 취소'))
            : null,
      ),
    ],
  );
}

class TdsFieldReferenceFixture extends StatelessWidget {
  const TdsFieldReferenceFixture({required this.state, super.key});
  final String state;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variant in TdsTextFieldVariant.values)
            TdsTextField(
              variant: variant,
              label: '이름',
              labelOption: TdsTextFieldLabelOption.sustain,
              value: state == 'empty' ? '' : '토스 디자인',
              placeholder: '이름을 입력하세요',
              help: const Text('도움말'),
              hasError: state == 'error',
              disabled: state == 'disabled',
            ),
        ],
      ),
    ),
  );
}

class TdsExtendedControlsFixture extends StatefulWidget {
  const TdsExtendedControlsFixture({super.key});
  @override
  State<TdsExtendedControlsFixture> createState() =>
      _TdsExtendedControlsFixtureState();
}

class _TdsExtendedControlsFixtureState
    extends State<TdsExtendedControlsFixture> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final size in TdsNumericSpinnerSize.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TdsNumericSpinner(size: size, defaultNumber: 5),
              ),
            ),
          for (final size in TdsSegmentedControlSize.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TdsSegmentedControl(
                size: size,
                defaultValue: 'a',
                items: const [
                  TdsSegmentedControlItem(value: 'a', text: '전체'),
                  TdsSegmentedControlItem(value: 'b', text: '진행 중'),
                  TdsSegmentedControlItem(value: 'c', text: '완료'),
                ],
              ),
            ),
          for (final size in TdsTabSize.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TdsTab(
                size: size,
                onChanged: (i) => setState(() => _tab = i),
                items: [
                  for (var i = 0; i < 3; i++)
                    TdsTabItem(
                      text: ['전체', '진행 중', '완료'][i],
                      selected: i == _tab,
                    ),
                ],
              ),
            ),
          for (final size in TdsProgressBarSize.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TdsProgressBar(size: size, progress: .4),
            ),
        ],
      ),
    ),
  );
}

class TdsButtonReferenceFixture extends StatelessWidget {
  const TdsButtonReferenceFixture({
    this.size = TdsButtonSize.xlarge,
    this.disabled = false,
    this.loading = false,
    super.key,
  });
  final TdsButtonSize size;
  final bool disabled, loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 390,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final color in [
            TdsButtonColor.primary,
            TdsButtonColor.danger,
            TdsButtonColor.dark,
            TdsButtonColor.light,
          ])
            for (final variant in TdsButtonVariant.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ColoredBox(
                  color: color == TdsButtonColor.light
                      ? TdsPalette.grey700
                      : const Color(0x00000000),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TdsButton(
                      size: size,
                      color: color,
                      variant: variant,
                      disabled: disabled,
                      loading: loading,
                      child: const Text('확인하기'),
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
