import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../foundation/host.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import 'asset.dart';
import 'button.dart';
import 'loader.dart';
import 'text.dart';

class TdsFadeIn extends StatefulWidget {
  const TdsFadeIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.onEnd,
    super.key,
  });
  final Widget child;
  final Duration delay, duration;
  final VoidCallback? onEnd;
  @override
  State<TdsFadeIn> createState() => _TdsFadeInState();
}

class _TdsFadeInState extends State<TdsFadeIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _delay;
  @override
  void initState() {
    super.initState();
    _delay = Timer(widget.delay, () {
      if (mounted) {
        _controller.forward().whenCompleteOrCancel(() {
          if (mounted && _controller.isCompleted) widget.onEnd?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller.drive(CurveTween(curve: TdsMotion.out)),
    child: widget.child,
  );
}

class TdsLoadingCompleteView extends StatefulWidget {
  const TdsLoadingCompleteView({
    required this.child,
    this.fadeIn = false,
    super.key,
  });
  final Widget child;
  final bool fadeIn;
  @override
  State<TdsLoadingCompleteView> createState() => _TdsLoadingCompleteViewState();
}

class _TdsLoadingCompleteViewState extends State<TdsLoadingCompleteView> {
  TdsHostSkeleton? _host;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = tdsSkeletonOf(context);
    if (host != _host) {
      _host = host;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _host == host) host?.remove();
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.fadeIn ? TdsFadeIn(child: widget.child) : widget.child;
}

/// Put this in the route's full-screen Stack. It blocks interactions below it.
class TdsFullScreenLoader extends StatelessWidget {
  const TdsFullScreenLoader({
    this.label,
    this.loaderType = TdsLoaderType.primary,
    this.loaderSize = TdsLoaderSize.medium,
    this.onDimmerClick,
    super.key,
  });
  final String? label;
  final TdsLoaderType loaderType;
  final TdsLoaderSize loaderSize;
  final VoidCallback? onDimmerClick;
  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDimmerClick,
      child: ColoredBox(
        color: TdsTheme.of(context).color('background'),
        child: Center(
          child: TdsLoader(label: label, type: loaderType, size: loaderSize),
        ),
      ),
    ),
  );
}

enum TdsSkeletonPattern {
  topList,
  topListWithIcon,
  amountTopList,
  amountTopListWithIcon,
  subtitleList,
  subtitleListWithIcon,
  listOnly,
  listWithIconOnly,
  cardOnly,
}

enum TdsSkeletonModule { title, subtitle, list, listWithIcon, card }

enum TdsSkeletonBackground { white, grey, greyOpacity100 }

class TdsSkeletonPart {
  const TdsSkeletonPart(this.module) : spacer = null;
  const TdsSkeletonPart.spacer(double height) : spacer = height, module = null;
  final TdsSkeletonModule? module;
  final double? spacer;
}

class TdsSkeleton extends StatelessWidget {
  const TdsSkeleton({
    this.height,
    this.pattern = TdsSkeletonPattern.topList,
    this.custom,
    this.repeatLastItemCount = 3,
    this.infinite = false,
    this.show = true,
    this.background = TdsSkeletonBackground.grey,
    super.key,
  }) : assert(repeatLastItemCount >= 0);
  final double? height;
  final TdsSkeletonPattern pattern;
  final List<TdsSkeletonPart>? custom;
  final int repeatLastItemCount;
  final bool infinite, show;
  final TdsSkeletonBackground background;
  List<TdsSkeletonPart> get parts {
    const title = TdsSkeletonPart(TdsSkeletonModule.title),
        subtitle = TdsSkeletonPart(TdsSkeletonModule.subtitle);
    final icon = {
      TdsSkeletonPattern.topListWithIcon,
      TdsSkeletonPattern.amountTopListWithIcon,
      TdsSkeletonPattern.subtitleListWithIcon,
      TdsSkeletonPattern.listWithIconOnly,
    }.contains(pattern);
    final list = TdsSkeletonPart(
      icon ? TdsSkeletonModule.listWithIcon : TdsSkeletonModule.list,
    );
    return custom ??
        switch (pattern) {
          TdsSkeletonPattern.topList || TdsSkeletonPattern.topListWithIcon => [
            title,
            subtitle,
            const TdsSkeletonPart.spacer(24),
            list,
          ],
          TdsSkeletonPattern.amountTopList ||
          TdsSkeletonPattern.amountTopListWithIcon => [
            const TdsSkeletonPart.spacer(48),
            subtitle,
            title,
            const TdsSkeletonPart.spacer(40),
            list,
          ],
          TdsSkeletonPattern.subtitleList ||
          TdsSkeletonPattern.subtitleListWithIcon => [
            subtitle,
            const TdsSkeletonPart.spacer(24),
            list,
          ],
          TdsSkeletonPattern.listOnly ||
          TdsSkeletonPattern.listWithIconOnly => [list],
          TdsSkeletonPattern.cardOnly => [
            const TdsSkeletonPart(TdsSkeletonModule.card),
          ],
        };
  }

  @override
  Widget build(BuildContext context) {
    final modules = parts;
    final items = <TdsSkeletonPart>[
      for (var i = 0; i < modules.length; i++)
        for (
          var n = 0;
          n <
              (i == modules.length - 1 && modules[i].module != null
                  ? (infinite || pattern == TdsSkeletonPattern.cardOnly
                        ? 30
                        : repeatLastItemCount)
                  : 1);
          n++
        )
          modules[i],
    ];
    final theme = TdsTheme.of(context);
    final color = switch (background) {
      TdsSkeletonBackground.white => theme.color('background'),
      TdsSkeletonBackground.greyOpacity100 => theme.color('greyOpacity100'),
      TdsSkeletonBackground.grey => theme.color(
        theme.colorScheme == TdsColorPreference.light ? 'grey100' : 'grey50',
      ),
    };
    Widget block(double h, double radius, {double? width}) => Container(
      height: h,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    Widget module(TdsSkeletonModule part) => switch (part) {
      TdsSkeletonModule.title => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FractionallySizedBox(
          widthFactor: .5,
          alignment: Alignment.centerLeft,
          child: block(30, 11),
        ),
      ),
      TdsSkeletonModule.subtitle => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FractionallySizedBox(
          widthFactor: .33,
          alignment: Alignment.centerLeft,
          child: block(22, 9),
        ),
      ),
      TdsSkeletonModule.list => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: block(64, 18),
      ),
      TdsSkeletonModule.card => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: block(240, 38),
      ),
      TdsSkeletonModule.listWithIcon => Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Row(
          children: [
            block(40, 20, width: 40),
            const SizedBox(width: 14),
            Expanded(child: block(42, 13)),
          ],
        ),
      ),
    };
    return TdsSkeletonWrapper(
      show: show,
      child: Semantics(
        label: '로딩 중',
        liveRegion: true,
        image: true,
        child: ExcludeSemantics(
          child: SizedBox(
            height: height,
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      items[i].spacer != null
                          ? SizedBox(height: items[i].spacer)
                          : TdsSkeletonItem(
                              index: i,
                              child: module(items[i].module!),
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
}

class TdsSkeletonWrapper extends StatefulWidget {
  const TdsSkeletonWrapper({required this.child, this.show = true, super.key});
  final Widget child;
  final bool show;
  @override
  State<TdsSkeletonWrapper> createState() => _TdsSkeletonWrapperState();
}

class _TdsSkeletonWrapperState extends State<TdsSkeletonWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  late double from = widget.show ? 0 : 1, to = widget.show ? 1 : 0;
  late Curve curve = widget.show ? TdsMotion.out : TdsMotion.expo;
  double get value => from + (to - from) * curve.transform(animation.value);
  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.show ? 1000 : 400),
    )..forward();
  }

  @override
  void didUpdateWidget(TdsSkeletonWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show == widget.show) return;
    // Sample with the OLD curve before switching; implicit curve replacement
    // otherwise jumps from out(t) to expo(t) during interrupted transitions.
    from = value;
    to = widget.show ? 1 : 0;
    curve = widget.show ? TdsMotion.out : TdsMotion.expo;
    animation.duration = Duration(milliseconds: widget.show ? 1000 : 400);
    animation.forward(from: 0);
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: !widget.show,
    child: AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) =>
          Opacity(opacity: value.clamp(0, 1), child: child),
    ),
  );
}

