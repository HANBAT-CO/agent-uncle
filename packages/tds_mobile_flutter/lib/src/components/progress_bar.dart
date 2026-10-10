import 'package:flutter/widgets.dart';
import '../foundation/css_transition.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.g.dart';

enum TdsProgressBarSize {
  light(2, 2.5),
  normal(5, 2.5),
  bold(8, 4);

  const TdsProgressBarSize(this.height, this.radius);
  final double height, radius;
}

class TdsProgressBar extends StatefulWidget {
  const TdsProgressBar({
    required this.progress,
    this.size = TdsProgressBarSize.normal,
    this.color = TdsPalette.blue400,
    this.animate = false,
    this.semanticLabel,
    super.key,
  });

  /// Fractional progress. Like the source, out-of-range values are translated
  /// without clamping and the track clips the filler to its visible bounds.
  final double progress;
  final TdsProgressBarSize size;
  final Color color;

  /// Only controls the initial animation. Subsequent changes always animate.
  final bool animate;
  final String? semanticLabel;
  @override
  State<TdsProgressBar> createState() => _TdsProgressBarState();
}

class _TdsProgressBarState extends State<TdsProgressBar>
    with SingleTickerProviderStateMixin {
  late bool _ready = !widget.animate;
  late final TdsCssTransition _transition;
  @override
  void initState() {
    super.initState();
    _transition = TdsCssTransition(
      vsync: this,
      value: _ready ? widget.progress : 0,
      baseDuration: const Duration(milliseconds: 500),
    );
    if (!_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ready = true;
        _transition.animateTo(widget.progress);
      });
    }
  }

  @override
  void didUpdateWidget(TdsProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready) _transition.animateTo(widget.progress);
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  String get _percentage {
    final value = widget.progress * 100;
    return '${value == value.truncateToDouble() ? value.toStringAsFixed(0) : value.toString()}%';
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    value: _percentage,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(widget.size.radius),
      child: ColoredBox(
        color: TdsTheme.of(context).color('grey200'),
        child: SizedBox(
          height: widget.size.height,
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _transition,
              builder: (context, child) => Stack(
                children: [
                  Positioned(
                    left: (_transition.value - 1) * constraints.maxWidth,
                    top: 0,
                    bottom: 0,
                    width: constraints.maxWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(widget.size.radius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
