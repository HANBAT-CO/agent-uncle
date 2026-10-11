import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/social_login_buttons.dart';
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
      back: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SocialLoginButtons(
            onSignIn: (provider) => session.signInWithSocial(provider.name),
          ),
          const TdsSpacing(12),
        ],
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Align(alignment: Alignment.centerLeft, child: AppLogo()),
        ),
        const PageHeading(
          '사입의 시작부터 수령까지',
          description: '요청하고, 확보하고, 전달해요.\n거래처와 같은 내용을 함께 확인하세요.',
        ),
        const TdsSpacing(32),
        const FigmaSurface(
          children: [
            Item(
              '사입 요청',
              subtitle: '상품·옵션·수량을 정확하게 전달해요',
              trailing: FigmaIcon('bag'),
            ),
            Item(
              '확보와 전달',
              subtitle: '회차별 진행 상황을 함께 확인해요',
              trailing: FigmaIcon('check'),
            ),
            Item(
              '거래처와 대화',
              subtitle: '요청에 연결된 대화를 이어가요',
              trailing: FigmaIcon('chat'),
            ),
          ],
        ),
        if (session.syncError != null) Info(session.syncError!, error: true),
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
            onPressed: () => AppScope.read(context).session.finishOnboarding(),
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
      PageHeading(titles[index], description: descriptions[index]),
      const TdsSpacing(24),
      FigmaSurface(
        children: [
          Item(
            const ['사입 요청', '확보 · 전달 · 수령', '요청에 연결된 채팅'][index],
            trailing: FigmaIcon(
              const ['bag', 'check', 'chat'][index],
              selected: true,
            ),
          ),
          const QuantityRow('상품과 옵션', '요청마다 정확하게'),
          QuantityRow(
            const ['요청 수량', '진행 상황', '처리 기록'][index],
            const ['필요한 만큼', '회차별로 확인', '함께 확인'][index],
          ),
        ],
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
      back: false,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Align(alignment: Alignment.centerLeft, child: AppLogo()),
        ),
        const PageHeading('사입의 시작부터 수령까지'),
        const Info('지금은 이 기기에 저장하는 로컬 체험 모드예요. 계정을 나누어 만들면 양쪽 역할을 확인할 수 있어요.'),
        const Inset(
          child: SocialLoginButton(
            provider: SocialLoginProvider.google,
            disabled: true,
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

class RolePage extends StatefulWidget {
  const RolePage({this.closeOnSelect = false, super.key});
  final bool closeOnSelect;
  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  AppRole? selected;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '역할 선택',
    back: widget.closeOnSelect,
    bottom: ActionButton(
      '선택한 역할로 계속',
      bottom: true,
      enabled: selected != null,
      onPressed: () async {
        await AppScope.read(context).session.chooseRole(selected!);
        if (widget.closeOnSelect && context.mounted) Navigator.pop(context);
      },
    ),
    children: [
      const PageHeading('어떤 일을 하고 계신가요?', description: '업무에 맞는 화면을 준비할게요.'),
      for (final role in AppRole.values)
        FigmaSurface(
          children: [
            Inset(
              child: TdsCheckbox(
                inputType: TdsCheckboxInputType.radio,
                checked: selected == role,
                onChanged: (_) => setState(() => selected = role),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TdsText(role.label, fontWeight: TdsFontWeight.semibold),
                    TdsText(
                      role == AppRole.retailer
                          ? '사입을 요청하고 받은 상품을 확인해요.'
                          : '요청을 받아 상품을 확보하고 전달해요.',
                      typography: TdsTypography.t6,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  String document = '',
      photo = '',
      salesChannel = '',
      transport = '',
      activityHours = '';
  List<String> markets = [], activityDays = [];
  int step = 0;
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
      'activityStart',
      'activityEnd',
    ]) {
      fields[key] = TextEditingController(text: a.s(key));
    }
    salesChannel = a.s('salesChannel');
    transport = a.s('transport');
    activityHours = a.s('activityHours');
    markets = List.of(a.list('markets'));
    activityDays = List.of(a.list('activityDays'));
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
    'salesChannel': salesChannel,
    'markets': List.of(markets),
    'transport': transport,
    'activityHours': activityHours,
    'activityStart': fields['activityStart']!.text,
    'activityEnd': fields['activityEnd']!.text,
    'activityDays': List.of(activityDays),
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
    try {
      if (widget.signup) await saver!.flush();
      if (!mounted) return;
      if (widget.signup && step > 0) {
        setState(() => step--);
        return;
      }
      setState(() => leaving = true);
      Navigator.maybePop(context);
    } catch (_) {
      /* Saver displays the failure and retains the form. */
    }
  }

  void validateStep(bool retailer) {
    final keys = switch (step) {
      0 => ['name', 'contact', 'phone'],
      1 => ['businessName', 'businessNumber'],
      2 =>
        retailer
            ? ['address', 'addressDetail']
            : ['pickupArea', 'deliveryArea', 'deadline'],
      _ => <String>[],
    };
    for (final key in keys) {
      if (fields[key]!.text.trim().isEmpty) {
        throw const AppFailure('필수 항목을 모두 입력해 주세요.');
      }
    }
    if (step == 0 &&
        !RegExp(r'^\+?[\d -]{9,16}$').hasMatch(fields['phone']!.text.trim())) {
      throw const AppFailure('연락처를 확인해 주세요.');
    }
    if (step == 1) {
      if (!RegExp(
        r'^\d{10}$',
      ).hasMatch(fields['businessNumber']!.text.replaceAll('-', '').trim())) {
        throw const AppFailure('사업자등록번호 10자리를 확인해 주세요.');
      }
      if (document.isEmpty) throw const AppFailure('사업자등록증을 첨부해 주세요.');
    }
    for (final key in ['activityStart', 'activityEnd']) {
      final time = fields[key]!.text.trim();
      if (time.isNotEmpty &&
          !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
        throw const AppFailure('활동 시간은 22:00처럼 입력해 주세요.');
      }
    }
  }

  Widget multiChoice(
    String label,
    List<String> options,
    List<String> selected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Section(label),
      for (final option in options)
        Inset(
          child: TdsCheckbox(
            checked: selected.contains(option),
            child: Text(option),
            onChanged: (v) {
              if (v) {
                selected.add(option);
              } else {
                selected.remove(option);
              }
              changed();
            },
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.session.current!;
    final retailer = a.role == AppRole.retailer;
    bool show(int n) => !widget.signup || step == n;
    final headings = [
      '연락받을 정보를 알려주세요',
      '사업자 정보를 확인해 주세요',
      retailer ? '상품을 받을 곳을 알려주세요' : '활동 구역을 알려주세요',
      retailer ? '어디에서 사입하시나요?' : '어떻게 활동하시나요?',
      '입력한 정보를 확인해 주세요',
      '이용에 필요한 동의를 확인해요',
    ];
    return PopScope(
      canPop: leaving || !widget.signup,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: PageFrame(
        title: widget.signup ? '${a.role!.label} 가입' : '내 정보 수정',
        scrollKey: 'profile-${widget.signup ? step : 'edit'}',
        back: !widget.signup || step > 0,
        bottom: ActionButton(
          widget.signup ? (step == 5 ? '가입 완료' : '다음') : '저장하기',
          bottom: true,
          key: ValueKey('profile-submit-$step'),
          onPressed: () async {
            validateStep(retailer);
            if (widget.signup) await saver!.flush();
            if (widget.signup && step < 5) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => step++);
              return;
            }
            await app.session.saveProfile(values(), complete: true);
            if (!widget.signup && context.mounted) Navigator.pop(context);
          },
        ),
        children: [
          if (widget.signup)
            PageHeading(
              headings[step],
              eyebrow: '가입 · ${step + 1} / 6',
              description: '입력한 정보는 자동으로 저장돼요.',
            ),
          if (widget.signup && step == 0)
            Item(
              '역할 다시 선택',
              onTap: () async {
                try {
                  await saver!.flush();
                  if (context.mounted) {
                    await openPage(
                      context,
                      const RolePage(closeOnSelect: true),
                    );
                  }
                } catch (_) {}
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
          if (show(0)) ...[
            if (!widget.signup) const Section('담당자 정보'),
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
            if (retailer) ...[
              const Section('판매 채널 (선택)'),
              Choices(
                options: const ['온라인', '오프라인', '온라인·오프라인 병행'],
                value: salesChannel,
                onChanged: (v) {
                  salesChannel = v;
                  changed();
                },
              ),
            ],
          ],
          if (show(1)) ...[
            if (!widget.signup) const Section('사업자 정보'),
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
            const Info('사업자등록증 사진 또는 PDF를 첨부해 주세요. 서류 제출과 사업자 검증은 별개예요.'),
          ],
          if (show(2)) ...[
            if (retailer) ...[
              if (!widget.signup) const Section('기본 배송지'),
              field('address', '주소'),
              field('addressDetail', '상세주소'),
              field('deliveryNote', '배송 참고사항', multiline: true),
              if (!widget.signup) const Info('변경한 기본 배송지는 새 요청부터 적용돼요.'),
            ] else ...[
              if (!widget.signup) const Section('활동·운영 정보'),
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
          ],
          if (show(3)) ...[
            multiChoice('사입 시장 (선택)', const ['동대문', '남대문'], markets),
            if (!retailer) ...[
              const Section('이동 수단 (선택)'),
              Choices(
                options: const ['도보', '오토바이', '승용차', '화물차', '기타'],
                value: transport,
                onChanged: (v) {
                  transport = v;
                  changed();
                },
              ),
              const Section('활동 시간대 (선택)'),
              Choices(
                options: const ['주간 09–18', '야간 22–06', '일정에 따라 달라요'],
                value: activityHours,
                onChanged: (v) {
                  activityHours = v;
                  changed();
                },
              ),
              field('activityStart', '활동 시작 (HH:mm, 선택)'),
              field('activityEnd', '활동 종료 (HH:mm, 선택)'),
              const Info('종료가 시작보다 이르면 다음 날 종료예요. 요청 마감과 휴무 안내는 별도로 적용돼요.'),
              multiChoice('활동 요일 (선택)', const [
                '월',
                '화',
                '수',
                '목',
                '금',
                '토',
                '일',
              ], activityDays),
            ],
          ],
          if (widget.signup && step == 4) ...[
            FigmaSurface(
              children: [
                Item(
                  fields['name']!.text,
                  subtitle:
                      '${fields['contact']!.text} · ${fields['phone']!.text}',
                ),
                QuantityRow('역할', a.role!.label),
                QuantityRow('사업자명', fields['businessName']!.text),
                QuantityRow('사업자등록번호', fields['businessNumber']!.text),
                QuantityRow('사업자 서류', document.isEmpty ? '미첨부' : '첨부 완료'),
                Item(
                  retailer ? '기본 배송지' : '활동 구역',
                  subtitle: retailer
                      ? '${fields['address']!.text} ${fields['addressDetail']!.text}'
                      : '${fields['pickupArea']!.text} · ${fields['deliveryArea']!.text}',
                ),
                QuantityRow(
                  '사입 시장',
                  markets.isEmpty ? '미선택' : markets.join(' · '),
                ),
              ],
            ),
            Item('정보 수정하기', onTap: () => setState(() => step = 0)),
          ],
          if (widget.signup && step == 5) ...[
            const Info('개발용 동의 화면이에요. 정식 약관·개인정보 처리방침은 서비스 운영 전에 확정돼요.'),
            FigmaSurface(
              children: [
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
                          ? '현재 개발 검증 중인 서비스입니다. 정식 약관과 개인정보 처리방침은 확정 전입니다. 가입정보·거래 기록·첨부파일은 서버에 저장되며, 거래에 필요한 정보는 연결된 상대방과 공유됩니다. 사업자 서류는 상대방에게 공개되지 않습니다.'
                          : '현재는 로컬 개발용 가입 흐름입니다. 정식 약관과 개인정보 처리방침은 확정 전이며, 입력과 첨부는 이 기기에 저장됩니다.',
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.signup)
            Inset(
              child: TdsTextButton(
                size: TdsTextButtonSize.small,
                onPressed: () async {
                  try {
                    await saver!.flush();
                    await app.session.signOut();
                  } catch (_) {}
                },
                child: const Text('저장하고 로그아웃'),
              ),
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
        FigmaSurface(
          children: [
            Item(a.name, subtitle: '${a.role!.label} · ${a.s('contact')}'),
            if (a.s('photoId').isNotEmpty)
              AttachmentPreview(a.s('photoId'), compact: true),
            Item(
              '기본·사업자·운영 정보 수정',
              onTap: () => openPage(context, const ProfileForm()),
            ),
          ],
        ),
        const Section('업무 정보'),
        FigmaSurface(
          children: [
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
          ],
        ),
        const Section('계정 관리'),
        FigmaSurface(
          children: [
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
          ],
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
