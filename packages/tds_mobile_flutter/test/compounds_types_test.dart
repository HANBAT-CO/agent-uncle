import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('Top compounds preserve source sizes and route activation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        Column(
          children: [
            TdsTop(
              title: const TdsTopTitleParagraph('제목'),
              subtitleBottom: const TdsTopSubtitleParagraph('부제'),
              lower: TdsTopLowerCTA(
                children: [
                  TdsTopLowerCTAButton(
                    onPressed: () => taps++,
                    child: const Text('계속'),
                  ),
                  const TdsTopLowerCTAButton(child: Text('취소')),
                ],
              ),
            ),
            const TdsTopLowerButton(child: Text('작은 버튼')),
            const TdsTopRightButton(child: Text('오른쪽 버튼')),
          ],
        ),
      ),
    );
    expect(
      tester.widget<TdsTopLowerButton>(find.byType(TdsTopLowerButton)).size,
      TdsButtonSize.small,
    );
    expect(
      tester.widget<TdsTopRightButton>(find.byType(TdsTopRightButton)).size,
      TdsButtonSize.medium,
    );
    expect(
      tester.getSize(find.byType(TdsTopLowerCTAButton).first).width,
      tester.getSize(find.byType(TdsTopLowerCTAButton).last).width,
    );
    expect(tester.getSize(find.byType(TdsTopLowerCTAButton).first).width, 80);
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Top selector and subtitle defaults use actual typography keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const Column(
          children: [
            TdsTopTitleSelector(text: '제목'),
            TdsTopSubtitleSelector(text: '부제', size: 13),
            TdsTopSubtitleBadges(
              badges: [
                TdsTopSubtitleBadge(
                  text: '새 소식',
                  color: TdsBadgeColor.blue,
                  variant: TdsBadgeVariant.weak,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final selectors = tester
        .widgetList<TdsSelector>(find.byType(TdsSelector))
        .toList();
    expect(selectors[0].typography, TdsTypography.t3);
    expect(selectors[0].fontWeight, TdsFontWeight.bold);
    expect(selectors[1].typography, TdsTypography.t7);
    expect(
      tester.widget<TdsBadge>(find.byType(TdsBadge)).size,
      TdsBadgeSize.small,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'List image frame dimensions and header inheritance match source tables',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          Column(
            children: [
              for (final type in TdsListRowImageType.values.skip(1))
                TdsListRowImageContainer(
                  type: type,
                  child: const SizedBox.expand(),
                ),
              const TdsListHeader(
                size: TdsListHeaderSize.large,
                title: TdsListHeaderTitleSelector(text: '계좌'),
              ),
            ],
          ),
        ),
      );
      final containers = find.byType(TdsListRowImageContainer);
      for (var i = 0; i < containers.evaluate().length; i++) {
        final expected = TdsListRowImageContainer.dimensions(
          TdsListRowImageType.values[i + 1],
        );
        expect(
          tester.getSize(containers.at(i)),
          Size(expected.width!, expected.height!),
        );
      }
      expect(
        tester.widget<TdsSelector>(find.byType(TdsSelector)).typography,
        TdsTypography.t4,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Paragraph link is activated once and advertises link semantics',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          Align(
            alignment: Alignment.topLeft,
            child: TdsParagraphLink(text: '약관 보기', onPressed: () => taps++),
          ),
        ),
      );
      await tester.tap(find.text('약관 보기'));
      await tester.pump();
      expect(taps, 1);
      expect(find.bySemanticsLabel('약관 보기'), findsOneWidget);
      semantics.dispose();
    },
  );
  testWidgets(
    'Agreement controller controls expansion and survives host replacement',
    (tester) async {
      final controller = TdsAgreementV3CollapsibleGroupController();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          TdsAgreementV3CollapsibleGroup(
            controller: controller,
            header: (_, open, toggle) => TdsTextButton(
              size: TdsTextButtonSize.medium,
              onPressed: toggle,
              child: const Text('전체 약관'),
            ),
            child: const Text('약관 상세'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('약관 상세'), findsNothing);
      controller.open();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('약관 상세'), findsOneWidget);
      await tester.tap(find.text('전체 약관'));
      await tester.pumpAndSettle();
      expect(controller.isOpen, false);
      await tester.pumpWidget(testApp(const SizedBox()));
      controller.toggle();
      controller.close();
      controller.dispose();
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'List row effects reset on completion, replacement and disposal',
    (tester) async {
      final first = TdsListRowController(), second = TdsListRowController();
      Widget row(TdsListRowController controller) => testApp(
        TdsListRow(controller: controller, contents: const Text('내 계좌')),
      );
      await tester.pumpWidget(row(first));
      first.blink();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, true);
      first.blink(); // ignored while active
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(); // Original retains the slow blink fade-out.
      expect(tester.hasRunningAnimations, false);
      first.shine(playCount: 2);
      await tester.pump();
      await tester.pumpWidget(row(second));
      expect(tester.hasRunningAnimations, false);
      second.shine();
      await tester.pump();
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      first.dispose();
      second.dispose();
    },
  );
  test(
    'Native prop composition is immutable and right-biased like the source',
    () {
      final source = TdsProps({
        'value': 1,
        'color': 'red',
        'transition': 10,
        'as': 'div',
        'label': 'before',
      });
      final overrides = TdsProps({'label': 'after', 'color': 'blue'});
      expect(source.rightJoin(overrides).values, {
        'value': 1,
        'label': 'after',
        'color': 'blue',
      });
      expect(source['label'], 'before');
      expect(() => source.values['label'] = '', throwsUnsupportedError);
      expect(
        source
            .mergeWithAs(TdsProps({'id': 'x'}), overrides, as: 'native')
            .values,
        {
          'value': 1,
          'label': 'after',
          'color': 'blue',
          'id': 'x',
          'as': 'native',
        },
      );
    },
  );
  testWidgets('Typed component builders retain explicit props and keys', (
    tester,
  ) async {
    final key = GlobalKey();
    final component = TdsComponentWithAs<String>(
      builder: (_, props, key) => Text(props, key: key),
    );
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) =>
              TdsPropsOf(component, '본문').build(context, key: key),
        ),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
    expect(find.text('본문'), findsOneWidget);
  });
  testWidgets(
    'Typed keypad emits restricted number keys and validates alphabet literals',
    (tester) async {
      TdsNumberKey? key;
      await tester.pumpWidget(
        testApp(
          TdsNumberKeypad.typed(
            onKeyClick: (v) => key = v,
            onBackspaceClick: () {},
          ),
        ),
      );
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(key, TdsNumberKey.one);
      expect(TdsAlphabetKey.values.length, 52);
      expect(TdsAlphabetKey('a'), TdsAlphabetKey('a'));
      expect(() => TdsAlphabetKey('가'), throwsArgumentError);
      expect(() => TdsAlphabetKey('AA'), throwsArgumentError);
    },
  );
  test('Web typography uses its separate non-rounded Android limits', () {
    const platform = TdsPlatform(os: TdsOS.android, fontScale: 135);
    final variables = TdsTypographyVariables(platform, web: true);
    expect(variables.css['--toss-font-size-17'], '22.95px');
    expect(variables.css['--toss-line-height-17'], '32.0px');
    expect(variables.mobileCSS.containsKey('--tds-t-t5-text-fontSize'), true);
    const ios = TdsTypographyVariables(
      TdsPlatform(os: TdsOS.ios, fontA11y: 'A11y_xxxLarge'),
      web: true,
    );
    expect(ios.css['--toss-font-size-11'], '31.0px');
  });
}
