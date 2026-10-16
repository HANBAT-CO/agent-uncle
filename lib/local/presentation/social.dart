import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/media/native_media_picker.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'requests.dart';
import 'delivery.dart';
import 'profile_avatar.dart';
import 'connection_search.dart';
import 'chat_message_actions.dart';
import 'billing.dart';
import 'team_work.dart';

export 'connection_search.dart' show AddConnectionPage;

class ConnectionsList extends StatefulWidget {
  const ConnectionsList({super.key});
  @override
  State<ConnectionsList> createState() => _ConnectionsListState();
}

class _ConnectionsListState extends State<ConnectionsList> {
  String filter = '연결됨', query = '';
  int audience = 0;

  Widget _retailerConnectionEmptyState(BuildContext context) => TdsResult(
    figure: const ExcludeSemantics(child: FigmaIcon('store', size: 60)),
    title: const Text('아직 함께하는 사입삼촌이 없어요'),
    button: TdsButton(
      size: TdsButtonSize.small,
      variant: TdsButtonVariant.weak,
      onPressed: () => openPage(context, const AddConnectionPage()),
      child: const Text('거래처 연결하기'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final search = query.trim().toLowerCase();
    final app = AppScope.of(context);
    final retailer = app.session.current!.role == AppRole.retailer;
    final audienceTabs = TdsTab(
      semanticLabel: '연결 대상',
      items: [
        TdsTabItem(text: '거래처', selected: audience == 0),
        TdsTabItem(text: '사입 동료', selected: audience == 1),
      ],
      onChanged: (index) => setState(() => audience = index),
    );
    if (!retailer && audience == 1) {
      return Column(children: [audienceTabs, const UncleTeamConnections()]);
    }
    final all = app.workspace.records('connections').toList();
    Account? peerOf(Record record) => app.workspace.profile(
      record.s(record.s('from') == app.session.current!.id ? 'to' : 'from'),
    );
    int priority(Record record) {
      if (record.s('status') == 'pending') {
        return record.s('to') == app.session.current!.id ? 0 : 3;
      }
      if (record.s('status') == 'accepted') {
        final peer = peerOf(record);
        return peer?.role == AppRole.uncle && !peer!.b('working') ? 2 : 1;
      }
      return 4;
    }

    final accepted = all.where((c) => c.s('status') == 'accepted').length;
    final pending = all.where((c) => c.s('status') == 'pending').length;
    final incoming = all
        .where(
          (c) =>
              c.s('status') == 'pending' &&
              c.s('to') == app.session.current!.id,
        )
        .length;
    final connections =
        all.where((c) {
          final peer = peerOf(c);
          final status =
              filter == '전체' ||
              (filter == '연결됨'
                  ? c.s('status') == 'accepted'
                  : c.s('status') == 'pending');
          return status && (peer?.name ?? '').toLowerCase().contains(search);
        }).toList()..sort((a, b) {
          final order = priority(a).compareTo(priority(b));
          return order != 0
              ? order
              : (peerOf(a)?.name ?? '').compareTo(peerOf(b)?.name ?? '');
        });
    final showRetailerAddConnectionCta =
        retailer && accepted == 0 && search.isEmpty && filter != '연결 대기';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!retailer) audienceTabs,
        const TdsSpacing(16),
        FigmaSurface(
          children: [
            TdsListRow(
              contents: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TdsText(
                    retailer ? '함께하는 사입삼촌' : '함께하는 거래처',
                    typography: TdsTypography.t6,
                    color: TdsTheme.of(context).color('grey600'),
                  ),
                  const TdsSpacing(8),
                  TdsText(
                    '$accepted${retailer ? '명' : '곳'}',
                    typography: TdsTypography.t1,
                    fontWeight: TdsFontWeight.bold,
                  ),
                ],
              ),
              right: TdsButton(
                size: TdsButtonSize.large,
                variant: TdsButtonVariant.weak,
                onPressed: () => openPage(context, const AddConnectionPage()),
                child: Text(retailer ? '새 연결' : '소매 거래처 추가'),
              ),
            ),
            if (incoming > 0) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: TdsBorder(),
              ),
              Item(
                '받은 연결 요청 $incoming건',
                leading: const FigmaIcon('bell', selected: true),
                onTap: () => setState(() => filter = '연결 대기'),
              ),
            ],
          ],
        ),
        const TdsSpacing(12),
        if (retailer)
          AppSearchField(
            placeholder: '사입삼촌 이름으로 검색',
            onChanged: (v) => setState(() => query = v),
          )
        else
          FigmaSurface(
            children: [
              Item(
                '거래처 검색',
                key: const ValueKey('uncle-partner-directory'),
                leading: const TdsAssetIcon(name: 'icn-searchfield', size: 24),
                onTap: () => openPage(context, const AddConnectionPage()),
              ),
            ],
          ),
        TdsTab(
          semanticLabel: '연결 상태',
          items: [
            TdsTabItem(text: '연결됨 $accepted', selected: filter == '연결됨'),
            TdsTabItem(
              text: '연결 대기 $pending',
              selected: filter == '연결 대기',
              redBean: incoming > 0,
            ),
            TdsTabItem(text: '전체', selected: filter == '전체'),
          ],
          onChanged: (i) => setState(() => filter = ['연결됨', '연결 대기', '전체'][i]),
        ),
        const TdsSpacing(12),
        if (connections.isEmpty && search.isNotEmpty)
          const EmptyState.titleOnly('검색 결과가 없어요')
        else if (connections.isEmpty)
          showRetailerAddConnectionCta
              ? _retailerConnectionEmptyState(context)
              : EmptyState.titleOnly(
                  filter == '연결 대기'
                      ? '기다리는 연결 요청이 없어요'
                      : retailer
                      ? '아직 함께하는 사입삼촌이 없어요'
                      : '연결된 거래처가 없어요',
                  icon: 'store',
                ),
        for (final c in connections) ConnectionCard(c),
      ],
    );
  }
}

