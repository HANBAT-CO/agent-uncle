import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

class RecordingToast implements TdsHostToast {
  final requests = <(String, TdsHostToastOptions)>[];
  @override
  void show(String message, TdsHostToastOptions options) =>
      requests.add((message, options));
}

void main() {
  testWidgets('top hook ignores action surface but preserves action duration', (
    tester,
  ) async {
    final controller = TdsToastController();
    await tester.pumpWidget(
      fieldApp(
        TdsToastProvider.web(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      ),
    );
    controller.openToast(
      'top',
      options: TdsToastOptions(
        position: TdsToastPosition.top,
        action: TdsToastAction(text: 'hidden action', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hidden action'), findsNothing);
    expect(
      tester.widget<TdsToast>(find.byType(TdsToast)).duration,
      const Duration(seconds: 5),
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Toast.Icon merges partial frame with its 24px source defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      fieldApp(
        const Center(
          child: TdsToastIcon(
            name: 'icn-delete',
            frameShape: TdsAssetFrameShape(width: 32, radius: 9),
          ),
        ),
      ),
    );
    final shape = tester
        .widget<TdsAssetIcon>(find.byType(TdsAssetIcon))
        .frameShape!;
    expect(shape.width, 32);
    expect(shape.height, 24);
    expect(shape.radius, 9);
  });
  testWidgets(
    'native host receives source placement precedence and safe area',
    (tester) async {
      final source =
          (jsonDecode(
                    File(
                      'reference/compound-constants.json',
                    ).readAsStringSync(),
                  )
                  as Map)['hostToastOffsets']
              as Map;
      final native = RecordingToast();
      final controller = TdsToastController();
      for (final os in [TdsOS.android, TdsOS.ios]) {
        await tester.pumpWidget(
          fieldApp(
            Builder(
              builder: (context) => TdsTheme(
                data: TdsTheme.of(
                  context,
                ).copyWith(platform: TdsPlatform(os: os)),
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(padding: const EdgeInsets.only(bottom: 34)),
                  child: TdsHostProvider(
                    toast: native,
                    child: TdsToastProvider(
                      controller: controller,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        controller.openToast('default');
        expect(native.requests.last.$2.bottom, isNull);
        controller.openToast(
          'bottom',
          options: const TdsToastOptions(higherThanCTA: false),
        );
        expect(native.requests.last.$2.bottom, 34 + source['bottom']);
        controller.openToast(
          'above CTA',
          options: const TdsToastOptions(higherThanCTA: true),
        );
        expect(
          native.requests.last.$2.bottom,
          34 + source['bottom'] + source['ctaHeight'] + source['ctaGap'],
        );
        controller.openToast(
          'gap wins',
          options: const TdsToastOptions(higherThanCTA: true, gap: 0),
        );
        expect(native.requests.last.$2.bottom, 0);
        controller.openToast(
          'top default',
          options: const TdsToastOptions(position: TdsToastPosition.top),
        );
        expect(native.requests.last.$2.top, os == TdsOS.android ? 26 : 46);
        controller.openToast(
          'top zero',
          options: const TdsToastOptions(
            position: TdsToastPosition.top,
            gap: 0,
          ),
        );
        expect(native.requests.last.$2.top, os == TdsOS.android ? 26 : 46);
        controller.openToast(
          'top gap',
          options: const TdsToastOptions(
            position: TdsToastPosition.top,
            gap: 70,
          ),
        );
        expect(native.requests.last.$2.top, 70);
        await tester.pumpAndSettle();
        expect(find.byType(TdsToast), findsNothing);
        expect(controller.isOpen, isFalse); // The host has no observable state.
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'host options retain action and duration, web provider bypasses host',
    (tester) async {
      final native = RecordingToast();
      final controller = TdsToastController();
      var actions = 0;
      final action = TdsToastAction(text: 'undo', onPressed: () => actions++);
      Widget app(bool web) => fieldApp(
        TdsHostProvider(
          toast: native,
          child: web
              ? TdsToastProvider.web(
                  controller: controller,
                  child: const SizedBox.expand(),
                )
              : TdsToastProvider(
                  controller: controller,
                  child: const SizedBox.expand(),
                ),
        ),
      );
      await tester.pumpWidget(app(false));
      final options = TdsToastOptions(
        icon: 'icn-delete',
        iconType: TdsToastIconType.circle,
        action: action,
        duration: const Duration(seconds: 8),
      );
      controller.openToast('native', options: options);
      final request = native.requests.single;
      expect(request.$1, 'native');
      expect(request.$2.icon, 'icn-delete');
      expect(request.$2.iconType, TdsToastIconType.circle);
      expect(request.$2.duration, const Duration(seconds: 8));
      request.$2.button!.onPressed();
      expect(actions, 1);
      await tester.pumpWidget(app(true));
      controller.openToast('web', options: options);
      await tester.pumpAndSettle();
      expect(native.requests.length, 1);
      expect(find.text('web'), findsOneWidget);
      final icon = tester.widget<TdsToastIcon>(find.byType(TdsToastIcon));
      expect(icon.frameShape.radius, 9999);
      expect(icon.frameShape.width, 24);
      await tester.tap(find.text('undo'));
      await tester.pumpAndSettle();
      expect(actions, 2);
      expect(controller.isOpen, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'explicit null ToastContext shadows host and is not controller context',
    (tester) async {
      final native = RecordingToast();
      final controller = TdsToastController();
      TdsHostToast? seen;
      Widget app(bool shadow) => fieldApp(
        TdsHostProvider(
          toast: native,
          child: TdsToastContextProvider(
            value: shadow ? null : native,
            child: TdsToastProvider(
              controller: controller,
              child: Builder(
                builder: (context) {
                  seen = useToastContext(context);
                  expect(TdsToastProvider.of(context), same(controller));
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(false));
      expect(seen, same(native));
      await tester.pumpWidget(app(true));
      expect(seen, isNull);
      controller.openToast('fallback');
      await tester.pumpAndSettle();
      expect(native.requests, isEmpty);
      expect(find.text('fallback'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  test(
    'hook options enforce the icon/lottie union and adapt addon defaults',
    () {
      expect(
        () => TdsToastOptions(icon: 'a', lottie: 'b'),
        throwsAssertionError,
      );
      expect(
        () => TdsToastOptions(iconType: TdsToastIconType.circle, lottie: 'b'),
        throwsAssertionError,
      );
      final animation =
          const TdsToastOptions(lottie: 'asset.json').resolvedAddon
              as TdsToastLottie;
      expect(animation.src, 'asset.json');
      expect(animation.frameShape.width, 24);
      expect(animation.frameShape.height, 24);
      final icon =
          const TdsToastOptions(icon: 'a').resolvedAddon as TdsToastIcon;
      expect(icon.frameShape.radius, 0);
      expect(const TdsToastOptions(icon: '').resolvedAddon, isNull);
      expect(const TdsToastOptions(lottie: '').resolvedAddon, isNull);
    },
  );
}
