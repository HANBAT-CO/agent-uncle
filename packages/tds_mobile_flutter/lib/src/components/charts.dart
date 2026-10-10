import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'text.dart';

@immutable
class TdsDoughnutData {
  const TdsDoughnutData({
    required this.value,
    required this.color,
    this.label,
    this.semanticLabel,
  }) : assert(value >= 0);
  final double value;
  final Color color;
  final Widget? label;
  final String? semanticLabel;
}

class TdsDoughnut extends StatefulWidget {
  const TdsDoughnut({
    required this.size,
    required this.thickness,
    required this.data,
    this.backgroundColor,
    required this.show,
    super.key,
  }) : assert(size > 0),
       assert(thickness > 0 && thickness <= size);
  final double size, thickness;
  final List<TdsDoughnutData> data;
  final Color? backgroundColor;
  final bool show;
  @override
  State<TdsDoughnut> createState() => _TdsDoughnutState();
}

class _TdsDoughnutState extends State<TdsDoughnut>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: TdsMotion.basic.duration,
  );
  @override
  void initState() {
    super.initState();
    if (widget.show) _animation.forward();
  }

  @override
  void didUpdateWidget(TdsDoughnut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      widget.show ? _animation.forward() : _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '도넛 차트',
    value: widget.data
        .map((d) => '${d.semanticLabel ?? ''}: ${d.value}')
        .join(', '),
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _DoughnutPainter(
            widget.data,
            widget.thickness,
            widget.backgroundColor ?? TdsTheme.of(context).color('grey100'),
            _animation,
          ),
        ),
      ),
    ),
  );
}

class _DoughnutPainter extends CustomPainter {
  _DoughnutPainter(this.data, this.thickness, this.background, this.animation)
    : super(repaint: animation);
  final List<TdsDoughnutData> data;
  final double thickness;
  final Color background;
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - thickness) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = background;
    canvas.drawOval(rect, paint);
    final total = data.fold(0.0, (v, d) => v + d.value);
    if (!total.isFinite || total <= 0) return;
    final reveal =
        TdsMotion.basic.transform(animation.value).clamp(0.0, 1.0) *
        359.9 *
        math.pi /
        180;
    var start = 0.0;
    for (final item in data) {
      final sweep = item.value / total * math.pi * 2;
      final visible = math.max(0.0, math.min(start + sweep, reveal) - start);
      if (visible > 0) {
        canvas.drawArc(
          rect,
          start - math.pi / 2,
          visible,
          false,
          paint..color = item.color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DoughnutPainter oldDelegate) =>
      data != oldDelegate.data ||
      thickness != oldDelegate.thickness ||
      background != oldDelegate.background;
}

class TdsDoughnutLabel extends StatelessWidget {
  const TdsDoughnutLabel({required this.labels, super.key});
  final List<TdsDoughnutData> labels;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: labels[i].color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: DefaultTextStyle(
                style: TdsTheme.of(
                  context,
                ).textStyle(color: TdsTheme.of(context).color('grey700')),
                child: labels[i].label ?? const SizedBox(),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

enum TdsDoughnutLabelPosition { top, bottom, right, left }

class TdsDoughnutChart extends StatelessWidget {
  const TdsDoughnutChart({
    required this.data,
    this.size = 150,
    this.thickness = 40,
    this.backgroundColor,
    this.showLabel = true,
    this.labelPosition = TdsDoughnutLabelPosition.right,
    this.show = true,
    super.key,
  });
  final List<TdsDoughnutData> data;
  final double size, thickness;
  final Color? backgroundColor;
  final bool showLabel, show;
  final TdsDoughnutLabelPosition labelPosition;
  @override
  Widget build(BuildContext context) {
    final chart = TdsDoughnut(
      size: size,
      thickness: thickness,
      data: data,
      backgroundColor: backgroundColor,
      show: show,
    );
    if (!showLabel) return chart;
    final label = Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TdsDoughnutLabel(labels: data),
    );
    final reverse =
        labelPosition == TdsDoughnutLabelPosition.left ||
        labelPosition == TdsDoughnutLabelPosition.top;
    final vertical =
        labelPosition == TdsDoughnutLabelPosition.top ||
        labelPosition == TdsDoughnutLabelPosition.bottom;
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          reverse ? label : chart,
          const SizedBox(height: 24),
          reverse ? chart : label,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reverse) Flexible(child: label) else chart,
        const SizedBox(width: 24),
        if (reverse) chart else Flexible(child: label),
      ],
    );
  }
}