class ConnectionCard extends StatelessWidget {
  const ConnectionCard(this.record, {super.key});
  final Record record;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.workspace
        .records('connections')
        .where((c) => c.id == this.record.id)
        .firstOrNull;
    if (current == null) return const Info('연결 기록을 찾을 수 없어요.');
    final record = current,
        own = record.s('from') == app.session.current!.id,
        peerId = record.s(own ? 'to' : 'from'),
        peer = app.workspace.profile(peerId);
    final theme = TdsTheme.of(context);
    final connected = record.s('status') == 'accepted';
    final retailer = app.session.current!.role == AppRole.retailer;
    final status = switch (record.s('status')) {
      'pending' => own ? '보낸 요청 · 수락 대기' : '받은 연결 요청',
      'accepted' =>
        peer?.role == AppRole.uncle
            ? (peer!.b('working') ? '업무 중' : '휴무 중')
            : '연결 완료',
      'withdrawn' => '연결 요청 철회',
      _ => '연결 요청 거절',
    };
    final actions = [
      TdsButton(
        display: TdsButtonDisplay.block,
        size: TdsButtonSize.large,
        color: TdsButtonColor.dark,
        variant: TdsButtonVariant.weak,
        onPressed: () => openPage(context, ChatPage(peerId)),
        child: const Text('채팅'),
      ),
      TdsButton(
        display: TdsButtonDisplay.block,
        size: TdsButtonSize.large,
        variant: TdsButtonVariant.weak,
        onPressed: () => openPage(
          context,
          retailer
              ? RequestEditor(peerId: peerId)
              : PageFrame(
                  title: '${peer?.name ?? '거래처'} 전달',
                  children: [DeliveryList(peerId: peerId)],
                ),
        ),
        child: Text(retailer ? '사입 요청' : '전달 목록'),
      ),
    ];
    return FigmaSurface(
      children: [
        TdsListRow(
          left: peer == null ? null : ProfileAvatar(peer, size: 64),
          contents: TdsListRowTexts(
            type: TdsListRowTextType.row2TypeA,
            top: Text(peer?.name ?? '거래처'),
            topProps: const TdsListRowTextStyle(
              typography: TdsTypography.t4,
              fontWeight: TdsFontWeight.bold,
            ),
            bottom: Text(
              connected && peer != null && peer.s('contact').isNotEmpty
                  ? '${peer.s('contact')} · 담당자'
                  : status,
            ),
          ),
          withArrow: true,
          onPressed: () => openPage(context, PartnerPage(peerId)),
        ),
        if (connected && peer != null) ...[
          Inset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TdsBadge(
                      size: TdsBadgeSize.small,
                      variant: TdsBadgeVariant.weak,
                      color: peer.role == AppRole.uncle && !peer.b('working')
                          ? TdsBadgeColor.elephant
                          : TdsBadgeColor.blue,
                      child: Text(status),
                    ),
                    if (peer.role == AppRole.uncle &&
                        peer.s('deadline').isNotEmpty)
                      TdsText(
                        '요청 마감 ${peer.s('deadline')}',
                        typography: TdsTypography.t7,
                        color: theme.color('grey600'),
                      ),
                  ],
                ),
                const TdsSpacing(12),
                if (peer.role == AppRole.uncle) ...[
                  TdsText(
                    '픽업  ${peer.s('pickupArea').isEmpty ? '등록 전' : peer.s('pickupArea')}',
                    typography: TdsTypography.t6,
                    color: theme.color('grey700'),
                  ),
                  const TdsSpacing(4),
                  TdsText(
                    '배송  ${peer.s('deliveryArea').isEmpty ? '등록 전' : peer.s('deliveryArea')}',
                    typography: TdsTypography.t6,
                    color: theme.color('grey700'),
                  ),
                ] else
                  TdsText(
                    [
                      peer.s('address'),
                      peer.s('addressDetail'),
                    ].where((part) => part.trim().isNotEmpty).join(' '),
                    typography: TdsTypography.t6,
                    color: theme.color('grey700'),
                  ),
              ],
            ),
          ),
          Inset(
            child: theme.platform.fontScale > 130
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [actions[0], const TdsSpacing(8), actions[1]],
                  )
                : Row(
                    children: [
                      Expanded(child: actions[0]),
                      const SizedBox(width: 8),
                      Expanded(child: actions[1]),
                    ],
                  ),
          ),
        ],
        if (record.s('status') == 'pending') ...[
          if (!own)
            ActionButton(
              '연결 수락',
              onPressed: () => app.workspace.respondConnection(
                record.id,
                'accepted',
                record.version,
                newId(),
              ),
            ),
          ActionButton(
            own ? '연결 요청 철회' : '연결 거절',
            weak: true,
            onPressed: () => app.workspace.respondConnection(
              record.id,
              own ? 'withdrawn' : 'rejected',
              record.version,
              newId(),
            ),
          ),
        ],
      ],
    );
  }
}

