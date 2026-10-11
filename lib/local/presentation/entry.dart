import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'home.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return Navigator(
      key: ValueKey(session.current?.id ?? 'signed-out'),
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        pageBuilder: (context, a, b) => const AccountLanding(),
      ),
    );
  }
}

class AccountLanding extends StatelessWidget {
  const AccountLanding({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    if (session.loading || (session.authenticated && session.current == null)) {
      return PageFrame(
        title: '계정 확인',
        back: false,
        children: [
          if (session.loading)
            const Center(child: TdsLoader())
          else ...[
            Info(session.syncError ?? '계정 정보를 확인하지 못했어요.', error: true),
            ActionButton('다시 시도', onPressed: session.retrySync),
            ActionButton('로그아웃', weak: true, onPressed: session.signOut),
          ],
        ],
      );
    }
    if (!session.onboardingSeen) return const OnboardingPage();
    if (session.current == null) {
      return session.isRemote
          ? const SocialLoginPage()
          : const LocalLoginPage();
    }
    if (session.current!.role == null) return const RolePage();
    if (!session.current!.complete) {
      return ProfileForm(key: ValueKey(session.current!.id), signup: true);
    }
    return HomeShell(key: ValueKey(session.current!.id));
  }
}

class SocialLoginPage extends StatelessWidget {
  const SocialLoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return PageFrame(
      title: '사입삼춘',
      subtitle: '사입의 시작부터 수령까지',
      back: false,
      children: [
        const TdsSpacing(48),
        const TdsResult(
          title: Text('함께하는 사입을 시작해요'),
          description: Text('로그인하고 거래처와 요청·전달 상황을 함께 확인하세요.'),
        ),
        const TdsSpacing(24),
        if (session.syncError != null) Info(session.syncError!, error: true),
        ActionButton(
          'Google로 로그인',
          onPressed: () => session.signInWithSocial('google'),
        ),
        ActionButton(
          '카카오로 로그인',
          weak: true,
          onPressed: () => session.signInWithSocial('kakao'),
        ),
        const Info('로그인을 취소했다면 원하는 로그인 버튼을 다시 눌러 주세요.'),
      ],
    );
  }
}

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
  static const descriptions = [
    '상품·옵션·수량을 요청에 담고 거래처와 같은 내용을 확인해요.',
    '확보·미송·전달 수량을 구분하고 받은 상품을 직접 확인해요.',
    '1:1 대화에서 관련 요청을 바로 열고 처리 기록을 함께 남겨요.',
  ];
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '사입삼춘',
    back: false,
    subtitle: '${index + 1} / 3',
    children: [
      const TdsSpacing(48),
      TdsResult(
        title: Text(titles[index]),
        description: Text(descriptions[index]),
      ),
      const TdsSpacing(48),
      ActionButton(
        index == 2 ? '시작하기' : '다음',
        onPressed: () async {
          if (index < 2) {
            setState(() => index++);
          } else {
            await AppScope.read(context).session.finishOnboarding();
          }
        },
      ),
      ActionButton(
        '건너뛰기',
        weak: true,
        onPressed: () => AppScope.read(context).session.finishOnboarding(),
      ),
    ],
  );
}

class LocalLoginPage extends StatefulWidget {
  const LocalLoginPage({super.key});
  @override
  State<LocalLoginPage> createState() => _LocalLoginPageState();
}

class _LocalLoginPageState extends State<LocalLoginPage> {
  final label = TextEditingController();
  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return PageFrame(
      title: '사입삼춘',
      subtitle: '사입의 시작부터 수령까지',
      back: false,
      children: [
        const Info('지금은 이 기기에 저장하는 로컬 체험 모드예요. 계정을 나누어 만들면 양쪽 역할을 확인할 수 있어요.'),
        const Inset(
          child: TdsButton(
            display: TdsButtonDisplay.block,
            disabled: true,
            child: Text('Google로 로그인'),
          ),
        ),
        const Info('Google 계정 연결은 준비 중이에요.'),
        // TODO(auth): Enable only after Kakao Biz App registration and backend integration.
        // ActionButton('카카오로 로그인', onPressed: () => authRepository.signInWithKakao()),
        const Section('새 로컬 계정'), Field('계정 이름', controller: label),
        ActionButton(
          '로컬 계정 만들기',
          onPressed: () async {
            await session.createAccount(label.text);
          },
        ),
        if (session.accounts.isNotEmpty) ...[
          const Section('이 기기의 계정'),
          for (final account in session.accounts)
            Item(
              account.name,
              subtitle:
                  '${account.role?.label ?? '역할 선택 전'} · ${account.complete ? '가입 완료' : '가입 이어 하기'}',
              onTap: () async {
                try {
                  await session.signIn(account.id);
                } catch (e) {
                  if (context.mounted) {
                    await confirm(context, '로그인하지 못했어요', e.toString());
                  }
                }
              },
            ),
        ],
      ],
    );
  }
}

