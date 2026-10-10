import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

void main() {
  testWidgets(
    'default context is empty; provider aggregates unique IDs and uses latest callbacks',
    (tester) async {
      TdsGlobalConfigContext? contextValue;
      final events = <String>[];
      final consumer = Builder(
        builder: (context) {
          contextValue = useGlobalConfigContext(context);
          return const SizedBox();
        },
      );
      await tester.pumpWidget(testApp(consumer));
      expect(contextValue!.onLoadingStarted, isNull);
      expect(contextValue!.onLoadingFinish, isNull);
      expect(contextValue!.backEvent, isNull);
      Widget provider(bool updated) => testApp(
        TdsGlobalConfigProvider(
          config: TdsGlobalConfig(
            onLoadingStart: () => events.add(updated ? 'new-start' : 'start'),
            onLoadingFinish: () =>
                events.add(updated ? 'new-finish' : 'finish'),
          ),
          child: consumer,
        ),
      );
      await tester.pumpWidget(provider(false));
      final captured = contextValue!;
      captured.onLoadingStarted!('a');
      captured.onLoadingStarted!('a');
      captured.onLoadingStarted!('b');
      expect(events, ['start']);
      captured.onLoadingFinish!('a');
      expect(events, ['start']);
      await tester.pumpWidget(provider(true));
      captured.onLoadingFinish!('b');
      captured.onLoadingFinish!('unknown');
      expect(events, ['start', 'new-finish', 'new-finish']);
      captured.onLoadingStarted!('c');
      expect(events.last, 'new-start');
    },
  );

  testWidgets(
    'overlapping loaders notify once until the last unmount, without restarting on rebuild',
    (tester) async {
      final events = <String>[], starts = <String>[], finishes = <String>[];
      Widget view(int count, {bool changed = false}) => testApp(
        TdsGlobalConfigProvider(
          config: TdsGlobalConfig(
            onLoadingStart: () => events.add('start'),
            onLoadingFinish: () =>
                events.add(changed ? 'new-finish' : 'finish'),
          ),
          onLoadingStarted: starts.add,
          onLoadingFinish: finishes.add,
          child: Column(
            children: [
              if (count >= 1)
                TdsLoader(
                  key: const ValueKey('a'),
                  label: changed ? 'updated' : 'one',
                ),
              if (count >= 2) const TdsLoader(key: ValueKey('b'), label: 'two'),
            ],
          ),
        ),
      );
      await tester.pumpWidget(view(1));
      expect(events, ['start']);
      await tester.pumpWidget(view(2));
      expect(starts.length, 2);
      expect(starts.toSet().length, 2);
      expect(events, ['start']);
      await tester.pumpWidget(view(1, changed: true));
      expect(finishes, [starts[1]]);
      expect(events, ['start']);
      await tester.pumpWidget(view(0, changed: true));
      expect(finishes, [starts[1], starts[0]]);
      expect(events, ['start', 'new-finish']);
      await tester.pump();
      expect(tester.hasRunningAnimations, false);
    },
  );

  testWidgets(
    'loader in a modal uses the same global aggregate and direct animation/button loading do not register',
    (tester) async {
      final events = <String>[];
      Widget view(bool open) => testApp(
        TdsGlobalConfigProvider(
          config: TdsGlobalConfig(
            onLoadingStart: () => events.add('start'),
            onLoadingFinish: () => events.add('finish'),
          ),
          child: Column(
            children: [
              const TdsLoaderAnimation(),
              const TdsButton(loading: true, child: Text('button')),
              TdsModal(open: open, child: const TdsLoader()),
            ],
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(events, isEmpty);
      await tester.pumpWidget(view(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(events, ['start']);
      await tester.pumpWidget(view(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(events, ['start', 'finish']);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loader has source 700ms delay/300ms CSS fade and omits empty labels',
    (tester) async {
      await tester.pumpWidget(testApp(const TdsLoader(label: '')));
      final fade = find.descendant(
        of: find.byType(TdsLoader),
        matching: find.byType(FadeTransition),
      );
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
      expect(opacity(), 0);
      expect(find.byType(TdsText), findsNothing);
      expect(tester.getSize(find.byType(TdsLoader)).height, 60);
      await tester.pump(const Duration(milliseconds: 700));
      expect(opacity(), 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(), closeTo(.5, .001));
      await tester.pump(const Duration(milliseconds: 150));
      expect(opacity(), 1);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
