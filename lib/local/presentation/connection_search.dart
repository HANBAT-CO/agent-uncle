import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'profile_avatar.dart';
import 'social.dart' show ConnectionCard, PartnerPage;

/// 검색 목록에는 서버에서 공개용으로 반환한 프로필만 사용한다.
class AddConnectionPage extends StatefulWidget {
  const AddConnectionPage({super.key});

  @override
  State<AddConnectionPage> createState() => _AddConnectionPageState();
}

class _AddConnectionPageState extends State<AddConnectionPage> {
  static const _pageSize = 20;
  final _query = TextEditingController();
  final _region = TextEditingController();
  final _minFee = TextEditingController();
  final _maxFee = TextEditingController();
  final _code = TextEditingController();
  final _operations = <String, String>{};
  final _sent = <String, String>{};
  final _results = <Account>[];
  WorkspaceRepository? _workspace;
  Timer? _debounce;
  Account? _invited;
  int _mode = 0, _generation = 0, _codeGeneration = 0, _offset = 0;
  bool _loading = true, _hasMore = false, _filtersOpen = false;
  String _activeQuery = '', _activeRegion = '';
  int? _activeMinFee, _activeMaxFee;
  String? _searchError, _minimumError, _maximumError, _clipboardMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workspace != null) return;
    _workspace = AppScope.read(context).workspace;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_search());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final controller in [_query, _region, _minFee, _maxFee, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _queryChanged(String value) {
    _debounce?.cancel();
    // 새 검색어를 입력한 뒤 이전 요청이 끝나도 오래된 목록을 표시하지 않는다.
    _generation++;
    setState(() {
      _loading = true;
      _results.clear();
      _offset = 0;
      _hasMore = false;
      _searchError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  bool _validateFees() {
    String? error(String raw) {
      if (raw.trim().isEmpty) return null;
      final value = int.tryParse(raw.trim());
      if (value == null || value < 0) {
        return '0 이상의 금액을 숫자로 입력해 주세요.';
      }
      return value > maxPartnerFee ? '수수료는 10억 원 이하로 입력해 주세요.' : null;
    }

    _minimumError = error(_minFee.text);
    _maximumError = error(_maxFee.text);
    final minimum = int.tryParse(_minFee.text.trim());
    final maximum = int.tryParse(_maxFee.text.trim());
    if (_minimumError == null &&
        _maximumError == null &&
        minimum != null &&
        maximum != null &&
        minimum > maximum) {
      _maximumError = '최대 금액은 최소 금액보다 크거나 같아야 해요.';
    }
    return _minimumError == null && _maximumError == null;
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    if (!mounted || _workspace == null || (more && _loading)) return;
    final generation = ++_generation;
    final retailer =
        AppScope.read(context).session.current?.role == AppRole.retailer;
    if (!more && retailer && !_validateFees()) {
      setState(() {
        _filtersOpen = true;
        _loading = false;
        _hasMore = false;
      });
      return;
    }
    final offset = more ? _offset : 0;
    setState(() {
      _loading = true;
      _searchError = null;
      if (!more) {
        _results.clear();
        _hasMore = false;
        _offset = 0;
        _activeQuery = _query.text.trim();
        _activeRegion = retailer ? _region.text.trim() : '';
        _activeMinFee = retailer ? int.tryParse(_minFee.text.trim()) : null;
        _activeMaxFee = retailer ? int.tryParse(_maxFee.text.trim()) : null;
      }
    });
    try {
      final found = await _workspace!.searchPartners(
        query: _activeQuery,
        region: _activeRegion,
        minFee: _activeMinFee,
        maxFee: _activeMaxFee,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final present = _results.map((account) => account.id).toSet();
        _results.addAll(found.where((account) => present.add(account.id)));
        _offset = offset + found.length;
        _hasMore = found.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _searchError = error.toString();
      });
    }
  }

  void _codeChanged(String _) {
    _codeGeneration++;
    setState(() {
      _invited = null;
      _clipboardMessage = null;
    });
  }

  Future<void> _lookupCode() async {
    FocusScope.of(context).unfocus();
    final input = _code.text.trim();
    if (input.isEmpty) throw const AppFailure('상대방의 초대 코드를 입력해 주세요.');
    final generation = ++_codeGeneration;
    final found = await _workspace!.lookupCode(input);
    if (!mounted || generation != _codeGeneration) return;
    setState(() => _invited = found);
  }

  Future<void> _copy(String value, String message) async {
    if (value.trim().isEmpty) throw const AppFailure('복사할 코드가 없어요.');
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _clipboardMessage = message);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) throw const AppFailure('복사한 초대 코드가 없어요.');
    if (text.length > 128) throw const AppFailure('초대 코드만 복사해서 붙여넣어 주세요.');
    _code.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _codeChanged(text);
  }

  Future<void> _request(Account account, {bool fromCode = false}) async {
    if (fromCode) {
      final input = _code.text.trim();
      final verified = await _workspace!.lookupCode(input);
      if (!mounted) return;
      if (verified.id != account.id || _code.text.trim() != input) {
        throw const AppFailure('초대 코드가 바뀌었어요. 상대방을 다시 확인해 주세요.');
      }
    }
    final operation = _operations.putIfAbsent(account.id, newId);
    final id = await _workspace!.connect(account.id, operation);
    // 성공한 요청의 ID는 폐기하고, 통신 실패 때만 같은 ID로 재시도한다.
    _operations.remove(account.id);
    if (!mounted) return;
    setState(() => _sent[account.id] = id);
  }

  Widget _partnerCard(Account account, {bool fromCode = false}) {
    final app = AppScope.of(context);
    final ownId = app.session.current!.id;
    final links = app.workspace
        .records('connections')
        .where(
          (record) =>
              (record.s('from') == ownId && record.s('to') == account.id) ||
              (record.s('to') == ownId && record.s('from') == account.id),
        );
    final connected = links
        .where((record) => record.s('status') == 'accepted')
        .firstOrNull;
    final pending = links
        .where((record) => record.s('status') == 'pending')
        .firstOrNull;
    final sentId = _sent[account.id];
    final sentRecord = links.where((record) => record.id == sentId).firstOrNull;
    final recentlySent = sentId != null && sentRecord == null;
    final incoming = pending != null && pending.s('to') == ownId;
    final nickname = account.s('nickname').trim();
    final title = nickname.isEmpty ? account.name : nickname;
    final subtitle = [
      account.s('publicCode'),
      if (nickname.isNotEmpty && nickname != account.name) account.name,
      account.role!.label,
    ].where((value) => value.isNotEmpty).join(' · ');
    final regions = [
      account.s('pickupArea'),
      account.s('deliveryArea'),
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    final fee = account.data['fee'];
    return FigmaSurface(
      key: ValueKey('partner-${account.id}'),
      children: [
        Item(title, subtitle: subtitle, leading: ProfileAvatar(account)),
        if (regions.isNotEmpty)
          Item('활동 지역', subtitle: regions, leading: const FigmaIcon('pin')),
        if (account.role == AppRole.uncle)
          Item(
            '거래 수수료',
            subtitle: fee is num ? '${fee.toInt()}원 / 건' : '상대방과 협의',
          ),
        if (account.s('intro').trim().isNotEmpty) Info(account.s('intro')),
        if (connected != null)
          ActionButton(
            '연결된 거래처 보기',
            weak: true,
            onPressed: () => openPage(context, PartnerPage(account.id)),
          )
        else if (incoming)
          ActionButton(
            '받은 연결 요청 확인',
            weak: true,
            onPressed: () => openPage(
              context,
              PageFrame(title: '연결 요청', children: [ConnectionCard(pending)]),
            ),
          )
        else
          ActionButton(
            pending != null || recentlySent ? '수락 대기 중' : '거래 요청 보내기',
            enabled: pending == null && !recentlySent,
            onPressed: () => _request(account, fromCode: fromCode),
          ),
      ],
    );
  }

  List<Widget> _searchContent(bool retailer) => [
    TdsSearchField(
      key: const ValueKey('partner-search'),
      controller: _query,
      placeholder: '닉네임 또는 #0000으로 검색',
      onChanged: _queryChanged,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        unawaited(_search());
      },
    ),
    if (retailer) ...[
      Inset(
        child: TdsChip(
          kind: TdsChipKind.action,
          margin: TdsChipMargin.none,
          wrap: true,
          children: [
            TdsChipItem(
              text: _filtersOpen ? '지역·수수료 필터 접기' : '지역·수수료 필터',
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            ),
          ],
        ),
      ),
      if (_filtersOpen)
        FigmaSurface(
          children: [
            Field('활동 지역', controller: _region, placeholder: '예: 동대문, 서울'),
            Field(
              '최소 수수료 (원/건)',
              controller: _minFee,
              numeric: true,
              error: _minimumError,
            ),
            Field(
              '최대 수수료 (원/건)',
              controller: _maxFee,
              numeric: true,
              error: _maximumError,
            ),
            ActionButton(
              '필터 적용',
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await _search();
              },
            ),
            Inset(
              child: TdsTextButton(
                size: TdsTextButtonSize.small,
                onPressed: () {
                  for (final field in [_region, _minFee, _maxFee]) {
                    field.clear();
                  }
                  unawaited(_search());
                },
                child: const Text('필터 초기화'),
              ),
            ),
          ],
        ),
    ],
    Section(retailer ? '함께할 사입삼촌' : '함께할 소매업자'),
    if (_loading && _results.isEmpty) const Info('거래처를 찾고 있어요…'),
    if (!_loading && _searchError == null && _results.isEmpty)
      const EmptyState.titleOnly('검색 결과가 없어요', icon: 'store'),
    for (final account in _results) _partnerCard(account),
    if (_searchError != null) ...[
      Info(_searchError!, error: true),
      ActionButton(
        '다시 검색',
        weak: true,
        onPressed: () => _search(more: _results.isNotEmpty),
      ),
    ] else if (_hasMore)
      ActionButton(
        '더 보기',
        weak: true,
        enabled: !_loading,
        onPressed: () => _search(more: true),
      ),
    if (_loading && _results.isNotEmpty) const Info('더 찾아보고 있어요…'),
  ];

  List<Widget> _invitationContent(Account me) => [
    const Section('내 초대 코드'),
    FigmaSurface(
      children: [
        Item(
          me.s('code'),
          subtitle: '유효기간 ${displayTime(me.s('codeExpires'))}',
        ),
        ActionButton(
          '초대 코드 복사',
          icon: 'copy',
          weak: true,
          onPressed: () => _copy(me.s('code'), '내 초대 코드를 복사했어요.'),
        ),
        ActionButton(
          '코드 새로 발급',
          icon: 'refresh',
          weak: true,
          onPressed: () async {
            await _workspace!.renewCode();
            if (mounted) setState(() => _clipboardMessage = '새 초대 코드를 발급했어요.');
          },
        ),
      ],
    ),
    const Section('상대방 초대 코드'),
    FigmaSurface(
      children: [
        TdsTextField(
          key: const ValueKey('partner-invite-code'),
          variant: TdsTextFieldVariant.box,
          label: '초대 코드',
          labelOption: TdsTextFieldLabelOption.sustain,
          placeholder: '복사한 초대 코드를 붙여넣어 주세요',
          controller: _code,
          maxLength: 128,
          onChanged: _codeChanged,
        ),
        ActionButton('붙여넣기', weak: true, icon: 'copy', onPressed: _paste),
        ActionButton(
          '입력한 코드 복사',
          weak: true,
          onPressed: () => _copy(_code.text, '입력한 코드를 복사했어요.'),
        ),
        ActionButton('상대방 확인', onPressed: _lookupCode),
      ],
    ),
    if (_invited != null) _partnerCard(_invited!, fromCode: true),
  ];

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).session.current!;
    final retailer = me.role == AppRole.retailer;
    return PageFrame(
      title: '상대방 연결',
      children: [
        const PageHeading('함께할 거래처를 찾아요'),
        if (me.s('publicCode').isNotEmpty)
          FigmaSurface(
            children: [
              Item('내 검색 코드 ${me.s('publicCode')}'),
              ActionButton(
                '검색 코드 복사',
                weak: true,
                icon: 'copy',
                onPressed: () => _copy(me.s('publicCode'), '내 검색 코드를 복사했어요.'),
              ),
            ],
          ),
        if (_clipboardMessage != null)
          Semantics(liveRegion: true, child: Info(_clipboardMessage!)),
        TdsTab(
          semanticLabel: '거래처 찾는 방법',
          items: [
            TdsTabItem(text: '검색으로 찾기', selected: _mode == 0),
            TdsTabItem(text: '초대코드', selected: _mode == 1),
          ],
          onChanged: (value) {
            FocusScope.of(context).unfocus();
            setState(() => _mode = value);
          },
        ),
        if (_mode == 0)
          ..._searchContent(retailer)
        else
          ..._invitationContent(me),
      ],
    );
  }
}