class RolePage extends StatelessWidget {
  const RolePage({this.closeOnSelect = false, super.key});
  final bool closeOnSelect;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '어떤 일을 하시나요?',
    subtitle: '계정 하나에 역할 하나를 선택해요',
    back: closeOnSelect,
    children: [
      const TdsSpacing(24),
      const Item('소매업자', subtitle: '사입을 요청하고 처리 결과를 확인해요.'),
      ActionButton(
        '소매업자로 시작',
        onPressed: () async {
          await AppScope.read(context).session.chooseRole(AppRole.retailer);
          if (closeOnSelect && context.mounted) Navigator.pop(context);
        },
      ),
      const Item('사입삼촌', subtitle: '요청을 받아 사입하고 상품을 전달해요.'),
      ActionButton(
        '사입삼촌으로 시작',
        weak: true,
        onPressed: () async {
          await AppScope.read(context).session.chooseRole(AppRole.uncle);
          if (closeOnSelect && context.mounted) Navigator.pop(context);
        },
      ),
      ActionButton(
        '로그인으로 돌아가기',
        weak: true,
        onPressed: () => AppScope.read(context).session.signOut(),
      ),
    ],
  );
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({this.signup = false, super.key});
  final bool signup;
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final fields = <String, TextEditingController>{};
  bool ready = false,
      terms = false,
      privacy = false,
      working = true,
      leaving = false;
  String document = '', photo = '';
  FormSaver? saver;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    final app = AppScope.read(context), a = app.session.current!;
    for (final key in [
      'name',
      'contact',
      'phone',
      'businessName',
      'businessNumber',
      'address',
      'addressDetail',
      'deliveryNote',
      'pickupArea',
      'deliveryArea',
      'deadline',
      'holiday',
      'intro',
    ]) {
      fields[key] = TextEditingController(text: a.s(key));
    }
    document = a.s('documentId');
    photo = a.s('photoId');
    terms = a.b('terms');
    privacy = a.b('privacy');
    working = a.b('working');
    saver = FormSaver((values) => app.session.saveProfile(values));
    saver!.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Data values() => {
    for (final e in fields.entries) e.key: e.value.text.trim(),
    'documentId': document,
    'photoId': photo,
    'terms': terms,
    'privacy': privacy,
    'working': working,
  };
  void changed() {
    if (widget.signup) saver!.change(values());
    setState(() {});
  }

  Widget field(
    String key,
    String title, {
    bool numeric = false,
    bool multiline = false,
  }) => Field(
    title,
    controller: fields[key]!,
    numeric: numeric,
    multiline: multiline,
    onChanged: (_) => changed(),
  );
  @override
  void dispose() {
    saver?.removeListener(_refresh);
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (widget.signup) await saver!.flush();
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.session.current!;
    final retailer = a.role == AppRole.retailer;
    return PopScope(
      canPop: leaving || !widget.signup,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: PageFrame(
        title: widget.signup ? '${a.role!.label} 정보 입력' : '내 정보 수정',
        back: !widget.signup,
        subtitle: widget.signup ? '입력한 정보는 자동으로 저장돼요' : null,
        children: [
          if (widget.signup)
            ActionButton(
              '역할 다시 선택',
              weak: true,
              onPressed: () async {
                await saver!.flush();
                if (context.mounted) {
                  await openPage(context, const RolePage(closeOnSelect: true));
                }
              },
            ),
          if (saver!.error != null) ...[
            Info(saver!.error!, error: true),
            ActionButton(
              '저장 다시 시도',
              weak: true,
              onPressed: () => saver!.flush(),
            ),
          ],
          const Section('담당자 정보'),
          field('name', retailer ? '매장명·쇼핑몰명' : '활동명·업체명'),
          field('contact', '이름·담당자명'),
          field('phone', '연락처'),
          AttachmentField(
            label: '프로필 사진',
            ids: photo.isEmpty ? [] : [photo],
            onChanged: (ids) {
              photo = ids.firstOrNull ?? '';
              changed();
            },
          ),
          const Section('사업자 정보'),
          field('businessName', '사업자명'),
          field('businessNumber', '사업자등록번호', numeric: true),
          AttachmentField(
            label: '사업자등록증 (필수)',
            document: true,
            ids: document.isEmpty ? [] : [document],
            onChanged: (ids) {
              document = ids.firstOrNull ?? '';
              changed();
            },
          ),
          const Info('가입하려면 사업자등록증 사진 또는 PDF를 첨부해 주세요. 서류 제출과 사업자 검증은 별개예요.'),
          if (retailer) ...[
            const Section('기본 배송지'),
            field('address', '주소'),
            field('addressDetail', '상세주소'),
            field('deliveryNote', '배송 참고사항', multiline: true),
            if (!widget.signup) const Info('변경한 기본 배송지는 새로 작성하는 요청부터 적용돼요.'),
          ] else ...[
            const Section('활동·운영 정보'),
            field('pickupArea', '도매 픽업 구역'),
            const Info('시장·상가·건물·층까지 입력해 주세요.'),
            field('deliveryArea', '소매 배송 지역'),
            field('deadline', '요청 마감시간'),
            field('holiday', '휴무·안내사항', multiline: true),
            field('intro', '소개', multiline: true),
            Toggle(
              '업무 중',
              value: working,
              onChanged: (v) {
                working = v;
                changed();
              },
            ),
            const Info('휴무로 바꾸어도 이미 수락한 요청은 유지돼요.'),
          ],
          if (widget.signup) ...[
            const Section('필수 동의'),
            const Info('개발용 동의 화면이에요. 정식 약관·개인정보 처리방침은 서비스 운영 전에 확정돼요.'),
            Inset(
              child: TdsCheckbox(
                checked: terms,
                onChanged: (v) {
                  terms = v;
                  changed();
                },
                child: const Text('[필수] 서비스 이용 동의 확인'),
              ),
            ),
            Inset(
              child: TdsCheckbox(
                checked: privacy,
                onChanged: (v) {
                  privacy = v;
                  changed();
                },
                child: const Text('[필수] 개인정보 처리 동의 확인'),
              ),
            ),
            Item(
              '약관·개인정보 처리 안내',
              onTap: () => openPage(
                context,
                PolicyPage(
                  '가입 동의 안내',
                  app.session.isRemote
                      ? '현재 개발 검증 중인 서비스입니다. 정식 약관과 개인정보 처리방침은 확정 전입니다. 입력한 가입정보·거래 기록·첨부파일은 Supabase 서버에 저장되며, 거래에 필요한 정보는 연결된 상대방과 공유됩니다. 사업자 서류는 상대방에게 공개되지 않습니다.'
                      : '현재는 로컬 개발용 가입 흐름입니다. 정식 약관과 개인정보 처리방침은 확정 전이며, 입력과 첨부는 이 기기에 저장됩니다.',
                ),
              ),
            ),
          ],
          ActionButton(
            widget.signup ? '가입 완료' : '저장하기',
            onPressed: () async {
              if (widget.signup) await saver!.flush();
              await app.session.saveProfile(values(), complete: true);
              if (!widget.signup && context.mounted) Navigator.pop(context);
            },
          ),
          if (widget.signup)
            ActionButton(
              '저장하고 로그아웃',
              weak: true,
              onPressed: () async {
                await saver!.flush();
                await app.session.signOut();
              },
            ),
        ],
      ),
    );
  }
}

