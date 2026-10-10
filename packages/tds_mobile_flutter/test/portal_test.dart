import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'text_field_test.dart' show fieldApp;

void main() {
  testWidgets('context Consumer is inline, nullable and shadows outer scope', (
    tester,
  ) async {
    Widget consumer() => TdsPortalContextConsumer(
      builder: (_, value) => Text(value == null ? 'null' : 'target'),
    );
    await tester.pumpWidget(fieldApp(consumer()));
    expect(find.text('null'), findsOneWidget);
    await tester.pumpWidget(fieldApp(TdsPortalProvider(child: consumer())));
    expect(find.text('target'), findsOneWidget);
    await tester.pumpWidget(
      fieldApp(
        TdsPortalProvider(
          child: TdsPortalContextProvider(value: null, child: consumer()),
        ),
      ),
    );
    expect(find.text('null'), findsOneWidget);
  });

  testWidgets('explicit target beats nearest Overlay and migrates on changes', (
    tester,
  ) async {
    final mode = ValueNotifier<int>(0);
    late OverlayState root;
    const marker = Key('marker');
    await tester.pumpWidget(
      fieldApp(
        Builder(
          builder: (context) {
            root = Overlay.of(context);
            return SizedBox(
              width: 200,
              height: 100,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => ValueListenableBuilder<int>(
                      valueListenable: mode,
                      builder: (context, value, _) => TdsPortalContextProvider(
                        value: value == 2
                            ? null
                            : TdsPortalContext(
                                value == 0 ? root : Overlay.of(context),
                              ),
                        child: TdsPortalConsumer(
                          visible: value != 3,
                          child: const Positioned(
                            right: 0,
                            bottom: 0,
                            child: SizedBox(key: marker, width: 20, height: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byKey(marker)), const Offset(800, 600));
    mode.value = 1;
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byKey(marker)), const Offset(500, 350));
    mode.value = 2;
    await tester.pumpAndSettle();
    expect(find.byKey(marker), findsNothing);
    mode.value = 0;
    await tester.pumpAndSettle();
    expect(find.byKey(marker), findsOneWidget);
    mode.value = 3;
    await tester.pumpAndSettle();
    expect(find.byKey(marker), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mode.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portal carries TDS theme, text style, direction and media updates',
    (tester) async {
      final color = ValueNotifier<Color>(const Color(0xffff0000));
      TdsThemeData? observed;
      TextDirection? direction;
      TextScaler? scaler;
      TextStyle? textStyle;
      Widget content() => Builder(
        builder: (context) {
          observed = TdsTheme.of(context);
          direction = Directionality.of(context);
          scaler = MediaQuery.textScalerOf(context);
          textStyle = DefaultTextStyle.of(context).style;
          return const Positioned(top: 0, child: Text('portal'));
        },
      );
      await tester.pumpWidget(
        fieldApp(
          ValueListenableBuilder<Color>(
            valueListenable: color,
            builder: (context, value, _) => TdsTheme(
              data: TdsTheme.of(context).copyWith(primary: value),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 27),
                  child: TdsPortalProvider(
                    child: TdsPortalConsumer(child: content()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(observed!.primary, color.value);
      expect(direction, TextDirection.rtl);
      expect(scaler, TextScaler.noScaling);
      expect(textStyle!.fontSize, 27);
      color.value = const Color(0xff0000ff);
      await tester.pumpAndSettle();
      expect(observed!.primary, color.value);
      await tester.pumpWidget(const SizedBox());
      color.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
