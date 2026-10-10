import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

class FakeSecure implements TdsSecureScreen {
  final calls = <String>[];
  final pendingEnable = Completer<void>();
  @override
  Future<void> enable() {
    calls.add('enable');
    return pendingEnable.future;
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
  }
}

class FakeNavigation implements TdsNavigation {
  final calls = <String>[];
  @override
  void addAccessoryButton(TdsAccessoryButton button) =>
      calls.add((button as TdsAccessoryTextButton).title);
  @override
  void removeAccessoryButton() => calls.add('remove');
}

void main() {
  testWidgets(
    'opt-in platform haptics call only their documented native approximation',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      for (final type in TdsHapticType.values) {
        await const TdsNoopHaptic().generate(type);
      }
      expect(calls, isEmpty);
      for (final type in TdsHapticType.values) {
        await const TdsPlatformHaptic().generate(type);
      }
      expect(calls.map((call) => call.method).toSet(), {
        'HapticFeedback.vibrate',
      });
      expect(calls.map((call) => call.arguments).toList(), [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
      // This validates calls, not physical motor strength or Toss host patterns.
    },
  );

  testWidgets(
    'secure host replacements stay ordered while initial enable is pending',
    (tester) async {
      final first = FakeSecure(), second = FakeSecure();
      Widget view(TdsSecureScreen host, bool enabled) => TdsHostProvider(
        secureScreen: host,
        child: TdsSecureScreenScope(enabled: enabled, child: const SizedBox()),
      );
      await tester.pumpWidget(view(first, true));
      await tester.pump();
      await tester.pumpWidget(view(second, true));
      await tester.pumpWidget(view(second, false));
      expect(first.calls, ['enable']);
      expect(second.calls, isEmpty);
      first.pendingEnable.complete();
      await tester.pump();
      expect(first.calls, ['enable', 'disable']);
      expect(second.calls, ['enable']);
      second.pendingEnable.complete();
      await tester.pump();
      expect(second.calls, ['enable', 'disable']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(second.calls, ['enable', 'disable']);
    },
  );

  testWidgets(
    'secure host enable failure is reported and does not skip queued cleanup',
    (tester) async {
      final secure = FakeSecure();
      await tester.pumpWidget(
        TdsHostProvider(
          secureScreen: secure,
          child: const TdsSecureScreenScope(child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      secure.pendingEnable.completeError(
        StateError('native host rejected enable'),
      );
      await tester.pump();
      expect(tester.takeException(), isA<StateError>());
      expect(secure.calls, ['enable', 'disable']);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'navigation luminance uses original weighted bytes, including ignored alpha',
    () {
      expect(
        getNavTypeByBackgroundColor(const Color(0xff808080)),
        TdsNavigationTextType.darkText,
      );
      expect(
        getNavTypeByBackgroundColor(const Color(0xff7f7f7f)),
        TdsNavigationTextType.lightText,
      );
      expect(
        getNavTypeByBackgroundColor(const Color(0x00ffffff)),
        TdsNavigationTextType.darkText,
      );
      expect(
        getNavTypeByBackgroundColor(const Color(0xff00ff00)),
        TdsNavigationTextType.darkText,
      );
      expect(
        getTopOffsetInMobile(
          os: TdsOS.android,
          hasWebNav: true,
          pureSafeAreaTop: 44,
        ),
        0,
      );
      expect(
        getTopOffsetInMobile(
          os: TdsOS.ios,
          hasWebNav: true,
          pureSafeAreaTop: 44,
        ),
        44,
      );
    },
  );
  testWidgets(
    'layout hooks distinguish native insets from keyboard and themed backgrounds',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 800),
              viewPadding: EdgeInsets.only(top: 44, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: TdsTheme(
              data: const TdsThemeData(
                colorScheme: TdsColorPreference.dark,
                platform: TdsPlatform(os: TdsOS.android),
              ),
              child: Builder(
                builder: (context) {
                  expect(useTopNavigationHeight(context), 54);
                  expect(
                    useTopNavigationHeight(context, withSafeAreaTop: true),
                    98,
                  );
                  expect(
                    useTopNavigationHeight(
                      context,
                      withSafeAreaTop: true,
                      height: 70,
                    ),
                    114,
                  );
                  expect(
                    useBackgroundStyle(
                      context,
                      background: TdsBackground.grey100,
                    ).color,
                    TdsTheme.of(context).color('grey50'),
                  );
                  expect(TdsFixedBottomMetrics.of(context).bottom, 300);
                  expect(
                    TdsFixedBottomMetrics.of(
                      context,
                      enabled: false,
                    ).isKeyboardOpen,
                    isFalse,
                  );
                  expect(TdsViewport.of(context).height, 500);
                  expect(safeAreaInsetBottom(context), 34);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
    },
  );
  testWidgets(
    'secure host enable then disable stays ordered across async unmount',
    (tester) async {
      final secure = FakeSecure();
      await tester.pumpWidget(
        TdsHostProvider(
          secureScreen: secure,
          child: const TdsSecureScreenScope(child: SizedBox()),
        ),
      );
      await tester.pump();
      expect(secure.calls, ['enable']);
      await tester.pumpWidget(const SizedBox());
      expect(secure.calls, ['enable']);
      secure.pendingEnable.complete();
      await tester.pump();
      expect(secure.calls, ['enable', 'disable']);
      await tester.pumpWidget(const TdsSecureScreenScope(child: SizedBox()));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('accessory host replacement and disposal remove the old button', (
    tester,
  ) async {
    final navigation = FakeNavigation();
    Widget scope(String title) => TdsHostProvider(
      navigation: navigation,
      child: TdsAccessoryButtonScope(
        button: TdsAccessoryTextButton(title: title, callback: () {}),
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(scope('첫째'));
    await tester.pumpWidget(scope('둘째'));
    await tester.pumpWidget(const SizedBox());
    expect(navigation.calls, ['첫째', 'remove', '둘째', 'remove']);
  });
  testWidgets(
    'scroll direction keeps strict threshold and trailing 50ms sampling',
    (tester) async {
      final scroll = ScrollController();
      final direction = TdsScrollingDirectionController(scroll, threshold: 10);
      await tester.pumpWidget(
        fieldApp(
          SingleChildScrollView(
            controller: scroll,
            child: const SizedBox(width: 300, height: 3000),
          ),
        ),
      );
      scroll.jumpTo(10);
      expect(direction.value, isNull);
      scroll.jumpTo(11);
      await tester.pump(const Duration(milliseconds: 50));
      expect(direction.value, TdsScrollingDirection.down);
      scroll.jumpTo(2);
      expect(direction.value, TdsScrollingDirection.down);
      scroll.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(direction.value, TdsScrollingDirection.up);
      direction.dispose();
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
  );
}
