import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';
import 'text.dart';

enum TdsLoaderSize { small, medium, large }

enum TdsLoaderType { primary, dark, light }

class TdsLoader extends StatefulWidget {
  const TdsLoader({
    this.size = TdsLoaderSize.medium,
    this.type = TdsLoaderType.primary,
    this.label,
    super.key,
  });
  final TdsLoaderSize size;
  final TdsLoaderType type;
  final String? label;
  @override
  State<TdsLoader> createState() => _TdsLoaderState();
}

class _TdsLoaderState extends State<TdsLoader>
    with SingleTickerProviderStateMixin {
  static int _nextLoadingId = 0;
  late final _loadingId = 'tds-loader-${_nextLoadingId++}';
  TdsGlobalConfigContext? _config;
  bool _registered = false;
  late final AnimationController _fade;
  late final Animation<double> _opacity;
  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _opacity = _fade.drive(
      CurveTween(curve: const Interval(.7, 1, curve: Curves.easeInOut)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registered = true;
      _config?.onLoadingStarted?.call(_loadingId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Yoe captures the original ID but reads the latest context at cleanup.
    _config = TdsGlobalConfigProvider.maybeOf(context);
  }

  @override
  void dispose() {
    if (_registered) {
      final finish = _config?.onLoadingFinish;
      final id = _loadingId;
      WidgetsBinding.instance.addPostFrameCallback((_) => finish?.call(id));
    }
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final hasLabel = widget.label?.isNotEmpty ?? false;
    final color = switch (widget.type) {
      TdsLoaderType.primary => const Color(0xff3188ff),
      TdsLoaderType.dark => TdsPalette.grey600,
      TdsLoaderType.light => TdsPalette.white,
    };
    final labelColor = switch (widget.type) {
      TdsLoaderType.primary => theme.color('grey800'),
      TdsLoaderType.dark => TdsPalette.grey800,
      TdsLoaderType.light => TdsPalette.whiteOpacity800,
    };
    return Semantics(
      label: hasLabel ? widget.label : '로딩 중',
      image: !hasLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(
                  widget.size == TdsLoaderSize.large ? 16 : 12,
                ),
                child: TdsLoaderAnimation(
                  size: switch (widget.size) {
                    TdsLoaderSize.small => 24,
                    TdsLoaderSize.medium => 36,
                    TdsLoaderSize.large => 48,
                  },
                  color: color,
                ),
              ),
              if (hasLabel)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TdsText(
                    widget.label!,
                    typography: TdsTypography.t6,
                    color: labelColor,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TdsLoaderAnimation extends StatefulWidget {
  const TdsLoaderAnimation({
    this.size = 48,
    this.color = const Color(0xff3188ff),
    super.key,
  });
  final double size;
  final Color color;
  @override
  State<TdsLoaderAnimation> createState() => _TdsLoaderAnimationState();
}

class _TdsLoaderAnimationState extends State<TdsLoaderAnimation>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(painter: _LoaderPainter(_controller, widget.color)),
    ),
  );
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.animation, this.color) : super(repaint: animation);
  final Animation<double> animation;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final progress = Curves.easeInOut.transform(
      phase < .5 ? phase * 2 : (phase - .5) * 2,
    );
    final dashOffset = phase < .5 ? 180 - 135 * progress : 45 + 135 * progress;
    final turn = phase < .5 ? 108 * progress : 108 + 252 * progress;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(phase * math.pi * 2 + turn * math.pi / 180);
    final radius = size.width * 30 / 66;
    final circumference = math.pi * 60;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 6 / 66
      ..strokeCap = StrokeCap.round;
    // SVG dasharray=180 repeats [180,180] around a circumference of 188.5.
    for (var start = -dashOffset; start < circumference; start += 360) {
      final from = math.max(0.0, start),
          to = math.min(circumference, start + 180);
      if (to > from) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          from / 30,
          (to - from) / 30,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter oldDelegate) =>
      color != oldDelegate.color || animation != oldDelegate.animation;
}
