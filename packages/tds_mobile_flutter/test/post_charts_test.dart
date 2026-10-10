import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets('Post lists preserve ordered numbering and headings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        const Column(
          children: [
            TdsPostH1('제목'),
            TdsPostOl(
              children: [
                TdsPostLi(child: Text('첫째')),
                Text('둘째'),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(tester.getSemantics(find.text('제목')).flagsCollection.isHeader, true);
    semantics.dispose();
  });
  testWidgets(
    'ProgressStepper aligns endpoints and supports empty/single steps',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsProgressStepper(
            activeStepIndex: 1,
            children: [
              TdsProgressStep(title: '시작'),
              TdsProgressStep(title: '중간'),
              TdsProgressStep(title: '끝'),
            ],
          ),
        ),
      );
      final steps = find.byType(TdsProgressStep);
      expect(tester.getTopLeft(steps.at(0)).dx, 24);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        testApp(
          const TdsProgressStepper(children: [TdsProgressStep(title: '하나')]),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(testApp(const TdsProgressStepper(children: [])));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Doughnut zero values, animation reversal and disposal are safe',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsDoughnut(
            size: 100,
            thickness: 20,
            data: [TdsDoughnutData(value: 0, color: Color(0xff3182f6))],
            show: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        testApp(
          const TdsDoughnut(
            size: 100,
            thickness: 20,
            data: [TdsDoughnutData(value: 3, color: Color(0xff3182f6))],
            show: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(testApp(const SizedBox()));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'BarChart supports empty/zero data and endpoint labels above 12 bars',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const TdsBarChart(data: [], fill: TdsAllBarFill(TdsBarTheme.blue)),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        testApp(
          TdsBarChart(
            data: List.generate(
              13,
              (i) => TdsBarItem(value: 0, label: 'bar$i'),
            ),
            fill: const TdsAllBarFill(TdsBarTheme.blue),
          ),
        ),
      );
      expect(find.text('bar0'), findsOneWidget);
      expect(find.text('bar12'), findsOneWidget);
      expect(find.text('bar6'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Stepper entry timers cancel on unmount', (tester) async {
    await tester.pumpWidget(
      testApp(
        const TdsStaggerIn(delay: Duration(seconds: 1), child: Text('나중')),
      ),
    );
    await tester.pumpWidget(testApp(const SizedBox()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