class PolicyPage extends StatelessWidget {
  const PolicyPage(this.title, this.description, {super.key});
  final String title, description;
  @override
  Widget build(BuildContext context) =>
      PageFrame(title: title, children: [Info(description)]);
}

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        settings = mapOf(app.session.current!.data, 'notificationSettings');
    return PageFrame(
      title: '알림 설정',
      children: [
        const Info(
          '알림 배지에 표시할 종류를 선택해요. 설정과 관계없이 알림함에서 전체 이력을 확인할 수 있어요. 원격 푸시는 아직 연결하지 않았어요.',
        ),
        for (final e in {
          'connection': '거래처 연결',
          'request': '사입 요청·처리·미송',
          'delivery': '전달·수령·문제',
          'chat': '새 메시지',
        }.entries)
          Toggle(
            e.value,
            value: settings[e.key] != false,
            onChanged: (v) async {
              try {
                await app.session.saveProfile({
                  'notificationSettings': {...settings, e.key: v},
                });
              } catch (error) {
                if (context.mounted) {
                  await confirm(context, '저장하지 못했어요', error.toString());
                }
              }
            },
          ),
      ],
    );
  }
}

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.session.current!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(a.name, subtitle: '${a.role!.label} · ${a.s('contact')}'),
        if (a.s('photoId').isNotEmpty)
          AttachmentPreview(a.s('photoId'), compact: true),
        Item(
          '기본·사업자·운영 정보 수정',
          onTap: () => openPage(context, const ProfileForm()),
        ),
        Item(
          '사업자 서류',
          subtitle: a.s('documentId').isEmpty ? '미등록' : '제출됨 · 검증 전',
          onTap: () => openPage(
            context,
            PageFrame(
              title: '사업자 서류',
              children: [
                const Info('서류 제출 상태예요. 실제 사업자 검증은 연결되지 않았어요.'),
                if (a.s('documentId').isNotEmpty)
                  AttachmentPreview(a.s('documentId')),
              ],
            ),
          ),
        ),
        Item(
          '알림 설정',
          onTap: () => openPage(context, const NotificationSettingsPage()),
        ),
        Item(
          '계정 연결 정보',
          subtitle: app.session.isRemote
              ? '${a.s('provider')} · ${a.s('email', a.s('label'))}'
              : '로컬 계정 · ${a.s('label')}',
          onTap: () => openPage(
            context,
            PolicyPage(
              '계정 연결 정보',
              app.session.isRemote
                  ? '소셜 계정으로 로그인했어요. 가입정보와 거래 기록은 서버에 저장되며 같은 계정으로 다른 기기에서도 확인할 수 있어요. 가입 후 역할 변경은 제공하지 않아요.'
                  : '현재 이 기기에 저장되는 로컬 계정으로 이용 중이에요. 가입 후 역할 변경은 제공하지 않아요.',
            ),
          ),
        ),
        Item(
          '탈퇴 안내',
          onTap: () => openPage(
            context,
            PageFrame(
              title: '탈퇴 안내',
              children: [
                const Info(
                  '진행 중 요청 정리와 기록 처리 정책이 확정되면 탈퇴를 제공할 예정이에요. 현재 계정과 거래 기록은 삭제하지 않아요.',
                ),
                ActionButton(
                  '탈퇴 전 확인 사항',
                  weak: true,
                  onPressed: () async {
                    await confirm(
                      context,
                      '탈퇴 정책을 준비하고 있어요',
                      '진행 중 거래와 보존할 기록에 대한 정책이 확정된 뒤 탈퇴할 수 있어요. 지금은 계정이 삭제되지 않아요.',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ActionButton(
          '로그아웃',
          weak: true,
          onPressed: () async {
            if (await confirm(
              context,
              '로그아웃할까요?',
              app.session.isRemote
                  ? '서버에 저장된 거래 기록은 유지돼요. 같은 소셜 계정으로 다시 로그인하면 이어서 이용할 수 있어요.'
                  : '이 기기에 저장한 거래 기록은 유지돼요. 다른 계정을 선택하면 상대방 화면을 확인할 수 있어요.',
            )) {
              await app.session.signOut();
            }
          },
        ),
      ],
    );
  }
}
