import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';

/// 가입한 역할에 맞춰 실제 업무에서 얻는 이점을 안내한다.
class RoleOnboardingPage extends StatefulWidget {
  const RoleOnboardingPage({required this.role, super.key});
  final AppRole role;

  @override
  State<RoleOnboardingPage> createState() => _RoleOnboardingPageState();
}

class _RoleOnboardingPageState extends State<RoleOnboardingPage> {
  int index = 0;
  bool saving = false;
  String? error;
  final scrollController = ScrollController();

  static const retailerPages = [
    (
      title: '원하는 상품을\n정확하게 전달해요',
      description: '상품 정보부터 배송지까지 함께 공유해\n입력 실수와 배송 착오를 줄여요.',
      icon: 'bag',
      rows: [
        (
          icon: 'shirt',
          title: '상품·옵션·수량을 한 번에',
          subtitle: '주문 내용을 사입삼촌과 함께 확인해요.',
        ),
        (icon: 'pin', title: '받을 곳까지 정확하게', subtitle: '배송지와 상세주소를 요청에 남겨요.'),
      ],
    ),
    (
      title: '챙겨야 할 대금이\n한눈에 보여요',
      description: '입금 전부터 확인 완료까지,\n대금 처리 현황을 확인해요.',
      icon: 'document',
      rows: [
        (
          icon: 'clock',
          title: '아직 입금하지 않은 건 확인',
          subtitle: '처리가 필요한 대금을 놓치지 않고 챙겨요.',
        ),
        (
          icon: 'check',
          title: '입금 후에도 진행 상황 확인',
          subtitle: '송금 신고와 운영자 확인 상태를 살펴봐요.',
        ),
      ],
    ),
    (
      title: '새로운 시장으로\n사입을 넓혀요',
      description: '다른 지역의 사입삼촌과 연결하고\n우리 매장에 맞는 상품을 찾아보세요.',
      icon: 'store',
      rows: [
        (
          icon: 'search',
          title: '필요한 지역의 사입삼촌 찾기',
          subtitle: '사입 지역과 프로필을 확인해요.',
        ),
        (
          icon: 'link',
          title: '연결하고 새 사입 요청 보내기',
          subtitle: '연결이 수락되면 요청과 대화를 시작해요.',
        ),
      ],
    ),
  ];

  static const unclePages = [
    (
      title: '받을 대금과 지급 현황을\n놓치지 않아요',
      description: '입금 확인부터 지급 처리까지,\n어디까지 진행됐는지 확인해요.',
      icon: 'document',
      rows: [
        (
          icon: 'clock',
          title: '미입금·지급 대기 건 확인',
          subtitle: '아직 처리되지 않은 대금을 챙겨요.',
        ),
        (
          icon: 'check',
          title: '운영자 확인 후 지급 상태 확인',
          subtitle: '소매업자 수령·입금 확인 후 운영자가 지급해요.',
        ),
      ],
    ),
    (
      title: '여러 거래처의 요청을\n한곳에서 관리해요',
      description: '흩어진 주문을 모아 보고\n진행 중인 사입을 차근차근 처리해요.',
      icon: 'bag',
      rows: [
        (
          icon: 'store',
          title: '거래처별 요청 모아보기',
          subtitle: '여러 소매업장의 주문을 앱에서 확인해요.',
        ),
        (
          icon: 'truck',
          title: '확보부터 전달까지 이어서',
          subtitle: '상품 확보·미송·전달 상태를 기록하고 공유해요.',
        ),
      ],
    ),
    (
      title: '오늘의 사입도,\n이번 달 실적도 한눈에',
      description: '쌓이는 사입 기록을 살펴보고\n내 업무 현황을 확인해요.',
      icon: 'home',
      rows: [
        (
          icon: 'check',
          title: '오늘 처리한 사입 확인',
          subtitle: '오늘의 진행 상황과 완료 내역을 살펴봐요.',
        ),
        (
          icon: 'document',
          title: '이번 달 실적 돌아보기',
          subtitle: '기간별 사입 현황을 모아 확인해요.',
        ),
      ],
    ),
  ];

  void move(int target) {
    if (saving) return;
    if (scrollController.hasClients) scrollController.jumpTo(0);
    setState(() => index = target);
  }

  Future<void> finish() async {
    if (saving) return;
    final session = AppScope.read(context).session;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await session.finishRoleOnboarding();
    } catch (_) {
      if (mounted) {
        setState(() => error = '안내 완료 상태를 저장하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.role == AppRole.retailer ? retailerPages : unclePages;
    final page = pages[index];
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && index > 0) move(index - 1);
      },
      child: PageFrame(
        title: '사입삼춘 시작 안내',
        back: false,
        scrollController: scrollController,
        trailing: TdsTextButton(
          size: TdsTextButtonSize.small,
          colorToken: 'grey600',
          disabled: saving,
          onPressed: finish,
          child: const Text('건너뛰기'),
        ),
        header: Semantics(
          label: '시작 안내 ${pages.length}단계 중 ${index + 1}단계',
          child: ExcludeSemantics(
            child: TdsProgressStepper(
              activeStepIndex: index,
              children: const [
                TdsProgressStep(),
                TdsProgressStep(),
                TdsProgressStep(),
              ],
            ),
          ),
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) Info(error!, error: true),
            if (index > 0)
              TdsTextButton(
                size: TdsTextButtonSize.medium,
                colorToken: 'grey600',
                disabled: saving,
                onPressed: () => move(index - 1),
                child: const Text('이전'),
              ),
            ActionButton(
              index == pages.length - 1 ? '사입삼춘 시작하기' : '다음',
              enabled: !saving,
              bottom: true,
              onPressed: () async {
                if (index == pages.length - 1) {
                  await finish();
                } else {
                  move(index + 1);
                }
              },
            ),
          ],
        ),
        children: [
          TdsStaggerIn(
            key: ValueKey('${widget.role.name}:$index:$reducedMotion'),
            play: !reducedMotion,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: PageHeading(
                    page.title,
                    eyebrow:
                        '${widget.role.label}를 위한 사입삼춘 · ${index + 1} / ${pages.length}',
                    description: page.description,
                  ),
                ),
                FigmaSurface(
                  tinted: true,
                  children: [
                    Inset(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ExcludeSemantics(
                          child: FigmaIcon(page.icon, selected: true, size: 40),
                        ),
                      ),
                    ),
                    for (final row in page.rows)
                      Item(
                        row.title,
                        subtitle: row.subtitle,
                        leading: ExcludeSemantics(
                          child: FigmaIcon(row.icon, selected: true),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