class PartnerPage extends StatelessWidget {
  const PartnerPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.workspace.profile(id);
    if (a == null) {
      return const PageFrame(
        title: '거래처',
        children: [Info('이 계정에서는 거래처를 확인할 수 없어요.')],
      );
    }
    final connected = app.workspace.partners.any((p) => p.id == id),
        retailer = app.session.current!.role == AppRole.retailer;
    final theme = TdsTheme.of(context);
    final history = app.workspace
        .records('requests')
        .where((r) => r.s(retailer ? 'uncleId' : 'retailerId') == id)
        .toList();
    return PageFrame(
      title: a.role == AppRole.uncle ? '사입삼촌 정보' : '거래처 정보',
      bottom: connected
          ? ActionButton(
              '1:1 채팅',
              bottom: true,
              onPressed: () => openPage(context, ChatPage(id)),
            )
          : null,
      children: [
        FigmaSurface(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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
            if (a.s('intro').trim().isNotEmpty) Info(a.s('intro')),
            if (connected)
              Item(
                retailer ? '새 사입 요청' : '이 거래처 전달 목록',
                leading: const FigmaIcon('bag', selected: true),
                onTap: () => openPage(
                  context,
                  retailer
                      ? RequestEditor(peerId: id)
                      : PageFrame(
                          title: '${a.name} 전달',
                          children: [DeliveryList(peerId: id)],
                        ),
                ),
              ),
          ],
        ),
        const Section('업무·배송 정보'),
        FigmaSurface(
          children: [
            if (a.role == AppRole.uncle) ...[
              Inset(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TdsBadge(
                    size: TdsBadgeSize.small,
                    variant: TdsBadgeVariant.weak,
                    color: a.b('working')
                        ? TdsBadgeColor.blue
                        : TdsBadgeColor.elephant,
                    child: Text(a.b('working') ? '업무 중' : '휴무 중'),
                  ),
                ),
              ),
              Item(
                '도매 픽업 지역',
                leading: const FigmaIcon('pin'),
                subtitle: a.s('pickupArea'),
              ),
              Item(
                '소매 배송 지역',
                leading: const FigmaIcon('truck'),
                subtitle: a.s('deliveryArea'),
              ),
              Item(
                '요청 마감시간',
                leading: const FigmaIcon('clock'),
                subtitle: a.s('deadline'),
              ),
              if (a.s('holiday').trim().isNotEmpty)
                Item('휴무 안내', subtitle: a.s('holiday')),
            ] else ...[
              Item(
                '기본 배송지',
                leading: const FigmaIcon('pin'),
                subtitle: '${a.s('address')} ${a.s('addressDetail')}',
              ),
              Item('배송 참고사항', subtitle: a.s('deliveryNote')),
            ],
          ],
        ),
        const Section('연락처'),
        FigmaSurface(
          children: [
            Item(
              '전화번호',
              leading: const FigmaIcon('phone'),
              subtitle: a.s('phone'),
            ),
          ],
        ),
        Section('요청 이력 ${history.length}건'),
        for (final r in history)
          RequestCard(
            RequestRecord(r.id, r.data),
            onTap: () => openPage(context, RequestDetailPage(r.id)),
          ),
      ],
    );
  }
}

