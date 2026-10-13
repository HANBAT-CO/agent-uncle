import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/presentation/app_splash.dart';
import '../../features/auth/presentation/social_login_buttons.dart';
import '../app_services.dart';
import '../domain/models.dart';
import '../domain/profile_validation.dart';
import 'common.dart';
import 'home.dart';
import 'profile_avatar.dart';
import 'profile_time_field.dart';
import 'welcome.dart';

export 'welcome.dart';

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
    if (session.loading) return const AppSplashScreen();
    if (session.authenticated && session.current == null) {
      return PageFrame(
        title: '계정 확인',
        back: false,
        children: [
          Info(session.syncError ?? '계정 정보를 확인하지 못했어요.', error: true),
          ActionButton('다시 시도', onPressed: session.retrySync),
          ActionButton('로그아웃', weak: true, onPressed: session.signOut),
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

class ProfileForm extends StatefulWidget {
  const ProfileForm({this.signup = false, super.key});
  final bool signup;
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  static const retailerMarketOptions = ['동대문', '남대문'];

  final fields = <String, TextEditingController>{};
  final focusNodes = <String, FocusNode>{};
  final anchors = <String, GlobalKey>{};
  final scrollController = ScrollController();
  Map<String, String> errors = {};
  bool submitting = false;
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
  List<String> markets = [], activityDays = [], otherMarkets = [];
  bool marketOtherSelected = false, marketOtherDirty = false;
  int step = 0;
  FormSaver? saver;

  static final phoneNumberFormat = TdsTextFieldFormat(
    reset: (value) {
      final text = value.trim();
      final domestic = text.startsWith('+82') ? '0${text.substring(3)}' : text;
      return TdsTextFieldFormat.phoneNumber.reset!(domestic);
    },
    transform: (value) {
      final limit = value.startsWith('02') ? 10 : 11;
      final formatted = TdsTextFieldFormat.phoneNumber.transform(value);
      // 초과 입력을 잘라 유효한 다른 번호로 저장하지 않고, 제출 시 오류로 안내한다.
      return value.length > limit
          ? '$formatted${value.substring(limit)}'
          : formatted;
    },
  );

  static final businessNumberFormat = TdsTextFieldFormat(
    reset: (value) => value.replaceAll(RegExp(r'\D'), ''),
    transform: (value) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length <= 3) return digits;
      if (digits.length <= 5) {
        return '${digits.substring(0, 3)}-${digits.substring(3)}';
      }
      return '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}';
    },
  );

  bool get retailer =>
      AppScope.read(context).session.current!.role == AppRole.retailer;
  List<int> get steps =>
      retailer ? const [0, 1, 2, 3, 4, 5] : const [0, 2, 3, 4, 5];
  GlobalKey anchor(String key) => anchors.putIfAbsent(key, GlobalKey.new);
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
      'marketOther',
    ]) {
      final stored = a.s(key);
      fields[key] = TextEditingController(
        text: key == 'phone'
            ? phoneNumberFormat.transform(phoneNumberFormat.reset!(stored))
            : key == 'businessNumber'
            ? businessNumberFormat.transform(stored)
            : stored,
      );
      focusNodes[key] = FocusNode();
    }
    salesChannel = a.s('salesChannel');
    transport = a.s('transport');
    activityHours = a.s('activityHours');
    final storedMarkets = [
      for (final market
          in a.list('markets').map((value) => value.toString().trim()))
        if (market.isNotEmpty) market,
    ];
    markets = [
      for (final market in storedMarkets)
        if (retailerMarketOptions.contains(market)) market,
    ];
    otherMarkets = [
      for (final market in storedMarkets)
        if (!retailerMarketOptions.contains(market)) market,
    ];
    marketOtherSelected = otherMarkets.isNotEmpty;
    fields['marketOther']!.text = otherMarkets.join(' · ');
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

  List<String> selectedMarkets() {
    final selected = [
      for (final option in retailerMarketOptions)
        if (markets.contains(option)) option,
    ];
    if (!marketOtherSelected) return selected;
    if (!marketOtherDirty && otherMarkets.isNotEmpty) {
      selected.addAll(otherMarkets.where((market) => market.trim().isNotEmpty));
      return selected.toSet().toList();
    }
    final custom = fields['marketOther']!.text.trim();
    if (custom.isNotEmpty) selected.add(custom);
    return selected.toSet().toList();
  }

  void toggleRetailerMarket(String option) {
    if (markets.contains(option)) {
      markets.remove(option);
    } else {
      markets.add(option);
    }
    changed();
  }

  void toggleOtherMarket() {
    marketOtherSelected = !marketOtherSelected;
    if (marketOtherSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        focusNodes['marketOther']?.requestFocus();
        final target = anchors['marketOther']?.currentContext;
        if (target == null) return;
        await Scrollable.ensureVisible(
          target,
          alignment: .12,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: TdsMotion.quick,
        );
      });
    }
    changed();
  }

  Data values() => {
    for (final e in fields.entries)
      if (e.key != 'marketOther') e.key: e.value.text.trim(),
    if (!retailer) 'name': fields['contact']!.text.trim(),
    'documentId': document,
    'photoId': photo,
    'terms': terms,
    'privacy': privacy,
    'working': working,
    'salesChannel': salesChannel,
    'markets': selectedMarkets(),
    'transport': transport,
    'activityHours': activityHours,
    'activityStart': fields['activityStart']!.text,
    'activityEnd': fields['activityEnd']!.text,
    'activityDays': List.of(activityDays),
  };
  void changed() {
    if (errors.isNotEmpty) {
      final current = fieldErrors();
      errors = {
        for (final key in errors.keys)
          if (current.containsKey(key)) key: current[key]!,
      };
    }
    if (widget.signup) saver!.change(values());
    setState(() {});
  }

  Widget field(
    String key,
    String title, {
    bool numeric = false,
    bool multiline = false,
    String? placeholder,
    ValueChanged<String>? onChanged,
  }) => ProfileInputTheme(
    key: anchor(key),
    child: Field(
      title,
      controller: fields[key]!,
      focusNode: focusNodes[key],
      format: key == 'phone'
          ? phoneNumberFormat
          : key == 'businessNumber'
          ? businessNumberFormat
          : null,
      keyboardType: key == 'phone' ? TextInputType.phone : null,
      numeric: numeric,
      multiline: multiline,
      placeholder: placeholder,
      error: errors[key],
      onChanged: (value) {
        onChanged?.call(value);
        changed();
      },
    ),
  );

  Widget timeField(
    String key,
    String title, {
    required int initialHour,
    bool optional = false,
  }) => ProfileInputTheme(
    key: anchor(key),
    child: ProfileTimeField(
      label: title,
      value: fields[key]!.text,
      initialHour: initialHour,
      optional: optional,
      error: errors[key],
      onChanged: (value) {
        fields[key]!.text = value;
        changed();
      },
    ),
  );

  Widget transportChoice() => TdsGridList(
    columns: TdsTheme.of(context).platform.fontScale > 130
        ? 1
        : MediaQuery.sizeOf(context).width < 390
        ? 2
        : 3,
    children: [
      for (final option in const ['도보', '오토바이', '승용차', '화물차', '기타'])
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Semantics(
            selected: transport == option,
            child: TdsButton(
              size: TdsButtonSize.medium,
              display: TdsButtonDisplay.block,
              color: transport == option
                  ? TdsButtonColor.primary
                  : TdsButtonColor.dark,
              variant: transport == option
                  ? TdsButtonVariant.fill
                  : TdsButtonVariant.weak,
              onPressed: () {
                transport = option;
                changed();
              },
              child: Text(option),
            ),
          ),
        ),
    ],
  );
  @override
  void dispose() {
    saver?.removeListener(_refresh);
    for (final c in fields.values) {
      c.dispose();
    }
    for (final focus in focusNodes.values) {
      focus.dispose();
    }
    scrollController.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (submitting) return;
    try {
      if (widget.signup) await saver!.flush();
      if (!mounted) return;
      if (widget.signup && step > 0) {
        goToStep(steps[steps.indexOf(step) - 1]);
        return;
      }
      if (widget.signup) {
        await chooseRole();
        return;
      }
      setState(() => leaving = true);
      Navigator.maybePop(context);
    } catch (_) {
      /* Saver displays the failure and retains the form. */
    }
  }

  Future<void> chooseRole() async {
    await saver!.flush();
    if (!mounted) return;
    await openPage(context, const RolePage(closeOnSelect: true));
    if (mounted) {
      errors.clear();
      goToStep(0);
    }
  }

  void goToStep(int next) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) scrollController.jumpTo(0);
    });
  }

  Map<String, String> fieldErrors() => profileFieldErrors(
    values(),
    role: AppScope.read(context).session.current!.role!,
    requireSalesChannel: widget.signup && retailer,
  );

  List<String> keysForStep(int n) => switch (n) {
    0 => [
      if (retailer) 'name',
      'contact',
      'phone',
      if (retailer) 'salesChannel',
    ],
    1 => ['businessName', 'businessNumber', 'documentId'],
    2 =>
      retailer
          ? ['address', 'addressDetail']
          : ['pickupArea', 'deliveryArea', 'deadline'],
    3 => retailer ? [] : ['activityStart', 'activityEnd'],
    5 => ['terms', 'privacy'],
    _ => [],
  };

  bool validate() {
    final current = fieldErrors();
    final keys = !widget.signup || step >= 4
        ? [
            for (final n in steps)
              if (step == 5 || !widget.signup || n != 5) ...keysForStep(n),
          ]
        : keysForStep(step);
    final failures = {
      for (final key in keys)
        if (current.containsKey(key)) key: current[key]!,
    };
    setState(() => errors = failures);
    if (failures.isEmpty) return true;
    final first = failures.keys.first;
    if (widget.signup) {
      final targetStep = steps.firstWhere(
        (n) => keysForStep(n).contains(first),
      );
      if (step != targetStep) goToStep(targetStep);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = anchors[first]?.currentContext;
      if (target == null) return;
      final focus = focusNodes[first];
      if (focus?.context != null) {
        focus!.requestFocus();
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
      await Scrollable.ensureVisible(
        target,
        alignment: .12,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: TdsMotion.quick,
      );
    });
    return false;
  }

  Future<void> submit() async {
    if (!validate()) return;
    final app = AppScope.read(context);
    setState(() => submitting = true);
    try {
      if (widget.signup) await saver!.flush();
      if (!mounted) return;
      if (widget.signup && step != 5) {
        goToStep(steps[steps.indexOf(step) + 1]);
        return;
      }
      await app.session.saveProfile(values(), complete: true);
      if (!widget.signup && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => submitting = false);
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

  Widget otherMarketField() => field(
    'marketOther',
    '사입 시장 직접 입력',
    placeholder: '예: 평화시장',
    onChanged: (_) => marketOtherDirty = true,
  );

  Widget marketChoice() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Section('사입 시장 (선택)'),
      Inset(
        child: TdsChip(
          wrap: true,
          variant: TdsChipVariant.weak,
          margin: TdsChipMargin.none,
          children: [
            for (final option in retailerMarketOptions)
              TdsChipItem(
                text: option,
                selected: markets.contains(option),
                onPressed: () => toggleRetailerMarket(option),
              ),
            TdsChipItem(
              text: '그외',
              selected: marketOtherSelected,
              onPressed: toggleOtherMarket,
            ),
          ],
        ),
      ),
      if (marketOtherSelected) otherMarketField(),
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
        scrollController: scrollController,
        back: !widget.signup,
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionButton(
              widget.signup ? (step == 5 ? '가입 완료' : '다음') : '저장하기',
              bottom: true,
              hasPaddingBottom: !widget.signup || retailer,
              key: ValueKey('profile-submit-$step'),
              onPressed: submit,
            ),
            if (widget.signup)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: retailer ? 8 : 0,
                ),
                child: TdsTextButton(
                  size: TdsTextButtonSize.small,
                  colorToken: 'grey600',
                  disabled: submitting,
                  onPressed: leave,
                  child: retailer
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('이전'),
                        )
                      : const SizedBox(
                          height: 44,
                          child: Center(child: Text('이전')),
                        ),
                ),
              ),
          ],
        ),
        children: [
          if (widget.signup)
            PageHeading(
              headings[step],
              eyebrow: '가입 · ${steps.indexOf(step) + 1} / ${steps.length}',
            ),
          if (show(0))
            FigmaSurface(
              children: [
                if (!widget.signup) const Section('담당자 정보'),
                if (retailer) field('name', '매장명'),
                field('contact', retailer ? '담당자명' : '이름(실명)'),
                field('phone', '연락처', placeholder: '010-1234-5678'),
                AttachmentField(
                  label: '프로필 사진',
                  ids: photo.isEmpty ? [] : [photo],
                  preview: Inset(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ProfileAvatar(a, photoId: photo, large: true),
                    ),
                  ),
                  onChanged: (ids) {
                    photo = ids.firstOrNull ?? '';
                    changed();
                  },
                ),
                if (retailer)
                  Column(
                    key: anchor('salesChannel'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Section('판매 채널'),
                      const Info('온라인과 오프라인을 함께 선택할 수 있어요.'),
                      Inset(
                        child: TdsChip(
                          wrap: true,
                          variant: TdsChipVariant.weak,
                          margin: TdsChipMargin.none,
                          children: [
                            for (final channel in const ['온라인', '오프라인'])
                              TdsChipItem(
                                text: channel,
                                selected: salesChannel.contains(channel),
                                onPressed: () {
                                  final selected = <String>{
                                    if (salesChannel.contains('온라인')) '온라인',
                                    if (salesChannel.contains('오프라인')) '오프라인',
                                  };
                                  if (!selected.add(channel)) {
                                    selected.remove(channel);
                                  }
                                  salesChannel = selected.length == 2
                                      ? '온라인·오프라인 병행'
                                      : selected.firstOrNull ?? '';
                                  changed();
                                },
                              ),
                          ],
                        ),
                      ),
                      if (errors['salesChannel'] != null)
                        Semantics(
                          liveRegion: true,
                          child: Info(errors['salesChannel']!, error: true),
                        ),
                    ],
                  ),
              ],
            ),
          if (retailer && show(1))
            FigmaSurface(
              children: [
                if (!widget.signup) const Section('사업자 정보'),
                field('businessName', '사업자명'),
                field(
                  'businessNumber',
                  '사업자등록번호',
                  numeric: true,
                  placeholder: '111-11-11111',
                ),
                AttachmentField(
                  key: anchor('documentId'),
                  label: '사업자등록증 (필수)',
                  document: true,
                  error: errors['documentId'],
                  ids: document.isEmpty ? [] : [document],
                  onChanged: (ids) {
                    document = ids.firstOrNull ?? '';
                    changed();
                  },
                ),
                const Info('서류 제출과 사업자 검증은 별개예요.'),
              ],
            ),
          if (show(2))
            FigmaSurface(
              children: [
                if (retailer) ...[
                  if (!widget.signup) const Section('기본 배송지'),
                  field('address', '주소'),
                  field('addressDetail', '상세주소'),
                  if (!widget.signup)
                    field('deliveryNote', '배송 참고사항', multiline: true),
                  if (!widget.signup) const Info('변경한 기본 배송지는 새 요청부터 적용돼요.'),
                ] else ...[
                  if (!widget.signup) const Section('활동·운영 정보'),
                  field('pickupArea', '도매 픽업 구역'),
                  const Info('시장·상가·건물·층까지 입력해 주세요.'),
                  field('deliveryArea', '소매 배송 지역'),
                  timeField('deadline', '요청 마감시간', initialHour: 23),
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
            ),
          if (show(3))
            FigmaSurface(
              children: [
                if (retailer)
                  marketChoice()
                else
                  multiChoice('사입 시장 (선택)', const ['동대문', '남대문'], markets),
                if (!retailer) ...[
                  const Section('이동 수단 (선택)'),
                  transportChoice(),
                  const Section('활동 시간대 (선택)'),
                  Choices(
                    options: const ['주간 09–18', '야간 22–06', '일정에 따라 달라요'],
                    value: activityHours,
                    onChanged: (v) {
                      activityHours = v;
                      changed();
                    },
                  ),
                  timeField(
                    'activityStart',
                    '활동 시작',
                    initialHour: 22,
                    optional: true,
                  ),
                  timeField(
                    'activityEnd',
                    '활동 종료',
                    initialHour: 6,
                    optional: true,
                  ),
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
            ),
          if (widget.signup && step == 4) ...[
            FigmaSurface(
              children: [
                Item(
                  retailer ? fields['name']!.text : fields['contact']!.text,
                  subtitle:
                      '${fields['contact']!.text} · ${fields['phone']!.text}',
                ),
                QuantityRow('역할', a.role!.label),
                if (retailer) ...[
                  QuantityRow('판매 채널', salesChannel),
                  Item('사업자명', subtitle: fields['businessName']!.text),
                  Item('사업자등록번호', subtitle: fields['businessNumber']!.text),
                  QuantityRow('사업자 서류', document.isEmpty ? '미첨부' : '첨부 완료'),
                ],
                Item(
                  retailer ? '기본 배송지' : '활동 구역',
                  subtitle: retailer
                      ? '${fields['address']!.text} ${fields['addressDetail']!.text}'
                      : '${fields['pickupArea']!.text} · ${fields['deliveryArea']!.text}',
                ),
                Item(
                  '사입 시장',
                  subtitle: selectedMarkets().isEmpty
                      ? '미선택'
                      : selectedMarkets().join(' · '),
                ),
              ],
            ),
            Item('정보 수정하기', onTap: () => goToStep(0)),
          ],
          if (widget.signup && step == 5) ...[
            FigmaSurface(
              children: [
                Inset(
                  key: anchor('terms'),
                  child: TdsCheckbox(
                    checked: terms,
                    onChanged: (v) {
                      terms = v;
                      changed();
                    },
                    child: const Text('[필수] 서비스 이용 동의 확인'),
                  ),
                ),
                if (errors['terms'] != null)
                  Semantics(
                    liveRegion: true,
                    child: Info(errors['terms']!, error: true),
                  ),
                Inset(
                  key: anchor('privacy'),
                  child: TdsCheckbox(
                    checked: privacy,
                    onChanged: (v) {
                      privacy = v;
                      changed();
                    },
                    child: const Text('[필수] 개인정보 처리 동의 확인'),
                  ),
                ),
                if (errors['privacy'] != null)
                  Semantics(
                    liveRegion: true,
                    child: Info(errors['privacy']!, error: true),
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
          // 자동 저장 결과가 입력칸 위에 끼어들면 키보드가 열린 상태에서
          // 폼과 터치 위치가 이동한다. 안내는 현재 단계의 입력 뒤에 둔다.
          if (saver!.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Info(saver!.error!, error: true),
            ),
            ActionButton(
              '저장 다시 시도',
              weak: true,
              onPressed: () => saver!.flush(),
            ),
          ],
        ],
      ),
    );
  }
}

class PolicyPage extends StatelessWidget {
  const PolicyPage(this.title, this.description, {super.key});
  final String title, description;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: title,
    children: [
      FigmaSurface(children: [Info(description)]),
    ],
  );
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
        FigmaSurface(
          children: [
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
    final theme = TdsTheme.of(context);
    final retailer = a.role == AppRole.retailer;
    final address = [
      a.s('address').trim(),
      a.s('addressDetail').trim(),
    ].where((value) => value.isNotEmpty).join('\n');
    final markets = [
      for (final market
          in a.list('markets').map((value) => value.toString().trim()))
        if (market.isNotEmpty) market,
    ];
    final notifications = mapOf(a.data, 'notificationSettings');
    final enabledNotifications = [
      'connection',
      'request',
      'delivery',
      'chat',
    ].where((key) => notifications[key] != false).length;
    Widget divider() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: TdsBorder(),
    );
    Widget infoRow(String label, String value) => TdsListRow(
      contents: TdsListRowTexts(
        type: TdsListRowTextType.row2TypeA,
        top: Text(label),
        bottom: Text(value),
        topProps: TdsListRowTextStyle(
          typography: TdsTypography.t7,
          color: theme.color('grey600'),
        ),
        bottomProps: const TdsListRowTextStyle(
          typography: TdsTypography.t6,
          fontWeight: TdsFontWeight.semibold,
        ),
      ),
    );
    void editProfile() => openPage(context, const ProfileForm());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TdsSpacing(16),
        FigmaSurface(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TdsBadge(
                          size: TdsBadgeSize.small,
                          color: TdsBadgeColor.blue,
                          variant: TdsBadgeVariant.weak,
                          child: Text(a.role!.label),
                        ),
                        const TdsSpacing(12),
                        TdsText(
                          a.name,
                          typography: TdsTypography.t2,
                          fontWeight: TdsFontWeight.bold,
                        ),
                        if (a.s('contact').isNotEmpty) ...[
                          const TdsSpacing(4),
                          TdsText(
                            '${a.s('contact')} · 담당자',
                            typography: TdsTypography.t6,
                            color: theme.color('grey600'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ProfileAvatar(a, large: true),
                ],
              ),
            ),
            divider(),
            if (retailer) ...[
              infoRow('기본 배송지', address.isEmpty ? '배송지를 등록해 주세요' : address),
              divider(),
              infoRow('사입 시장', markets.isEmpty ? '등록 전' : markets.join(' · ')),
            ] else ...[
              infoRow(
                '도매 픽업 구역',
                a.s('pickupArea').trim().isEmpty
                    ? '픽업 구역을 등록해 주세요'
                    : a.s('pickupArea').trim(),
              ),
              divider(),
              infoRow(
                '소매 배송 지역',
                a.s('deliveryArea').trim().isEmpty
                    ? '배송 지역을 등록해 주세요'
                    : a.s('deliveryArea').trim(),
              ),
              divider(),
              infoRow('업무 상태', a.b('working') ? '업무 중' : '휴무 중'),
              divider(),
              infoRow(
                '요청 마감시간',
                a.s('deadline').trim().isEmpty
                    ? '마감시간 등록 전'
                    : a.s('deadline').trim(),
              ),
            ],
            divider(),
            Inset(
              child: TdsButton(
                display: TdsButtonDisplay.block,
                size: TdsButtonSize.large,
                variant: TdsButtonVariant.weak,
                onPressed: editProfile,
                child: const Text('프로필 수정'),
              ),
            ),
          ],
        ),
        const Section('설정'),
        FigmaSurface(
          children: [
            Item(
              '사업자 서류',
              leading: const FigmaIcon('document'),
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
              leading: const FigmaIcon('bell'),
              subtitle: enabledNotifications == 4
                  ? '모든 알림 켜짐'
                  : enabledNotifications == 0
                  ? '모든 알림 꺼짐'
                  : '4개 중 $enabledNotifications개 알림 켜짐',
              onTap: () => openPage(context, const NotificationSettingsPage()),
            ),
            Item(
              '계정 연결 정보',
              leading: const FigmaIcon('person'),
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
          ],
        ),
        const TdsSpacing(24),
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
        Center(
          child: SizedBox(
            height: 48,
            child: TdsTextButton(
              size: TdsTextButtonSize.small,
              colorToken: 'grey600',
              onPressed: () => openPage(
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
              child: const Text('탈퇴 안내'),
            ),
          ),
        ),
      ],
    );
  }
}
