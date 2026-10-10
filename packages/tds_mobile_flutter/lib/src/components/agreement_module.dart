import 'dart:async';
import 'package:flutter/widgets.dart';
import '../foundation/theme.dart';
import '../foundation/motion.dart';
import '../foundation/portal.dart';
import 'bottom_sheet.dart';
import 'button.dart';
import 'text_button.dart';
import 'stepper.dart';
import 'text.dart';

enum TdsAgreementStep { required, optional }

enum TdsAgreementCTAVariant { mainOnly, mainRequired, mainOptional, leftRight }

@immutable
class TdsAgreementModuleOptions {
  const TdsAgreementModuleOptions({
    this.step,
    this.delayWhenForceCheckedRequired = const Duration(milliseconds: 500),
    this.ctaRequiredDefaultVariant = TdsAgreementCTAVariant.mainRequired,
    this.ctaOptionalDefaultVariant = TdsAgreementCTAVariant.leftRight,
    this.totalOptionalTermCount = 0,
    this.agreedOptionalTermCount = 0,
    this.hasAgreedOptionalOnce = false,
    this.inBottomSheet = false,
  });
  final TdsAgreementStep? step;
  final Duration delayWhenForceCheckedRequired;
  final TdsAgreementCTAVariant ctaRequiredDefaultVariant,
      ctaOptionalDefaultVariant;
  final int totalOptionalTermCount, agreedOptionalTermCount;
  final bool hasAgreedOptionalOnce, inBottomSheet;
}

class _ModuleScope extends InheritedWidget {
  const _ModuleScope({
    required this.options,
    required this.step,
    required this.loading,
    required super.child,
  });
  final TdsAgreementModuleOptions options;
  final TdsAgreementStep? step;
  final bool loading;
  static _ModuleScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ModuleScope>();
  @override
  bool updateShouldNotify(_ModuleScope oldWidget) =>
      options != oldWidget.options ||
      step != oldWidget.step ||
      loading != oldWidget.loading;
}

class TdsAgreementModuleProvider extends StatefulWidget {
  const TdsAgreementModuleProvider({
    required this.options,
    required this.child,
    super.key,
  });
  final TdsAgreementModuleOptions options;
  final Widget child;
  @override
  State<TdsAgreementModuleProvider> createState() =>
      _TdsAgreementModuleProviderState();
}

class _TdsAgreementModuleProviderState
    extends State<TdsAgreementModuleProvider> {
  late TdsAgreementStep? step = widget.options.step;
  Timer? timer;
  bool loading = false;
  @override
  void didUpdateWidget(TdsAgreementModuleProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.step == widget.options.step &&
        oldWidget.options.delayWhenForceCheckedRequired ==
            widget.options.delayWhenForceCheckedRequired) {
      return;
    }
    timer?.cancel();
    if (step == widget.options.step) {
      loading = false;
      return;
    }
    loading = true;
    timer = Timer(widget.options.delayWhenForceCheckedRequired, () {
      if (mounted) {
        setState(() {
          step = widget.options.step;
          loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ModuleScope(
    options: widget.options,
    step: step,
    loading: loading,
    child: widget.child,
  );
}

class TdsAgreementModuleContent extends StatelessWidget {
  const TdsAgreementModuleContent({
    this.step,
    this.requiredContent,
    this.optionalContent,
    super.key,
  });
  final TdsAgreementStep? step;
  final Widget? requiredContent, optionalContent;
  @override
  Widget build(BuildContext context) {
    final current = step ?? _ModuleScope.of(context)?.step;
    return TdsFontScaleLimit(
      limit: 160,
      child: AnimatedSwitcher(
        duration: TdsMotion.basic.duration,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previous)
              Positioned.fill(
                child: ExcludeFocus(
                  child: ExcludeSemantics(child: IgnorePointer(child: child)),
                ),
              ),
            ?current,
          ],
        ),
        child: KeyedSubtree(
          key: ValueKey(current),
          child: switch (current) {
            TdsAgreementStep.required => requiredContent ?? const SizedBox(),
            TdsAgreementStep.optional => optionalContent ?? const SizedBox(),
            null => const SizedBox(),
          },
        ),
      ),
    );
  }
}

class TdsAgreementModuleStagger extends StatelessWidget {
  const TdsAgreementModuleStagger({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++)
        TdsStaggerIn(
          delay: Duration(milliseconds: 80 * (i == 0 ? 1 : i)),
          child: children[i],
        ),
    ],
  );
}

class TdsAgreementModuleTopTitle extends StatelessWidget {
  const TdsAgreementModuleTopTitle(this.text, {this.color, super.key});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: TdsText(
      text,
      typography: TdsTypography.t3,
      fontWeight: TdsFontWeight.bold,
      color: color ?? TdsTheme.of(context).color('grey900'),
    ),
  );
}