class TdsSkeletonItem extends StatefulWidget {
  const TdsSkeletonItem({required this.child, this.index = 0, super.key});
  final Widget child;
  final int index;
  @override
  State<TdsSkeletonItem> createState() => _TdsSkeletonItemState();
}

class _TdsSkeletonItemState extends State<TdsSkeletonItem>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _delay;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    _delay = Timer(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        setState(() => _started = true);
        _animation.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    child: widget.child,
    builder: (context, child) {
      // TDS's named "ease" is NOT CSS ease / Flutter Curves.ease.
      final t = const Cubic(.6, 0, 0, .6).transform(_animation.value);
      return Opacity(
        opacity: _started ? .2 + .8 * t : 0,
        child: Transform.scale(
          scale: _started ? .96 + .04 * t : 1,
          child: child,
        ),
      );
    },
  );
}

enum TdsRatingSize { tiny, small, medium, large, big }

enum TdsRatingVariant { full, compact, iconOnly }

class TdsRating extends StatelessWidget {
  const TdsRating({
    required this.value,
    this.max = 5,
    this.size = TdsRatingSize.medium,
    this.readOnly = true,
    this.disabled = false,
    this.variant = TdsRatingVariant.full,
    this.onValueChange,
    this.semanticLabel = '별점평가',
    this.valueText,
    super.key,
  }) : assert(max > 0),
       assert(value >= 0 && value <= max),
       assert(
         readOnly ||
             (size != TdsRatingSize.tiny && size != TdsRatingSize.small),
       );
  final double value;
  final int max;
  final TdsRatingSize size;
  final bool readOnly, disabled;
  final TdsRatingVariant variant;
  final ValueChanged<double>? onValueChange;
  final String semanticLabel;
  final String? valueText;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final dimension = [16.0, 20.0, 24.0, 32.0, 40.0][size.index];
    final gap = readOnly ? 0.0 : [0.0, 0.0, 8.0, 6.0, 4.0][size.index];
    final count = readOnly && variant == TdsRatingVariant.compact ? 1 : max;
    final width = dimension * count + gap * (count - 1);
    void change(double next) {
      if (!readOnly && !disabled && next != value) {
        onValueChange?.call(next.clamp(0, max).toDouble());
        tdsHapticOf(context).generate(TdsHapticType.tickWeak);
      }
    }

