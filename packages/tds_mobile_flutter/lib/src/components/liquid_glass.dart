import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import 'badge.dart';
import 'icon_button.dart';
import 'text_button.dart';

/// Opt-in host adapter, separate from the reference TDS controls. The iOS host
/// registers tds/liquid_glass; unsupported hosts use the existing TDS controls.
class TdsLiquidGlass {
  TdsLiquidGlass._();
  static Future<bool>? _availability;
  static Future<bool> get available {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return Future.value(false);
    }
    return _availability ??= _resolve();
  }

  static Future<bool> _resolve() async {
    try {
      return await const MethodChannel(
            'tds/liquid_glass/capabilities',
          ).invokeMethod<bool>('available') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

@immutable
class TdsLiquidTab {
  const TdsLiquidTab({
    required this.label,
    required this.symbol,
    required this.icon,
    this.badge = 0,
  });
  final String label;

  /// SF Symbol used only by Apple's system tab bar.
  final String symbol;
  final Widget icon;
  final int badge;
}

/// Apple's system tab bar on supported iOS hosts; a TDS composition elsewhere.
/// Selection is committed only after [onSelected] approves it (e.g. draft save).
class TdsLiquidTabBar extends StatelessWidget {
  const TdsLiquidTabBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.fontAsset,
    super.key,
  }) : assert(items.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < items.length);
  final List<TdsLiquidTab> items;
  final int selectedIndex;
  final Future<bool> Function(int) onSelected;
  final String? fontAsset;

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    // Native tab labels use their system metrics; enlarged TDS fallbacks grow.
    final height = 76.0 + (theme.platform.fontScale - 100).clamp(0, 100) * .24;
    return SizedBox(
      height: height,
      child: _AppleGlassControl(
        parameters: {
          'kind': 'tabs',
          'selected': selectedIndex,
          'tint': theme.color('blue600').toARGB32(),
          'fontAsset': fontAsset,
          'items': [
            for (final item in items)
              {'label': item.label, 'symbol': item.symbol, 'badge': item.badge},
          ],
        },
        onEvent: (call) async {
          if (call.method != 'select') return null;
          final index = call.arguments;
          if (index is! int || index < 0 || index >= items.length) return false;
          return onSelected(index);
        },
        fallback: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _GlassMaterial(
            radius: 32,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    start:
                        constraints.maxWidth / items.length * selectedIndex + 4,
                    top: 4,
                    bottom: 4,
                    width: constraints.maxWidth / items.length - 8,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.color('primary').withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: selectedIndex == i,
                            label: items[i].badge > 0
                                ? '${items[i].label}, 알림 ${items[i].badge}개'
                                : items[i].label,
                            child: TdsTextButton(
                              size: TdsTextButtonSize.xsmall,
                              colorToken: selectedIndex == i
                                  ? 'blue600'
                                  : 'grey600',
                              onPressed: () => onSelected(i),
                              child: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        items[i].icon,
                                        if (items[i].badge > 0)
                                          PositionedDirectional(
                                            top: -6,
                                            end: -10,
                                            child: TdsBadge(
                                              size: TdsBadgeSize.xsmall,
                                              color: TdsBadgeColor.red,
                                              variant: TdsBadgeVariant.fill,
                                              child: Text('${items[i].badge}'),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(items[i].label, maxLines: 1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard UIButton.Configuration.glass on iOS. No custom lens or shader.
class TdsGlassIconButton extends StatelessWidget {
  const TdsGlassIconButton({
    required this.semanticLabel,
    required this.symbol,
    required this.icon,
    required this.onPressed,
    this.unreadCount = 0,
    super.key,
  });
  final String semanticLabel, symbol;
  final Widget icon;
  final VoidCallback onPressed;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 0
        ? '$semanticLabel, 읽지 않은 알림 $unreadCount개'
        : semanticLabel;
    return SizedBox.square(
      dimension: 48,
      child: _AppleGlassControl(
        parameters: {
          'kind': 'button',
          'label': label,
          'symbol': symbol,
          'unread': unreadCount,
          'tint': TdsTheme.of(context).color('grey900').toARGB32(),
        },
        onEvent: (call) async {
          if (call.method == 'press') onPressed();
          return null;
        },
        fallback: _GlassMaterial(
          radius: 24,
          child: Stack(
            children: [
              TdsIconButton(
                semanticLabel: label,
                onPressed: onPressed,
                child: icon,
              ),
              if (unreadCount > 0)
                PositionedDirectional(
                  top: 7,
                  end: 7,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: TdsTheme.of(context).color('red500'),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMaterial extends StatelessWidget {
  const _GlassMaterial({required this.child, required this.radius});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final opaque = MediaQuery.highContrastOf(context);
    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.color('cardBgWhite').withValues(alpha: opaque ? 1 : .78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: opaque ? theme.color('grey900') : const Color(0xCCFFFFFF),
        ),
      ),
      child: child,
    );
    if (!opaque) {
      result = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: result,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: result,
    );
  }
}

class _AppleGlassControl extends StatefulWidget {
  const _AppleGlassControl({
    required this.parameters,
    required this.onEvent,
    required this.fallback,
  });
  final Map<String, Object?> parameters;
  final Future<Object?> Function(MethodCall) onEvent;
  final Widget fallback;
  @override
  State<_AppleGlassControl> createState() => _AppleGlassControlState();
}

class _AppleGlassControlState extends State<_AppleGlassControl> {
  bool native = false;
  MethodChannel? channel;
  @override
  void initState() {
    super.initState();
    TdsLiquidGlass.available.then((value) {
      if (mounted && value) setState(() => native = true);
    });
  }

  @override
  void didUpdateWidget(covariant _AppleGlassControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  Future<void> _sync() async {
    try {
      await channel?.invokeMethod<void>('update', widget.parameters);
    } on PlatformException {
      if (mounted) setState(() => native = false);
    } on MissingPluginException {
      if (mounted) setState(() => native = false);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => native
      ? UiKitView(
          viewType: 'tds/liquid_glass',
          layoutDirection: Directionality.of(context),
          creationParams: widget.parameters,
          creationParamsCodec: const StandardMessageCodec(),
          // Let UIKit own its press, hold and tab-scrubbing recognizers.
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onPlatformViewCreated: (id) {
            if (!mounted) return;
            channel = MethodChannel('tds/liquid_glass/$id')
              ..setMethodCallHandler((call) => widget.onEvent(call));
            _sync();
          },
        )
      : widget.fallback;
}
