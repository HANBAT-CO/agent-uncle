import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

Widget ctaApp(
  Widget child, {
  double safeBottom = 0,
  double keyboard = 0,
  bool reduced = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, navigator) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      viewPadding: EdgeInsets.only(bottom: safeBottom),
      viewInsets: EdgeInsets.only(bottom: keyboard),
      disableAnimations: reduced,
    ),
    child: TdsMobileProvider(
      theme: const TdsThemeData(platform: TdsPlatform(os: TdsOS.android)),
      child: navigator!,
    ),
  ),
  home: child,
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (c, a, s) => builder(c),
  ),
);

void main() {
  Future<void> viewport(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget flow(Widget child) =>
      Align(alignment: Alignment.topLeft, child: child);

  testWidgets('Single alias forwards disabled content and source spacing', (
    tester,
  ) async {
    await viewport(tester);
    await tester.pumpWidget(
      ctaApp(
        flow(
          const TdsBottomCTA.single(
            disabled: true,
            disabledChild: Text('준비 중'),
            topAccessory: SizedBox(height: 10),
            bottomAccessory: SizedBox(height: 12),
            child: Text('확인'),
          ),
        ),
        safeBottom: 34,
      ),
    );
    expect(find.text('준비 중'), findsOneWidget);
    expect(find.text('확인'), findsNothing);
    expect(
      tester.getSize(find.byType(TdsBottomCTA)).height,
      36 + 10 + 26 + 56 + 24 + 12 + 34,
    );
    final gradient = tester
        .widgetList<Container>(find.byType(Container))
        .map((e) => e.decoration)
        .whereType<BoxDecoration>()
        .map((e) => e.gradient)
        .whereType<LinearGradient>()
        .single;
    expect(gradient.stops, [0, .75, 1]);
    expect(tester.getSize(find.byType(TdsCTAButton)).width, 350);
  });

  testWidgets(
    'Double permits either or both null slots without making a Single',
    (tester) async {
      await viewport(tester);
      for (final left in [false, true]) {
        for (final right in [false, true]) {
          await tester.pumpWidget(
            ctaApp(
              flow(
                TdsBottomCTA.double(
                  leftButton: left
                      ? const SizedBox(
                          key: ValueKey('left'),
                          width: 50,
                          height: 30,
                        )
                      : null,
                  rightButton: right
                      ? const SizedBox(
                          key: ValueKey('right'),
                          width: 50,
                          height: 40,
                        )
                      : null,
                  background: false,
                ),
              ),
            ),
          );
          expect(find.byType(TdsCTAButton), findsNothing);
          expect(
            tester.getSize(find.byType(TdsBottomCTA)).height,
            20 +
                (right
                    ? 40
                    : left
                    ? 30
                    : 0),
          );
          if (left != right) {
            expect(
              tester
                  .getSize(find.byKey(ValueKey(left ? 'left' : 'right')))
                  .width,
              350,
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'Double uses intrinsic flex growth, stretch and viewport rounding',
    (tester) async {
      await viewport(tester);
      for (final width in [390.0, 391.0]) {
        tester.view.physicalSize = Size(width, 700);
        await tester.pumpWidget(
          ctaApp(
            flow(
              const TdsBottomCTA.double(
                background: false,
                hasPaddingBottom: false,
                leftButton: SizedBox(
                  key: ValueKey('left'),
                  width: 50,
                  height: 30,
                ),
                rightButton: SizedBox(
                  key: ValueKey('right'),
                  width: 172,
                  height: 40,
                ),
              ),
            ),
          ),
        );
        final left = tester.getRect(find.byKey(const ValueKey('left')));
        final right = tester.getRect(find.byKey(const ValueKey('right')));
        final gap = width == 390 ? 8.0 : 7.0;
        final available = width - 40;
        final base = available / 2 - gap;
        expect(left.width, base);
        expect(right.width, available - base - gap);
        expect(right.left - left.right, gap);
        expect(left.height, right.height);
      }
    },
  );

  testWidgets(
    'Double wraps in reverse order from intrinsic widths, including RTL',
    (tester) async {
      await viewport(tester);
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          ctaApp(
            flow(
              Directionality(
                textDirection: direction,
                child: const TdsBottomCTA.double(
                  background: false,
                  hasPaddingBottom: false,
                  leftButton: SizedBox(
                    key: ValueKey('left'),
                    width: 180,
                    height: 30,
                  ),
                  rightButton: SizedBox(
                    key: ValueKey('right'),
                    width: 180,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        );
        final left = tester.getRect(find.byKey(const ValueKey('left')));
        final right = tester.getRect(find.byKey(const ValueKey('right')));
        expect(right.top, 0);
        expect(left.top, 48);
        expect(left.width, 350);
        expect(right.width, 350);
        expect(tester.getSize(find.byType(TdsBottomCTA)).height, 78);
      }
    },
  );

  testWidgets('show translates exactly 50px and reverses without jumping', (
    tester,
  ) async {
    await viewport(tester);
    late StateSetter update;
    var show = true;
    await tester.pumpWidget(
      ctaApp(
        flow(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TdsBottomCTA(show: show, child: const Text('확인'));
            },
          ),
        ),
      ),
    );
    final button = find.byType(TdsCTAButton);
    final y = tester.getTopLeft(button).dy;
    final height = tester.getSize(find.byType(TdsBottomCTA)).height;
    update(() => show = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final mid = tester.getTopLeft(button).dy;
    expect(mid, greaterThan(y));
    expect(mid, lessThan(y + 50));
    update(() => show = true);
    await tester.pump();
    expect(tester.getTopLeft(button).dy, closeTo(mid, .0001));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button).dy, y);
    update(() => show = false);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(button).dy, y + 50);
    expect(tester.getSize(find.byType(TdsBottomCTA)).height, height);
  });

  testWidgets(
    'scroll observer threshold, trailing reversal and explicit show reset',
    (tester) async {
      await viewport(tester);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      late StateSetter update;
      var show = true;
      await tester.pumpWidget(
        ctaApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: scroll,
                    child: const SizedBox(height: 2000),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TdsBottomCTA(
                      hideOnScroll: true,
                      hideOnScrollDistanceThreshold: 10,
                      show: show,
                      child: const Text('확인'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final button = find.byType(TdsCTAButton);
      final y = tester.getTopLeft(button).dy;
      scroll.jumpTo(10);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, y);
      scroll.jumpTo(11);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, y + 50);
      scroll.jumpTo(100);
      scroll.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, y);
      scroll.jumpTo(100);
      await tester.pumpAndSettle();
      update(() => show = false);
      await tester.pumpAndSettle();
      update(() => show = true);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, y);
      scroll.jumpTo(150);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button).dy, y + 50);
      scroll.jumpTo(180);
      await tester.pumpWidget(ctaApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit scroll controller is not disposed and hideOnScroll can be disabled',
    (tester) async {
      await viewport(tester);
      final scroll = ScrollController();
      late StateSetter update;
      var hide = true;
      await tester.pumpWidget(
        ctaApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scroll,
                      child: const SizedBox(height: 2000),
                    ),
                  ),
                  TdsBottomCTA(
                    hideOnScroll: hide,
                    scrollController: scroll,
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final y = tester.getTopLeft(find.byType(TdsCTAButton)).dy;
      scroll.jumpTo(10);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TdsCTAButton)).dy, y + 50);
      update(() => hide = false);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TdsCTAButton)).dy, y);
      scroll.jumpTo(40);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TdsCTAButton)).dy, y);
      await tester.pumpWidget(ctaApp(const SizedBox()));
      scroll.addListener(() {});
      scroll.dispose();
    },
  );

  for (final animation in TdsBottomCTAAnimation.values) {
    testWidgets(
      'delayed ${animation.name} uses source duration and independent gradient',
      (tester) async {
        await viewport(tester);
        await tester.pumpWidget(
          ctaApp(
            flow(
              TdsBottomCTA(
                showAfterDelay: TdsBottomCTADelayedEntrance(
                  delay: const Duration(milliseconds: 100),
                  animation: animation,
                ),
                child: const Text('확인'),
              ),
            ),
          ),
        );
        final button = find.byType(TdsCTAButton);
        List<double> opacities() => tester
            .widgetList<Opacity>(
              find.ancestor(of: button, matching: find.byType(Opacity)),
            )
            .map((e) => e.opacity)
            .toList();
        expect(opacities(), contains(0));
        if (animation == TdsBottomCTAAnimation.slide) {
          expect(tester.getTopLeft(button).dy, 116);
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        final t = animation == TdsBottomCTAAnimation.fade ? .5 : .375;
        final expected =
            (animation == TdsBottomCTAAnimation.fade
                    ? const Cubic(.6, 0, 0, .6)
                    : TdsMotion.expo)
                .transform(t);
        expect(opacities(), contains(closeTo(expected, .0001)));
        await tester.pumpAndSettle();
        expect(opacities(), everyElement(1));
        expect(tester.getTopLeft(button).dy, 36);
      },
    );
  }

  testWidgets(
    'delayed entrance cancels on unmount and respects reduced motion',
    (tester) async {
      await viewport(tester);
      const cta = TdsBottomCTA(
        showAfterDelay: TdsBottomCTADelayedEntrance(
          delay: Duration(seconds: 10),
          animation: TdsBottomCTAAnimation.slide,
        ),
        child: Text('확인'),
      );
      await tester.pumpWidget(ctaApp(flow(cta)));
      await tester.pumpWidget(ctaApp(const SizedBox()));
      await tester.pump(const Duration(seconds: 11));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(ctaApp(flow(cta), reduced: true));
      expect(tester.getTopLeft(find.byType(TdsCTAButton)).dy, 36);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('keyboard and safe-area distinguish Single from Double', (
    tester,
  ) async {
    await viewport(tester);
    await tester.pumpWidget(
      ctaApp(
        flow(const TdsBottomCTA(child: Text('확인'))),
        keyboard: 250,
        safeBottom: 34,
      ),
    );
    expect(tester.getSize(find.byType(TdsBottomCTA)).height, 92);
    expect(
      tester.widget<TdsCTAButton>(find.byType(TdsCTAButton)).display,
      TdsButtonDisplay.full,
    );
    expect(tester.getSize(find.byType(TdsCTAButton)).width, 390);
    await tester.pumpWidget(
      ctaApp(
        flow(
          const TdsBottomCTA.double(
            leftButton: SizedBox(height: 56),
            rightButton: null,
          ),
        ),
        keyboard: 250,
        safeBottom: 34,
      ),
    );
    expect(tester.getSize(find.byType(TdsBottomCTA)).height, 126);
  });

  testWidgets(
    'takeSpace defaults to fixed; explicit inline spacer is measured',
    (tester) async {
      await viewport(tester);
      await tester.pumpWidget(
        ctaApp(flow(const TdsBottomCTA(child: Text('확인')))),
      );
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(TdsBottomCTA)).height;
      await tester.pumpWidget(
        ctaApp(flow(const TdsBottomCTA(takeSpace: true, child: Text('확인')))),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TdsBottomCTA)).height, height * 2);
      await tester.pumpWidget(
        ctaApp(const Column(children: [TdsFixedBottomCTA(child: Text('확인'))])),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TdsFixedPanel)).height, height);
      await tester.pumpWidget(
        ctaApp(
          const Column(
            children: [TdsFixedBottomCTA(takeSpace: false, child: Text('확인'))],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TdsFixedPanel)).height, 0);
    },
  );
}