class TdsAgreementModuleTop extends StatelessWidget {
  const TdsAgreementModuleTop({
    this.step,
    this.requiredAsset,
    this.optionalAsset,
    this.requiredTitle,
    this.optionalTitle,
    this.requiredSubTitle,
    this.optionalSubTitle,
    this.optionalInprogressTitle,
    this.optionalCompletedTitle = '선택 동의에\n모두 동의했어요',
    this.totalOptionalTermCount,
    this.agreedOptionalTermCount,
    super.key,
  });
  final TdsAgreementStep? step;
  final Widget? requiredAsset, optionalAsset;
  final String? requiredTitle,
      optionalTitle,
      requiredSubTitle,
      optionalSubTitle,
      optionalInprogressTitle;
  final String optionalCompletedTitle;
  final int? totalOptionalTermCount, agreedOptionalTermCount;
  @override
  Widget build(BuildContext context) {
    final scope = _ModuleScope.of(context),
        options = scope?.options ?? const TdsAgreementModuleOptions();
    final current = step ?? scope?.step;
    final required = current == TdsAgreementStep.required;
    final total = totalOptionalTermCount ?? options.totalOptionalTermCount;
    final count = agreedOptionalTermCount ?? options.agreedOptionalTermCount;
    final completed =
        !required &&
        count > 0 &&
        total > 1 &&
        count == total &&
        options.hasAgreedOptionalOnce;
    final title = required
        ? requiredTitle
        : count == 0 || total == 1
        ? optionalTitle
        : completed
        ? optionalCompletedTitle
        : optionalInprogressTitle ?? '선택 동의\n$count개에 동의했어요';
    final asset = required ? requiredAsset : optionalAsset;
    final subtitle = required ? requiredSubTitle : optionalSubTitle;
    return TdsFontScaleLimit(
      limit: 160,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          options.inBottomSheet ? 11 : 24,
          24,
          options.inBottomSheet ? 13 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (asset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(alignment: Alignment.centerLeft, child: asset),
              ),
            AnimatedSwitcher(
              duration: TdsMotion.basic.duration,
              child: Align(
                key: ValueKey(title),
                alignment: Alignment.centerLeft,
                child: TdsAgreementModuleTopTitle(
                  title ?? '',
                  color: completed
                      ? TdsTheme.of(context).color('blue500')
                      : null,
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TdsText(
                  subtitle,
                  typography: TdsTypography.t6,
                  color: TdsTheme.of(context).color('grey600'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TdsAgreementApproveEvent {
  const TdsAgreementApproveEvent({this.step, this.agreedOptionalTermCount = 0});
  final TdsAgreementStep? step;
  final int agreedOptionalTermCount;
}

class TdsAgreementModuleCTA extends StatelessWidget {
  const TdsAgreementModuleCTA({
    this.ctaVariant,
    this.approveRequiredButtonTitle,
    this.approveOptionalButtonTitle,
    this.rejectRequiredButtonTitle,
    this.rejectOptionalButtonTitle = '동의 안 함',
    this.onApproveButtonClick,
    this.onRejectButtonClick,
    this.disabled = false,
    super.key,
  });
  final TdsAgreementCTAVariant? ctaVariant;
  final String? approveRequiredButtonTitle,
      approveOptionalButtonTitle,
      rejectRequiredButtonTitle;
  final String rejectOptionalButtonTitle;
  final ValueChanged<TdsAgreementApproveEvent>? onApproveButtonClick;
  final ValueChanged<TdsAgreementStep?>? onRejectButtonClick;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final scope = _ModuleScope.of(context),
        options = scope?.options ?? const TdsAgreementModuleOptions();
    final step = scope?.step;
    final variant =
        ctaVariant ??
        (step == TdsAgreementStep.required
            ? options.ctaRequiredDefaultVariant
            : options.agreedOptionalTermCount == 0 ||
                  options.hasAgreedOptionalOnce
            ? options.ctaOptionalDefaultVariant
            : TdsAgreementCTAVariant.mainOnly);
    final isRequired =
        step == TdsAgreementStep.required ||
        (step == null &&
            [
              TdsAgreementCTAVariant.mainOnly,
              TdsAgreementCTAVariant.mainRequired,
            ].contains(variant));
    final approveText = isRequired
        ? approveRequiredButtonTitle ?? '필수 동의하기'
        : approveOptionalButtonTitle ??
              (options.agreedOptionalTermCount >= 1
                  ? '다음'
                  : variant == TdsAgreementCTAVariant.leftRight
                  ? '모두 동의'
                  : '모두 동의하기');
    final rejectText = isRequired
        ? rejectRequiredButtonTitle ?? (options.inBottomSheet ? '닫기' : '나중에')
        : rejectOptionalButtonTitle;
    final approve = TdsButton(
      display: TdsButtonDisplay.block,
      disabled: disabled || (scope?.loading ?? false),
      onPressed: () => onApproveButtonClick?.call(
        TdsAgreementApproveEvent(
          step: step,
          agreedOptionalTermCount: options.agreedOptionalTermCount,
        ),
      ),
      child: Text(approveText),
    );
    final reject = TdsButton(
      display: TdsButtonDisplay.block,
      color: TdsButtonColor.dark,
      variant: TdsButtonVariant.weak,
      onPressed: () => onRejectButtonClick?.call(step),
      child: Text(rejectText),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, options.inBottomSheet ? 18 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (variant == TdsAgreementCTAVariant.leftRight)
            if (rejectText.length > 7 || approveText.length > 7)
              Column(children: [approve, const SizedBox(height: 8), reject])
            else
              Row(
                children: [
                  Expanded(child: reject),
                  const SizedBox(width: 10),
                  Expanded(child: approve),
                ],
              )
          else
            approve,
          if ([
            TdsAgreementCTAVariant.mainOptional,
            TdsAgreementCTAVariant.mainRequired,
          ].contains(variant))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TdsTextButton(
                size: TdsTextButtonSize.medium,
                onPressed: () => onRejectButtonClick?.call(step),
                child: Text(rejectText),
              ),
            ),
        ],
      ),
    );
  }
}

class TdsFullPageAgreementModule extends StatelessWidget {
  const TdsFullPageAgreementModule({
    required this.options,
    required this.child,
    this.header,
    this.cta,
    super.key,
  });
  final TdsAgreementModuleOptions options;
  final Widget child;
  final Widget? header, cta;
  @override
  Widget build(BuildContext context) => TdsAgreementModuleProvider(
    options: options,
    child: Column(
      children: [
        ?header,
        Expanded(child: SingleChildScrollView(child: child)),
        if (cta != null) SafeArea(top: false, child: cta!),
      ],
    ),
  );
}

class TdsBottomSheetAgreementModule extends StatelessWidget {
  const TdsBottomSheetAgreementModule({
    required this.open,
    required this.options,
    required this.child,
    this.header,
    this.cta,
    this.onClose,
    this.ignoreDimmerClick,
    super.key,
  });
  final bool open;
  final TdsAgreementModuleOptions options;
  final Widget child;
  final Widget? header, cta;
  final VoidCallback? onClose;
  final bool? ignoreDimmerClick;
  @override
  Widget build(BuildContext context) => TdsBottomSheet(
    open: open,
    onClose: onClose,
    ignoreDimmerClick:
        ignoreDimmerClick ?? options.step == TdsAgreementStep.optional,
    child: TdsAgreementModuleProvider(
      options: _inSheet(options),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [?header, child, ?cta],
      ),
    ),
  );
}

TdsAgreementModuleOptions _inSheet(TdsAgreementModuleOptions options) =>
    TdsAgreementModuleOptions(
      step: options.step,
      delayWhenForceCheckedRequired: options.delayWhenForceCheckedRequired,
      ctaRequiredDefaultVariant: options.ctaRequiredDefaultVariant,
      ctaOptionalDefaultVariant: options.ctaOptionalDefaultVariant,
      totalOptionalTermCount: options.totalOptionalTermCount,
      agreedOptionalTermCount: options.agreedOptionalTermCount,
      hasAgreedOptionalOnce: options.hasAgreedOptionalOnce,
      inBottomSheet: true,
    );

class TdsFloatButtonAgreementModule extends StatefulWidget {
  const TdsFloatButtonAgreementModule({
    required this.options,
    required this.child,
    this.header,
    this.cta,
    this.delay = Duration.zero,
    this.gradientColor,
    super.key,
  });
  final TdsAgreementModuleOptions options;
  final Widget child;
  final Widget? header, cta;
  final Duration delay;
  final Color? gradientColor;
  @override
  State<TdsFloatButtonAgreementModule> createState() =>
      _TdsFloatButtonAgreementModuleState();
}

class _TdsFloatButtonAgreementModuleState
    extends State<TdsFloatButtonAgreementModule> {
  Timer? timer;
  bool visible = false;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  void schedule() {
    timer?.cancel();
    timer = Timer(widget.delay, () {
      if (mounted) setState(() => visible = true);
    });
  }

  @override
  void didUpdateWidget(TdsFloatButtonAgreementModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delay != widget.delay) {
      visible = false;
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !visible
      ? const SizedBox()
      : TdsFixedPanel(
          takeSpace: false,
          child: TdsAgreementModuleProvider(
            options: _inSheet(widget.options),
            child: TdsFontScaleLimit(
              limit: 120,
              child: _GradientAgreementContent(
                header: widget.header,
                cta: widget.cta,
                color: widget.gradientColor,
                maxHeightFraction: .33,
                child: widget.child,
              ),
            ),
          ),
        );
}

class TdsGradientBottomSheetAgreementModule extends StatelessWidget {
  const TdsGradientBottomSheetAgreementModule({
    required this.open,
    required this.options,
    required this.child,
    this.header,
    this.cta,
    this.onClose,
    this.gradientColor,
    super.key,
  });
  final bool open;
  final TdsAgreementModuleOptions options;
  final Widget child;
  final Widget? header, cta;
  final VoidCallback? onClose;
  final Color? gradientColor;
  @override
  Widget build(BuildContext context) => TdsBottomSheet(
    open: open,
    onClose: onClose,
    ctaContentGap: 0,
    child: TdsAgreementModuleProvider(
      options: _inSheet(options),
      child: _GradientAgreementContent(
        header: header,
        cta: cta,
        color: gradientColor,
        maxHeightFraction: .66,
        child: child,
      ),
    ),
  );
}

class _GradientAgreementContent extends StatelessWidget {
  const _GradientAgreementContent({
    required this.child,
    required this.maxHeightFraction,
    this.header,
    this.cta,
    this.color,
  });
  final Widget child;
  final Widget? header, cta;
  final Color? color;
  final double maxHeightFraction;
  @override
  Widget build(BuildContext context) {
    final background = color ?? TdsTheme.of(context).color('background');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [background.withValues(alpha: 0), background],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: background,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?header,
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height * maxHeightFraction,
                ),
                child: SingleChildScrollView(child: child),
              ),
              if (cta != null) SafeArea(top: false, child: cta!),
            ],
          ),
        ),
      ],
    );
  }
}
