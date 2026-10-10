import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget listApp(Widget child, {double scale = 100}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, navigator) => TdsMobileProvider(
    theme: TdsThemeData(
      platform: TdsPlatform(os: TdsOS.android, fontScale: scale),
    ),
    child: navigator!,
  ),
  home: SingleChildScrollView(child: child),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (c, a, s) => builder(c),
  ),
);

void main() {
  testWidgets('all 25 extracted presets keep their source text styles', (
    tester,
  ) async {
    expect(TdsListRowTextType.values.length, 25);
    for (final type in TdsListRowTextType.values) {
      await tester.pumpWidget(
        listApp(
          TdsListRow(
            contents: TdsListRowTexts(
              type: type,
              top: const Text('위'),
              middle: const Text('중간'),
              bottom: const Text('아래'),
            ),
          ),
        ),
      );
      final presets = tdsListRowTextPresets[type]!;
      final labels = [
        '위',
        if (presets.length == 3) '중간',
        if (presets.length >= 2) '아래',
      ];
      for (var i = 0; i < labels.length; i++) {
        final text = tester.widget<RichText>(
          find.descendant(
            of: find.text(labels[i]),
            matching: find.byType(RichText),
          ),
        );
        expect(
          text.text.style!.fontSize,
          presets[i].$1.baseSize,
          reason: type.sourceName,
        );
        expect(
          text.text.style!.fontWeight,
          presets[i].$2.value,
          reason: type.sourceName,
        );
        expect(text.text.style!.height, 1.35);
      }
      final expected = presets.fold(
        24.0,
        (height, style) => height + style.$1.baseSize * 1.35,
      );
      expect(
        tester.getSize(find.byType(TdsListRow)).height,
        closeTo(math.max(44, expected), .001),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'row activation, disabled nested controls and independent alignment',
    (tester) async {
      var activated = 0, toggled = 0;
      Widget row(bool disabled) => TdsListRow(
        disabled: disabled,
        onPressed: () => activated++,
        leftAlignment: TdsListRowAlignment.top,
        left: const SizedBox(key: ValueKey('left'), width: 24, height: 24),
        contents: const TdsListRowTexts(
          type: TdsListRowTextType.row2TypeA,
          top: Text('위'),
          bottom: Text('아래'),
        ),
        right: TdsSwitch(checked: false, onChanged: (_) => toggled++),
      );
      await tester.pumpWidget(listApp(row(false)));
      expect(tester.getTopLeft(find.byKey(const ValueKey('left'))).dy, 12);
      await tester.tap(find.text('위'));
      expect(activated, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, 2);
      await tester.pumpWidget(listApp(row(true)));
      await tester.tap(find.byType(TdsSwitch), warnIfMissed: false);
      await tester.tap(find.text('위'), warnIfMissed: false);
      expect(activated, 2);
      expect(toggled, 0);
    },
  );

  testWidgets(
    'supported right content reflows at source viewport/font thresholds',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const row = TdsListRow(
        contents: TdsListRowTexts(
          type: TdsListRowTextType.row1TypeA,
          top: Text('제목'),
        ),
        right: TdsListRowTexts(
          type: TdsListRowTextType.right1RowTypeA,
          top: Text('상태'),
        ),
      );
      await tester.pumpWidget(listApp(row));
      expect(
        tester.getTopLeft(find.text('제목')).dy,
        tester.getTopLeft(find.text('상태')).dy,
      );
      await tester.pumpWidget(listApp(row, scale: 135));
      expect(
        tester.getTopLeft(find.text('상태')).dy -
            tester.getBottomLeft(find.text('제목')).dy,
        closeTo(6, 1),
      );
      expect(tester.getTopLeft(find.text('상태')).dx, 24);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('header and table large-font layouts remain bounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      listApp(
        const TdsList(
          children: [
            TdsListHeader(
              title: TdsListHeaderTitleParagraph('제목'),
              right: TdsListHeaderRightText('전체 보기'),
            ),
            TdsTableRow(
              left: Text('항목'),
              right: Text('내용'),
              align: TdsTableRowAlign.spaceBetween,
              leftRatio: 40,
            ),
            TdsListFooter(child: Text('더 보기')),
          ],
        ),
        scale: 200,
      ),
    );
    expect(
      tester.getTopLeft(find.text('전체 보기')).dy,
      greaterThan(tester.getBottomLeft(find.text('제목')).dy),
    );
    expect(
      tester.getTopLeft(find.text('내용')).dy,
      greaterThan(tester.getBottomLeft(find.text('항목')).dy),
    );
    expect(
      tester.getSize(find.byType(TdsListFooter)).height,
      greaterThanOrEqualTo(59),
    );
    expect(tester.takeException(), isNull);
  });
}
