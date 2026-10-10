import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

Widget navigationApp(GlobalKey<NavigatorState> key) => WidgetsApp(
  navigatorKey: key,
  color: const Color(0xffffffff),
  builder: (_, navigator) => TdsMobileProvider(child: navigator!),
  home: const SizedBox.expand(),
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (c, a, s) => builder(c),
  ),
);

void main() {
  testWidgets('useToast survives route pop without restarting state or timer', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final controller = TdsToastController();
    await tester.pumpWidget(navigationApp(nav));
    nav.currentState!.push<void>(
      PageRouteBuilder(
        pageBuilder: (_, a, s) => TdsToastProvider(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.openToast(
      'retained',
      options: const TdsToastOptions(duration: Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(TdsToast));
    await tester.pump(const Duration(seconds: 7));
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TdsToastProvider), findsNothing);
    expect(tester.state(find.byType(TdsToast)), same(state));
    expect(find.text('retained'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('retained'), findsNothing);
    expect(controller.isOpen, isFalse);
    controller.dispose();
  });

  testWidgets(
    'web default exits on unmount and does not dispose external owner',
    (tester) async {
      final show = ValueNotifier<bool>(true);
      final controller = TdsToastController();
      await tester.pumpWidget(
        fieldApp(
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, _) => visible
                ? TdsToastProvider.web(
                    controller: controller,
                    child: const SizedBox.expand(),
                  )
                : const SizedBox(),
          ),
        ),
      );
      controller.openToast('web');
      await tester.pumpAndSettle();
      show.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(TdsToast), findsNothing);
      expect(controller.isOpen, isFalse);
      show.value = true;
      await tester.pumpAndSettle();
      controller.openToast('reused');
      await tester.pumpAndSettle();
      expect(find.text('reused'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      show.dispose();
    },
  );

  testWidgets('retained action, replacement, close and viewport remain live', (
    tester,
  ) async {
    final show = ValueNotifier<bool>(true);
    final controller = TdsToastController();
    var clicks = 0;
    await tester.pumpWidget(
      fieldApp(
        ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, _) => visible
              ? TdsToastProvider(
                  controller: controller,
                  child: const SizedBox.expand(),
                )
              : const SizedBox(),
        ),
      ),
    );
    controller.openToast(
      'persistent',
      options: TdsToastOptions(
        persistent: true,
        button: TdsToastButton(
          onPressed: () => clicks++,
          child: const Text('action'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    show.value = false;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.text('action'));
    expect(clicks, 1);
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(TdsToastContent)).dy, 880);
    controller.openToast('replacement');
    await tester.pumpAndSettle();
    expect(find.text('persistent'), findsNothing);
    expect(find.text('replacement'), findsOneWidget);
    controller.closeToast();
    await tester.pumpAndSettle();
    expect(find.byType(TdsToast), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    show.dispose();
  });

  testWidgets('owned controller survives until exit, then is released', (
    tester,
  ) async {
    final show = ValueNotifier<bool>(true);
    late TdsToastController controller;
    await tester.pumpWidget(
      fieldApp(
        ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, _) => visible
              ? TdsToastProvider(
                  child: Builder(
                    builder: (context) {
                      controller = TdsToastProvider.of(context);
                      return const SizedBox.expand();
                    },
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
    controller.openToast('owned');
    await tester.pumpAndSettle();
    show.value = false;
    await tester.pumpAndSettle();
    expect(find.text('owned'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    controller.openToast('disposed');
    expect(controller.isOpen, isFalse);
    expect(find.byType(TdsToast), findsNothing);
    show.dispose();
  });

  testWidgets(
    'root teardown clears a retained toast; controller can reattach',
    (tester) async {
      final controller = TdsToastController();
      Widget app() => fieldApp(
        TdsToastProvider(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(app());
      controller.openToast('root');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.isOpen, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app());
      controller.openToast('new root');
      await tester.pumpAndSettle();
      expect(find.text('new root'), findsOneWidget);
      controller.dispose();
      await tester.pumpAndSettle();
      expect(find.byType(TdsToast), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close and root destruction before first frame leave no entries',
    (tester) async {
      final controller = TdsToastController();
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.openToast('never presented');
      controller.closeToast();
      await tester.pumpAndSettle();
      expect(find.byType(TdsToast), findsNothing);
      controller.openToast('root destroyed');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      controller.dispose();
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero duration uses hook default instead of immediate dismissal',
    (tester) async {
      final controller = TdsToastController();
      await tester.pumpWidget(
        fieldApp(
          TdsToastProvider(
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.openToast(
        'zero',
        options: const TdsToastOptions(duration: Duration.zero),
      );
      await tester.pumpAndSettle();
      expect(find.text('zero'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('zero'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
