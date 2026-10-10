import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'collections_feedback_test.dart' show testApp;

class HostToast implements TdsHostToast {
  @override
  void show(String message, TdsHostToastOptions options) {}
}

void main() {
  testWidgets(
    'sheet onEntered fires when opening commits, never again at spring completion',
    (tester) async {
      var entered = 0, exited = 0;
      Widget view(bool open) => testApp(
        TdsBottomSheet(
          open: open,
          onEntered: () => entered++,
          onExited: () => exited++,
          child: const SizedBox(height: 100, child: Text('sheet')),
        ),
      );
      await tester.pumpWidget(view(false));
      expect(entered, 0);
      await tester.pumpWidget(view(true));
      expect(entered, 1);
      await tester.pumpAndSettle();
      expect(entered, 1);
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(entered, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(exited, 1);
      await tester.pumpWidget(view(true));
      expect(entered, 2);
      await tester.pumpAndSettle();
      expect(entered, 2);
    },
  );
  testWidgets(
    'ignored sheet dimmer neither dispatches callbacks nor starts an invisible wiggle',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        testApp(
          TdsBottomSheet(
            open: true,
            ignoreDimmerClick: true,
            onClose: () => calls++,
            onDimmerClick: () => calls++,
            child: const SizedBox(height: 100, child: Text('sheet')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(calls, 0);
      expect(tester.hasRunningAnimations, false);
    },
  );
  testWidgets(
    'open modal preserves and updates theme, host toast, loading callbacks and back stream',
    (tester) async {
      final first = HostToast(), second = HostToast();
      final firstBack = StreamController<void>.broadcast(),
          secondBack = StreamController<void>.broadcast();
      var closes = 0, entered = 0;
      final loading = <String>[];
      final local = GlobalKey();
      Widget view(bool updated) => testApp(
        TdsMobileProvider(
          theme: TdsThemeData(
            colorScheme: updated
                ? TdsColorPreference.dark
                : TdsColorPreference.light,
          ),
          child: TdsHostProvider(
            toast: updated ? second : first,
            child: TdsGlobalConfigProvider(
              backEvent: updated ? secondBack.stream : firstBack.stream,
              onLoadingStarted: (id) =>
                  loading.add('${updated ? 'new' : 'old'}:$id'),
              onLoadingFinish: (id) => loading.add('done:$id'),
              child: TdsModal(
                open: true,
                onClose: () => closes++,
                onEntered: () => entered++,
                child: Builder(
                  key: local,
                  builder: (context) =>
                      Text(TdsTheme.of(context).isDark ? 'dark' : 'light'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(
        TdsHostProvider.maybeOf(local.currentContext!)?.toast,
        same(first),
      );
      TdsGlobalConfigProvider.maybeOf(local.currentContext!)!.onLoadingStarted!(
        'x',
      );
      expect(loading, ['old:x']);
      expect(find.text('light'), findsOneWidget);
      firstBack.add(null);
      await tester.pump();
      expect(closes, 1);
      await tester.pumpWidget(view(true));
      await tester.pumpAndSettle();
      expect(entered, 1); // updates do not replace/re-enter the route
      expect(
        TdsHostProvider.maybeOf(local.currentContext!)?.toast,
        same(second),
      );
      expect(find.text('dark'), findsOneWidget);
      final config = TdsGlobalConfigProvider.maybeOf(local.currentContext!)!;
      config.onLoadingStarted!('y');
      config.onLoadingFinish!('y');
      expect(loading, ['old:x', 'new:y', 'done:y']);
      firstBack.add(null);
      await tester.pump();
      expect(closes, 1);
      secondBack.add(null);
      await tester.pump();
      expect(closes, 2);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(firstBack.hasListener, false);
      expect(secondBack.hasListener, false);
      await firstBack.close();
      await secondBack.close();
      expect(tester.takeException(), isNull);
    },
  );
}