    void position(double x) =>
        change((x / width * max).ceilToDouble().clamp(0, max).toDouble());
    final enabled = !readOnly && !disabled;
    Widget stars = SizedBox(
      width: width,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Builder(
              builder: (context) {
                final delta = i + 1 - value;
                final fraction = readOnly && variant == TdsRatingVariant.compact
                    ? 1.0
                    : readOnly
                    ? (delta <= .25
                          ? 1.0
                          : delta <= .75
                          ? .5
                          : 0.0)
                    : (i < value ? 1.0 : 0.0);
                return Stack(
                  children: [
                    TdsAssetIcon(
                      name: 'icon-star-mono',
                      size: dimension,
                      color: theme.color('grey200'),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction,
                        child: TdsAssetIcon(
                          name: 'icon-star-mono',
                          size: dimension,
                          color: theme.color('yellow400'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
    stars = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (e) => position(e.localPosition.dx) : null,
      onHorizontalDragStart: enabled
          ? (e) => position(e.localPosition.dx)
          : null,
      onHorizontalDragUpdate: enabled
          ? (e) => position(e.localPosition.dx)
          : null,
      child: stars,
    );
    return Semantics(
      label: semanticLabel,
      value: valueText ?? '$max점 만점 중 $value점',
      slider: !readOnly,
      enabled: !disabled,
      onIncrease: enabled && value < max ? () => change(value + 1) : null,
      onDecrease: enabled && value > 0 ? () => change(value - 1) : null,
      increasedValue: enabled ? '${(value + 1).clamp(0, max)}' : null,
      decreasedValue: enabled ? '${(value - 1).clamp(0, max)}' : null,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent || !enabled) return KeyEventResult.ignored;
          if (e.logicalKey == LogicalKeyboardKey.arrowRight ||
              e.logicalKey == LogicalKeyboardKey.arrowUp) {
            change(value + 1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowLeft ||
              e.logicalKey == LogicalKeyboardKey.arrowDown) {
            change(value - 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              stars,
              if (readOnly && variant != TdsRatingVariant.iconOnly) ...[
                SizedBox(width: size == TdsRatingSize.tiny ? 2 : 4),
                TdsText(
                  value == value.roundToDouble()
                      ? value.toInt().toString()
                      : value.toString(),
                  typography: [
                    TdsTypography.t7,
                    TdsTypography.t5,
                    TdsTypography.t4,
                    TdsTypography.t3,
                    TdsTypography.st5,
                  ][size.index],
                  fontWeight: size == TdsRatingSize.tiny
                      ? TdsFontWeight.medium
                      : size.index < 3
                      ? TdsFontWeight.semibold
                      : TdsFontWeight.bold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TdsResult extends StatelessWidget {
  const TdsResult({
    this.figure,
    this.title,
    this.description,
    this.button,
    super.key,
  });
  final Widget? figure, title, description, button;
  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (figure != null) ...[
            figure!,
            if (title != null || description != null)
              const SizedBox(height: 12),
          ],
          if (title != null)
            DefaultTextStyle(
              style: theme.textStyle(
                typography: TdsTypography.t5,
                fontWeight: TdsFontWeight.semibold,
              ),
              textAlign: TextAlign.center,
              child: title!,
            ),
          if (description != null) ...[
            if (title != null) const SizedBox(height: 4),
            DefaultTextStyle(
              style: theme.textStyle(
                typography: TdsTypography.t6,
                color: theme.color('grey700'),
              ),
              textAlign: TextAlign.center,
              child: description!,
            ),
          ],
          if (button != null) ...[const SizedBox(height: 16), button!],
        ],
      ),
    );
  }
}

class TdsResultButton extends StatelessWidget {
  const TdsResultButton({
    required this.child,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
    super.key,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled, loading;
  @override
  Widget build(BuildContext context) => TdsButton(
    size: TdsButtonSize.medium,
    onPressed: onPressed,
    disabled: disabled,
    loading: loading,
    child: child,
  );
}