class ChatList extends StatefulWidget {
  const ChatList({super.key});
  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  String query = '';
  int audience = 0;
  @override
  Widget build(BuildContext context) {
    final search = query.trim().toLowerCase();
    final app = AppScope.of(context),
        retailer = app.session.current!.role == AppRole.retailer,
        messages = app.workspace.records('messages'),
        partners = app.workspace.partners
            .where((p) => p.name.toLowerCase().contains(search))
            .toList();
    final audienceTabs = TdsTab(
      semanticLabel: '대화 대상',
      items: [
        TdsTabItem(text: '거래처', selected: audience == 0),
        TdsTabItem(text: '팀 동료', selected: audience == 1),
      ],
      onChanged: (index) => setState(() => audience = index),
    );
    if (!retailer && audience == 1) {
      return Column(children: [audienceTabs, const UncleTeamChats()]);
    }
    partners.sort((a, b) {
      String latest(String id) =>
          messages
              .where((m) => m.s('senderId') == id || m.s('recipientId') == id)
              .firstOrNull
              ?.s('createdAt') ??
          '';
      return latest(b.id).compareTo(latest(a.id));
    });
    return Column(
      children: [
        if (!retailer) audienceTabs,
        AppSearchField(
          placeholder: retailer ? '사입삼촌 검색' : '거래처 검색',
          onChanged: (v) => setState(() => query = v),
        ),
        if (partners.isEmpty && search.isNotEmpty)
          const EmptyState.titleOnly('검색 결과가 없어요')
        else if (partners.isEmpty)
          EmptyState.titleOnly(
            retailer ? '대화할 사입삼촌이 없어요' : '대화할 거래처가 없어요',
            icon: 'chat',
          ),
        for (final a in partners)
          Builder(
            builder: (context) {
              final rows = messages.where(
                (m) => m.s('senderId') == a.id || m.s('recipientId') == a.id,
              );
              final unread = rows
                  .where(
                    (m) =>
                        m.s('recipientId') == app.session.current!.id &&
                        !m.b('read'),
                  )
                  .length;
              return FigmaSurface(
                children: [
                  TdsListRow(
                    left: ProfileAvatar(a),
                    contents: TdsListRowTexts(
                      type: TdsListRowTextType.row2TypeA,
                      top: Text(a.name),
                      topProps: const TdsListRowTextStyle(maxLines: 1),
                      bottomProps: const TdsListRowTextStyle(
                        maxLines: 2,
                        typography: TdsTypography.t7,
                      ),
                      bottom: Text(
                        rows.isEmpty
                            ? '대화를 시작해 보세요'
                            : rows.first.b('deleted')
                            ? deletedMessageLabel
                            : rows.first.s('body').isEmpty
                            ? '사진'
                            : rows.first.s('body'),
                      ),
                    ),
                    right: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (rows.isNotEmpty)
                          TdsText(
                            displayTime(
                              rows.first.s('createdAt'),
                            ).split(' ').last,
                            typography: TdsTypography.t7,
                            color: TdsTheme.of(context).color('grey600'),
                          ),
                        if (unread > 0) ...[
                          const TdsSpacing(6),
                          StatusBadge('$unread'),
                        ],
                      ],
                    ),
                    onPressed: () => openPage(context, ChatPage(a.id)),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage(
    this.peerId, {
    this.requestId = '',
    this.mediaPicker,
    super.key,
  });
  final String peerId, requestId;
  final NativeMediaPicker? mediaPicker;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final body = TextEditingController();
  final conversationScroll = ScrollController();
  final mediaSheet = TdsBottomSheetController();
  List<String> photos = [];
  String messageId = newId();
  late String requestId = widget.requestId;
  bool sending = false, pickingMedia = false;
  bool changingBlock = false;
  String? sendError;

  Future<void> changeBlock() async {
    if (changingBlock || sending) return;
    final workspace = AppScope.read(context).workspace;
    final blocked = workspace.hasBlockedUser(widget.peerId);
    setState(() => changingBlock = true);
    try {
      final approved = await confirm(
        context,
        blocked ? '차단을 해제할까요?' : '이 사용자를 차단할까요?',
        blocked
            ? '상대방도 차단을 해제한 상태라면 다시 대화할 수 있어요.'
            : '서로 메시지와 사진을 보내거나 메시지를 수정할 수 없어요. 기존 대화와 거래 기록, 진행 중인 사입 업무는 유지돼요.',
      );
      if (!approved || !mounted) return;
      await workspace.setChatBlocked(widget.peerId, !blocked, newId());
      if (mounted) setState(() => sendError = null);
    } catch (error) {
      if (mounted) setState(() => sendError = error.toString());
    } finally {
      if (mounted) setState(() => changingBlock = false);
    }
  }

  NativeMediaPicker get mediaPicker =>
      widget.mediaPicker ?? defaultNativeMediaPicker;

  Future<void> send() async {
    if (sending) {
      return;
    }
    final sentBody = body.text, sentPhotos = List<String>.of(photos);
    setState(() {
      sending = true;
      sendError = null;
    });
    try {
      await AppScope.read(context).workspace.sendMessage(
        widget.peerId,
        messageId,
        sentBody,
        sentPhotos,
        requestId: requestId,
      );
      if (mounted) {
        setState(() {
          if (body.text == sentBody) body.clear();
          photos.removeWhere(sentPhotos.contains);
          messageId = newId();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && conversationScroll.hasClients) {
            conversationScroll.jumpTo(0);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => sendError = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> chooseRequest() async {
    final app = AppScope.read(context);
    final result = await openPage<String>(
      context,
      PageFrame(
        title: '대화에 연결할 요청',
        children: [
          Builder(
            builder: (context) =>
                Item('요청 연결 안 함', onTap: () => Navigator.pop(context, '')),
          ),
          for (final r
              in app.workspace
                  .records('requests')
                  .where(
                    (r) =>
                        r.s('retailerId') == widget.peerId ||
                        r.s('uncleId') == widget.peerId,
                  ))
            Builder(
              builder: (context) => Item(
                requestTitle(r.data),
                subtitle: isWholesalerOnlyRequest(r.data)
                    ? '도매처 ${requestWholesalers(r.data).length}곳'
                    : r.s('option'),
                onTap: () => Navigator.pop(context, r.id),
              ),
            ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => requestId = result);
  }

  final marked = <String>{};

  Future<NativeMediaSource?> choosePhotoSource() async {
    final result = Completer<NativeMediaSource?>();
    void complete([NativeMediaSource? source]) {
      if (!result.isCompleted) result.complete(source);
    }

    mediaSheet.open(
      TdsBottomSheetOptions(
        header: '사진 추가',
        headerDescription: const TdsBottomSheetHeaderDescription(
          '촬영하거나 갤러리에서 사진을 선택해 주세요.',
        ),
        onClose: complete,
        onExited: complete,
        child: TdsBottomSheetSelect(
          animation: false,
          onChange: (value) {
            complete(
              value == 'camera'
                  ? NativeMediaSource.camera
                  : NativeMediaSource.gallery,
            );
            mediaSheet.close();
          },
          options: const [
            TdsBottomSheetSelectOption(name: '사진 촬영', value: 'camera'),
            TdsBottomSheetSelectOption(name: '갤러리에서 선택', value: 'gallery'),
          ],
        ),
      ),
    );
    return result.future;
  }

  Future<void> attachPhoto() async {
    if (sending || pickingMedia) return;
    final source = await choosePhotoSource();
    if (source == null || !mounted) return;
    setState(() {
      pickingMedia = true;
      sendError = null;
    });
    try {
      final selection = await mediaPicker.pickImage(source: source);
      if (selection == null || !mounted) return;
      final id = await AppScope.read(
        context,
      ).attachments.save(selection.name, selection.bytes, selection.mime);
      if (mounted) {
        setState(() => photos.add(id));
      }
    } catch (error) {
      if (mounted) setState(() => sendError = error.toString());
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  @override
  void dispose() {
    body.dispose();
    conversationScroll.dispose();
    mediaSheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        me = app.session.current!,
        peer = app.workspace.profile(widget.peerId);
    final blocked = app.workspace.isChatBlocked(widget.peerId);
    final blockedByMe = app.workspace.hasBlockedUser(widget.peerId);
    final rows = app.workspace
        .records('messages')
        .where(
          (m) =>
              m.s('senderId') == widget.peerId ||
              m.s('recipientId') == widget.peerId,
        )
        .toList()
        .reversed
        .toList();
    final unread = rows
        .where(
          (m) =>
              m.s('recipientId') == me.id &&
              !m.b('read') &&
              !marked.contains(m.id),
        )
        .toList();
    if (unread.isNotEmpty &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      marked.addAll(unread.map((m) => m.id));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await app.workspace.markChatRead(widget.peerId);
        } catch (_) {
          marked.removeAll(unread.map((m) => m.id));
        }
      });
    }
    return TdsBottomSheetProvider(
      controller: mediaSheet,
      child: PageFrame(
        title: peer?.name ?? '채팅',
        navigationLeading: peer == null
            ? null
            : ExcludeSemantics(child: ProfileAvatar(peer, size: 36)),
        navigationSubtitle: peer == null
            ? '1:1 대화'
            : '${peer.role?.label ?? '거래처'} · 1:1 대화',
        scrollKey: 'chat-${widget.peerId}',
        reverse: true,
        scrollController: conversationScroll,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TdsTextButton(
              size: TdsTextButtonSize.small,
              semanticLabel: blockedByMe ? '사용자 차단 해제' : '사용자 차단',
              disabled: changingBlock || sending,
              onPressed: changeBlock,
              child: Text(blockedByMe ? '차단 해제' : '차단'),
            ),
            if (me.role == AppRole.retailer)
              TdsIconButton(
                semanticLabel: '새 사입 요청',
                onPressed: () =>
                    openPage(context, RequestEditor(peerId: widget.peerId)),
                child: const FigmaIcon('plus'),
              ),
          ],
        ),
        header: requestId.isNotEmpty && MediaQuery.sizeOf(context).height > 600
            ? FigmaSurface(
                children: [
                  TdsListRow(
                    left: const FigmaIcon('bag'),
                    contents: TdsListRowTexts(
                      type: TdsListRowTextType.row2TypeD,
                      top: const Text('연결된 요청 보기'),
                      bottom: Text(
                        requestTitle(
                          app.workspace.request(requestId)?.data ?? const {},
                        ),
                      ),
                      bottomProps: const TdsListRowTextStyle(
                        maxLines: 1,
                        typography: TdsTypography.t6,
                      ),
                    ),
                    withArrow: true,
                    onPressed: () =>
                        openPage(context, RequestDetailPage(requestId)),
                  ),
                ],
              )
            : null,
        bottom: FigmaSurface(
          margin: 12,
          children: [
            if (sendError != null) Info(sendError!, error: true),
            if (blocked)
              Info(
                blockedByMe
                    ? '차단한 사용자예요. 차단을 해제하면 다시 대화할 수 있어요.'
                    : '지금은 이 사용자와 대화할 수 없어요.',
              )
            else ...[
              TdsTextField(
                controller: body,
                placeholder: '메시지를 입력하세요',
                semanticLabel: '메시지',
                variant: TdsTextFieldVariant.box,
                paddingTop: 0,
                paddingBottom: 8,
                onSubmitted: (_) => send(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    TdsIconButton(
                      semanticLabel: photos.isEmpty
                          ? '사진 첨부'
                          : '사진 추가, ${photos.length}장 첨부됨',
                      disabled: sending || pickingMedia,
                      onPressed: sending || pickingMedia ? null : attachPhoto,
                      child: FigmaIcon('camera', selected: photos.isNotEmpty),
                    ),
                    if (photos.isNotEmpty) StatusBadge('${photos.length}'),
                    const SizedBox(width: 8),
                    TdsIconButton(
                      semanticLabel: requestId.isEmpty ? '요청 연결' : '연결된 요청 변경',
                      disabled: sending,
                      variant: requestId.isEmpty
                          ? TdsIconButtonVariant.clear
                          : TdsIconButtonVariant.fill,
                      backgroundColor: TdsTheme.of(context).color('blue50'),
                      onPressed: sending ? null : chooseRequest,
                      child: FigmaIcon('link', selected: requestId.isNotEmpty),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    TdsButton(
                      size: TdsButtonSize.large,
                      semanticLabel: '메시지 전송',
                      loading: sending,
                      disabled: sending,
                      onPressed: send,
                      child: FigmaIcon(
                        'send',
                        color: TdsButtonColors.resolve(
                          TdsTheme.of(context),
                          TdsButtonColor.primary,
                          TdsButtonVariant.fill,
                        ).foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        children: [
          if (rows.isEmpty)
            const EmptyState.titleOnly('아직 메시지가 없어요', icon: 'chat'),
          for (final (index, m) in rows.indexed) ...[
            if (index == 0 ||
                displayTime(
                      rows[index - 1].s('createdAt'),
                    ).split(' ').take(2).join(' ') !=
                    displayTime(m.s('createdAt')).split(' ').take(2).join(' '))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TdsText(
                    displayTime(m.s('createdAt')).split(' ').take(2).join(' '),
                    typography: TdsTypography.t7,
                    color: TdsTheme.of(context).color('grey600'),
                  ),
                ),
              ),
            if (m.b('system'))
              FigmaSurface(
                margin: 32,
                children: [
                  TdsListRow(
                    verticalPadding: TdsListRowVerticalPadding.small,
                    contents: TdsListRowTexts(
                      type: TdsListRowTextType.row2TypeD,
                      top: Text(
                        '업무 기록 · ${displayTime(m.s('createdAt')).split(' ').last}',
                      ),
                      bottom: Text(m.s('body')),
                      topProps: const TdsListRowTextStyle(
                        typography: TdsTypography.t7,
                      ),
                      bottomProps: const TdsListRowTextStyle(
                        typography: TdsTypography.t6,
                        fontWeight: TdsFontWeight.medium,
                      ),
                    ),
                    withArrow:
                        m.s('invoiceId').isNotEmpty ||
                        m.s('requestId').isNotEmpty,
                    onPressed: m.s('invoiceId').isNotEmpty
                        ? () => openPage(
                            context,
                            InvoiceDetailPage(invoiceId: m.s('invoiceId')),
                          )
                        : m.s('requestId').isEmpty
                        ? null
                        : () => openPage(
                            context,
                            RequestDetailPage(m.s('requestId')),
                          ),
                  ),
                ],
              )
            else
              Inset(
                child: Align(
                  alignment: m.s('senderId') == me.id
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: m.s('senderId') == me.id
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      ChatMessageActions(
                        key: ValueKey(m.id),
                        message: m,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: m.s('senderId') == me.id
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            TdsBubble(
                              withTail: false,
                              background: m.s('senderId') == me.id
                                  ? TdsBubbleBackground.blue
                                  : TdsBubbleBackground.grey,
                              child: TdsText(
                                m.b('deleted')
                                    ? deletedMessageLabel
                                    : m.s('body').isEmpty
                                    ? '사진'
                                    : m.s('body'),
                                typography: TdsTypography.t5,
                                color: TdsTheme.of(context).color(
                                  m.s('senderId') == me.id
                                      ? 'white'
                                      : 'grey900',
                                ),
                              ),
                            ),
                            if (!m.b('deleted'))
                              for (final id in m.list('attachments'))
                                AttachmentPreview(id, compact: true),
                          ],
                        ),
                      ),
                      if (!m.b('deleted') &&
                          m.s('requestId').isNotEmpty &&
                          (index == 0 ||
                              rows[index - 1].s('requestId') !=
                                  m.s('requestId')))
                        TdsTextButton(
                          size: TdsTextButtonSize.small,
                          onPressed: () => openPage(
                            context,
                            RequestDetailPage(m.s('requestId')),
                          ),
                          child: const Text('관련 요청 열기'),
                        ),
                      const TdsSpacing(4),
                      TdsText(
                        '${displayTime(m.s('createdAt')).split(' ').last}${m.s('status') == 'failed'
                            ? ' · 전송 실패'
                            : m.s('senderId') == me.id
                            ? ' · ${m.b('read') ? '읽음' : '안 읽음'}'
                            : ''}${!m.b('deleted') && m.s('editedAt').isNotEmpty ? ' · 수정됨' : ''}',
                        typography: TdsTypography.t7,
                        color: TdsTheme.of(context).color('grey600'),
                      ),
                      if (!m.b('deleted') &&
                          m.s('status') == 'failed' &&
                          m.s('senderId') == me.id)
                        ActionButton(
                          '메시지 다시 보내기',
                          weak: true,
                          enabled: !blocked,
                          onPressed: () async {
                            await app.workspace.sendMessage(
                              widget.peerId,
                              m.id,
                              m.s('body'),
                              m.list('attachments'),
                              requestId: m.s('requestId'),
                            );
                            if (mounted && messageId == m.id) {
                              setState(() {
                                body.clear();
                                photos = [];
                                messageId = newId();
                              });
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (requestId.isNotEmpty &&
              me.role == AppRole.retailer &&
              app.workspace.request(requestId)?.needsReply == true) ...[
            const FigmaSurface(
              tinted: true,
              children: [
                Item(
                  '업무 답변을 확정해 주세요',
                  subtitle: '채팅 내용과 별도로 미송 처리 방법을 확정하면 기록에 남아요.',
                ),
              ],
            ),
            ActionButton(
              '미송 답변하기',
              onPressed: () => openPage(context, BackorderReplyPage(requestId)),
            ),
          ],
          for (final id in photos) AttachmentPreview(id, compact: true),
          if (photos.isNotEmpty)
            Inset(
              child: TdsTextButton(
                size: TdsTextButtonSize.small,
                onPressed: sending ? null : () => setState(() => photos = []),
                child: const Text('첨부 삭제'),
              ),
            ),
        ],
      ),
    );
  }
}

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  bool unreadOnly = false;

  String _dateLabel(String value, DateTime today) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '이전 알림';
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return '오늘';
    if (day == DateTime(today.year, today.month, today.day - 1)) return '어제';
    return '${date.year == today.year ? '' : '${date.year}년 '}${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        notices = app.workspace.records('notices');
    final theme = TdsTheme.of(context);
    final unreadCount = notices.where((n) => !n.b('read')).length;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<Record>>{};
    for (final notice in notices) {
      if (unreadOnly && notice.b('read')) continue;
      final date = _dateLabel(notice.s('createdAt'), today);
      (groups[date] ??= []).add(notice);
    }
    return PageFrame(
      title: '알림',
      scrollKey: unreadOnly ? 'notices-unread' : 'notices-all',
      header: TdsTab(
        semanticLabel: '알림 필터',
        items: [
          TdsTabItem(text: '전체', selected: !unreadOnly),
          TdsTabItem(text: '안 읽음 $unreadCount', selected: unreadOnly),
        ],
        onChanged: (index) => setState(() => unreadOnly = index == 1),
      ),
      children: [
        if (groups.isEmpty)
          EmptyState(
            unreadOnly && notices.isNotEmpty
                ? '모든 알림을 확인했어요'
                : '아직 도착한 알림이 없어요',
            unreadOnly && notices.isNotEmpty
                ? '지난 소식은 전체에서 다시 볼 수 있어요.'
                : '새 메시지와 사입 진행 소식을 여기서 알려드릴게요.',
            icon: 'bell',
            action: unreadOnly && notices.isNotEmpty ? '전체 알림 보기' : null,
            onAction: () => setState(() => unreadOnly = false),
          ),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Semantics(
              header: true,
              child: TdsText(
                group.key,
                typography: TdsTypography.t6,
                fontWeight: TdsFontWeight.semibold,
                color: theme.color('grey700'),
              ),
            ),
          ),
          TdsList(
            semanticLabel: '${group.key} 알림',
            children: [
              for (var i = 0; i < group.value.length; i++)
                _noticeRow(context, group.value[i], border: i > 0),
            ],
          ),
        ],
      ],
    );
  }

  Widget _noticeRow(
    BuildContext context,
    Record notice, {
    required bool border,
  }) {
    final theme = TdsTheme.of(context);
    final unread = !notice.b('read');
    final (category, icon) = switch (notice.s('kind')) {
      'chat' => ('채팅', 'chat'),
      'connection' => ('거래처', 'store'),
      'delivery' => ('상품 전달', 'truck'),
      'request' => ('사입', 'bag'),
      _ => ('안내', 'bell'),
    };
    final date = DateTime.tryParse(notice.s('createdAt'))?.toLocal();
    final time = date == null
        ? '시간 정보 없음'
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return TdsListRow(
      key: ValueKey('notice-${notice.id}'),
      semanticLabel: unread ? '안 읽은 알림' : '읽은 알림',
      verticalPadding: TdsListRowVerticalPadding.large,
      leftAlignment: TdsListRowAlignment.top,
      border: border ? TdsListRowBorder.indented : TdsListRowBorder.none,
      left: ExcludeSemantics(
        child: TdsAssetFrame(
          shape: const TdsAssetFrameShape(
            width: 40,
            height: 40,
            radius: 20,
            transparent: false,
          ),
          backgroundColor: theme.color(
            unread ? 'tBlueBadgeBackground' : 'greyOpacity100',
          ),
          content: FigmaIcon(icon, selected: unread, size: 22),
        ),
      ),
      contents: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TdsText(
            unread ? '$category · 안 읽음' : category,
            typography: TdsTypography.t7,
            fontWeight: TdsFontWeight.medium,
            color: theme.color(unread ? 'blue600' : 'grey600'),
          ),
          const TdsSpacing(4),
          TdsText(
            notice.s('title'),
            typography: TdsTypography.t5,
            fontWeight: unread ? TdsFontWeight.semibold : TdsFontWeight.regular,
          ),
          const TdsSpacing(6),
          TdsText(
            time,
            typography: TdsTypography.t7,
            color: theme.color('grey600'),
          ),
        ],
      ),
      onPressed: () async {
        final app = AppScope.read(context);
        try {
          await app.session.setDestination({
            ...notice.data,
            'noticeId': notice.id,
          });
          if (context.mounted) await openDestination(context);
        } catch (error) {
          if (context.mounted) {
            await confirm(context, '알림을 열지 못했어요', error.toString());
          }
        }
      },
    );
  }
}

Future<void> openDestination(BuildContext context) async {
  final app = AppScope.read(context),
      target = app.session.pendingDestination,
      me = app.session.current;
  if (target == null || me == null) return;
  if (target.s('ownerId') != me.id) {
    await confirm(context, '다른 계정의 알림이에요', '알림을 받은 계정으로 로그인하면 이어서 확인할 수 있어요.');
    return;
  }
  Widget page;
  switch (target.s('kind')) {
    case 'invoice':
      page = InvoiceDetailPage(invoiceId: target.s('targetId'));
    case 'chat':
      page = ChatPage(target.s('targetId'));
    case 'connection':
      final c = app.workspace
          .records('connections')
          .where((c) => c.id == target.s('targetId'))
          .firstOrNull;
      page = PageFrame(
        title: '거래처 연결',
        children: [
          if (c != null) ConnectionCard(c) else const Info('연결 기록을 찾을 수 없어요.'),
        ],
      );
    case 'delivery':
      final d = app.workspace
          .records('deliveries')
          .where((d) => d.id == target.s('targetId'))
          .firstOrNull;
      page = PageFrame(
        title: '전달 내역',
        children: [
          if (d != null) DeliveryCard(d) else const Info('전달 기록을 찾을 수 없어요.'),
        ],
      );
    default:
      page = RequestDetailPage(
        target.s('requestId').isEmpty
            ? target.s('targetId')
            : target.s('requestId'),
      );
  }
  if (target.s('noticeId').isNotEmpty) {
    await app.workspace.readNotice(target.s('noticeId'));
  }
  await app.session.setDestination(null);
  if (context.mounted) await openPage(context, page);
}
