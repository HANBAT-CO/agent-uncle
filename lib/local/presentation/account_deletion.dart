import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import 'common.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool agreed = false;
  bool deleting = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.session.current?.b('deletionPending') ?? false;
    final active = app.workspace
        .records('requests')
        .where(
          (r) =>
              !['completed', 'cancelled', 'rejected'].contains(r.s('status')),
        )
        .length;
    return PopScope(
      canPop: !deleting && !pending,
      child: PageFrame(
        title: '회원 탈퇴',
        back: !deleting && !pending,
        children: [
          const PageHeading('탈퇴 전에 확인해 주세요'),
          const Info(
            '계정과 프로필, 가입 정보, 요청 초안, 알림, 업로드한 사진·서류를 삭제해요. 직접 보낸 일반 채팅은 삭제된 메시지로 표시돼요.',
          ),
          const Info(
            '상대방과 공유한 요청·배송·수령·문제 처리 기록과 업무 알림, 상대방이 보낸 메시지는 상대방의 거래 확인을 위해 남아요. 이미 내려받은 사본은 회수할 수 없어요.',
          ),
          const Info(
            '탈퇴는 되돌릴 수 없어요. 같은 소셜 계정으로 다시 로그인해도 새로 가입해야 하며 이전 기록은 복원되지 않아요. Google·카카오 계정 자체는 삭제되지 않아요.',
          ),
          if (active > 0)
            Info(
              '진행 중인 요청이 $active건 있어요. 탈퇴가 거래 취소나 정산 완료를 의미하지 않아요. 필요한 기록을 확인하고 거래처와 연락·정산 방법을 먼저 정해 주세요.',
            ),
          if (pending)
            const Info(
              '탈퇴 처리가 아직 완료되지 않았어요. 계정 이용은 중단되었으며 일부 파일이 이미 삭제되었을 수 있어요. 아래 버튼으로 탈퇴를 마무리해 주세요.',
              error: true,
            ),
          if (!pending)
            Inset(
              child: TdsCheckbox(
                checked: agreed,
                disabled: deleting,
                onChanged: (value) => setState(() => agreed = value),
                child: const Text('삭제 범위와 복구할 수 없음을 확인했어요'),
              ),
            ),
          const TdsSpacing(24),
          ActionButton(
            pending ? '탈퇴 다시 시도' : '회원 탈퇴하기',
            danger: true,
            enabled: (agreed || pending) && !deleting,
            onPressed: () async {
              if (!pending &&
                  !await confirm(
                    context,
                    '정말 탈퇴할까요?',
                    '확인하면 계정 이용이 중단되고 삭제가 시작돼요. 삭제된 정보는 복구할 수 없어요.',
                  )) {
                return;
              }
              if (!mounted) return;
              setState(() => deleting = true);
              try {
                await app.session.deleteAccount();
              } finally {
                if (mounted) setState(() => deleting = false);
              }
            },
          ),
          if (pending)
            ActionButton(
              '로그아웃',
              weak: true,
              enabled: !deleting,
              onPressed: app.session.signOut,
            ),
        ],
      ),
    );
  }
}