enum TdsBarTheme { blue, green, yellow, orange, red, grey, neutral }

class TdsBarItem {
  const TdsBarItem({
    required this.value,
    this.maxValue,
    this.label,
    this.theme,
    this.barAnnotation,
  }) : assert(value >= 0);
  final double value;
  final double? maxValue;
  final String? label, barAnnotation;
  final TdsBarTheme? theme;
}

sealed class TdsBarChartFill {
  const TdsBarChartFill();
  TdsBarTheme themeFor(int index, int length);
}

class TdsAllBarFill extends TdsBarChartFill {
  const TdsAllBarFill(this.theme);
  final TdsBarTheme theme;
  @override
  TdsBarTheme themeFor(int index, int length) => theme;
}

class TdsSingleBarFill extends TdsBarChartFill {
  const TdsSingleBarFill({required this.barIndex, required this.theme});
  final int barIndex;
  final TdsBarTheme theme;
  @override
  TdsBarTheme themeFor(int index, int length) =>
      index == barIndex ? theme : TdsBarTheme.neutral;
}

class TdsAutoBarFill extends TdsBarChartFill {
  const TdsAutoBarFill({required this.count}) : assert(count >= 0);
  final int count;
  @override
  TdsBarTheme themeFor(int index, int length) => length - index - 1 < count
      ? TdsBarTheme.values[(length - index - 1) % 6]
      : TdsBarTheme.neutral;
}

class TdsBarChart extends StatelessWidget {
  const TdsBarChart({
    required this.data,
    required this.fill,
    this.height = 205,
    super.key,
  }) : assert(height > 24);
  final List<TdsBarItem> data;
  final TdsBarChartFill fill;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);
    final theme = TdsTheme.of(context);
    final maxValue = data.fold(0.0, (max, item) => math.max(max, item.value));
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, data.length * 58.0);
            final radius =
                ((constraints.maxWidth / data.length * 38 / 58) / 5 + 2)
                    .floorToDouble()
                    .clamp(3.0, 8.0);
            return Center(
              child: SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < data.length; i++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final item = data[i],
                                ink =
                                    item.theme ?? fill.themeFor(i, data.length);
                            final max = item.maxValue ?? maxValue;
                            final barHeight = max > 0
                                ? (height - 24) *
                                      .7 *
                                      (item.value / max).clamp(0.0, 1.0)
                                : 0.0;
                            final start = switch (ink) {
                              TdsBarTheme.green => 'green200',
                              TdsBarTheme.grey => 'grey400',
                              _ => '${ink.name}300',
                            };
                            final end = ink == TdsBarTheme.green
                                ? 'green400'
                                : '${ink.name}500';
                            return Semantics(
                              label: item.label,
                              value: '${item.value}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (data.length <= 12 &&
                                      item.barAnnotation != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: TdsText(
                                        item.barAnnotation!,
                                        typography: TdsTypography.st12,
                                        fontWeight: TdsFontWeight.semibold,
                                        color: theme.color(
                                          ink == TdsBarTheme.neutral
                                              ? 'grey600'
                                              : '${ink.name}600',
                                        ),
                                        ellipsisAfterLines: 1,
                                      ),
                                    ),
                                  FractionallySizedBox(
                                    widthFactor: 38 / 58,
                                    child: Container(
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: ink == TdsBarTheme.neutral
                                            ? theme.color('grey100')
                                            : null,
                                        borderRadius: BorderRadius.circular(
                                          radius,
                                        ),
                                        gradient: ink == TdsBarTheme.neutral
                                            ? null
                                            : RadialGradient(
                                                center: Alignment.bottomLeft,
                                                radius: 1,
                                                colors: [
                                                  theme.color(start),
                                                  theme.color(end),
                                                ],
                                                stops: const [0, .66],
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 16.5,
                                    child:
                                        data.length > 12 &&
                                            i != 0 &&
                                            i != data.length - 1
                                        ? null
                                        : TdsText(
                                            item.label ?? '',
                                            typography: TdsTypography.st13,
                                            fontWeight: TdsFontWeight.medium,
                                            color: theme.color('grey600'),
                                            ellipsisAfterLines: 1,
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
