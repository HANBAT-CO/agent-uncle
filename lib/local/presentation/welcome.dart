import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int index = 0;
  static const titles = [
    '상품과 수량을 정확하게 전달해요',
    '확보부터 수령까지 함께 확인해요',
    '요청과 대화를 이어가요',
  ];
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget heading = PageHeading(titles[index]);
    if (!reduced) {
      heading = TdsTooltipMotionSurface(
        key: ValueKey(index),
        open: true,
        variant: TdsTooltipMotion.weak,
        placement: TdsOverlayPlacement.bottom,
        child: heading,
      );
    }
    return PageFrame(
      title: '사입삼춘',
      back: false,
      subtitle: '${index + 1} / 3',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActionButton(
            index == 2 ? '시작하기' : '다음',
            bottom: true,
            onPressed: () async {
              if (index < 2) {
                setState(() => index++);
              } else {
                await AppScope.read(context).session.finishOnboarding();
              }
            },
          ),
          Inset(
            child: TdsTextButton(
              size: TdsTextButtonSize.small,
              onPressed: () =>
                  AppScope.read(context).session.finishOnboarding(),
              child: const Text('건너뛰기'),
            ),
          ),
        ],
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Align(alignment: Alignment.centerLeft, child: AppLogo()),
        ),
        heading,
      ],
    );
  }
}

class RolePage extends StatefulWidget {
  const RolePage({this.closeOnSelect = false, super.key});
  final bool closeOnSelect;
  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  AppRole? selected;
  bool working = false;

  Future<void> _once(Future<void> Function() action) async {
    if (working) return;
    setState(() => working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget _roleCard(BuildContext context, AppRole role) {
    final theme = TdsTheme.of(context);
    final active = selected == role;
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FigmaIcon(
          role == AppRole.retailer ? 'store' : 'bag',
          selected: active,
          size: 40,
        ),
        const TdsSpacing(12),
        TdsText(
          role.label,
          typography: TdsTypography.t5,
          fontWeight: TdsFontWeight.semibold,
          color: active ? theme.color('blue600') : null,
        ),
        TdsText(
          role == AppRole.retailer
              ? '사입을 요청하고 받은 상품을 확인해요.'
              : '요청을 받아 상품을 확보하고 전달해요.',
          typography: TdsTypography.t6,
          color: theme.color('grey600'),
        ),
      ],
    );
    return FigmaSurface(
      tinted: active,
      children: [
        Semantics(
          selected: active,
          child: TdsListRow(
            onPressed: () => setState(() => selected = role),
            contents: contents,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '역할 선택',
    back: widget.closeOnSelect,
    bottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          '선택한 역할로 계속',
          bottom: true,
          enabled: selected != null && !working,
          onPressed: () => _once(() async {
            await AppScope.read(context).session.chooseRole(selected!);
            if (widget.closeOnSelect && context.mounted) {
              Navigator.pop(context);
            }
          }),
        ),
        Inset(
          child: TdsTextButton(
            size: TdsTextButtonSize.small,
            disabled: working,
            onPressed: () =>
                _once(() => AppScope.read(context).session.signOut()),
            child: const Text('로그인으로 돌아가기'),
          ),
        ),
      ],
    ),
    children: [
      const PageHeading('어떤 일을 하고 계신가요?', description: '업무에 맞는 화면을 준비할게요.'),
      for (final role in AppRole.values) _roleCard(context, role),
    ],
  );
}
