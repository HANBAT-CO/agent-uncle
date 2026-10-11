import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'requests.dart';
import 'delivery.dart';
import 'profile_avatar.dart';

class ConnectionsList extends StatefulWidget {
  const ConnectionsList({super.key});
  @override
  State<ConnectionsList> createState() => _ConnectionsListState();
}

class _ConnectionsListState extends State<ConnectionsList> {
  String filter = '연결됨', query = '';
  @override
  Widget build(BuildContext context) {
    final search = query.trim().toLowerCase();
    final app = AppScope.of(context);
    final retailer = app.session.current!.role == AppRole.retailer;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                child: const Text('새 연결'),
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
        AppSearchField(
          placeholder: retailer ? '사입삼촌 이름으로 검색' : '거래처 검색',
          onChanged: (v) => setState(() => query = v),
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
          const EmptyState('검색 결과가 없어요', '거래처 이름을 다시 확인해 주세요.')
        else if (connections.isEmpty)
          EmptyState(
            filter == '연결 대기'
                ? '기다리는 연결 요청이 없어요'
                : retailer
                ? '아직 함께하는 사입삼촌이 없어요'
                : '연결된 거래처가 없어요',
            filter == '연결 대기'
                ? '보내거나 받은 요청이 생기면 여기서 확인할 수 있어요.'
                : '새 연결에서 초대 코드를 주고받아 보세요.',
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
          Info(
            own
                ? '상대방이 수락하면 사입 요청과 대화를 시작할 수 있어요.'
                : '연결을 수락하면 사입 요청과 대화를 주고받을 수 있어요.',
          ),
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

class AddConnectionPage extends StatefulWidget {
  const AddConnectionPage({super.key});
  @override
  State<AddConnectionPage> createState() => _AddConnectionPageState();
}

class _AddConnectionPageState extends State<AddConnectionPage> {
  final code = TextEditingController();
  Account? found;
  String op = newId();
  bool copied = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), me = app.session.current!;
    return PageFrame(
      title: '상대방 연결',
      bottom: found == null
          ? ActionButton(
              '상대방 확인',
              bottom: true,
              onPressed: () async {
                final result = await app.workspace.lookupCode(code.text);
                if (mounted) {
                  setState(() {
                    found = result;
                    op = newId();
                  });
                }
              },
            )
          : ActionButton(
              '연결 요청 보내기',
              bottom: true,
              onPressed: () async {
                await app.workspace.lookupCode(code.text);
                await app.workspace.connect(found!.id, op);
                if (context.mounted) Navigator.pop(context);
              },
            ),
      children: [
        const PageHeading(
          '함께 일할 거래처를 연결해요',
          description: '초대 코드를 주고받으면 요청과 대화를 시작할 수 있어요.',
        ),
        const Section('내 초대 코드'),
        FigmaSurface(
          children: [
            Item(
              me.s('code'),
              leading: const FigmaIcon('store'),
              subtitle: '유효기간 ${displayTime(me.s('codeExpires'))}',
            ),
            ActionButton(
              copied ? '코드를 복사했어요' : '초대 코드 복사',
              icon: copied ? 'check' : 'copy',
              weak: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: me.s('code')));
                setState(() => copied = true);
              },
            ),
            ActionButton(
              '코드 새로 발급',
              icon: 'refresh',
              weak: true,
              onPressed: () async {
                await app.workspace.renewCode();
                if (mounted) setState(() => copied = false);
              },
            ),
          ],
        ),
        const Section('상대방 코드 입력'),
        FigmaSurface(
          children: [
            Field(
              '초대 코드',
              controller: code,
              onChanged: (_) => setState(() => found = null),
            ),
          ],
        ),
        if (found != null)
          FigmaSurface(
            children: [
              Item(
                found!.name,
                leading: ProfileAvatar(found!),
                subtitle:
                    '${found!.role!.label} · ${found!.s('pickupArea')} ${found!.s('deliveryArea')}',
              ),
            ],
          ),
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
                '도매 픽업 구역',
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
        if (history.isEmpty) const Info('함께 진행한 사입 요청이 여기에 쌓여요.'),
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
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        messages = app.workspace.records('messages'),
        partners = app.workspace.partners
            .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
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
        Inset(
          child: TdsSearchField(
            placeholder: '거래처 검색',
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        if (partners.isEmpty)
          const EmptyState('대화할 거래처가 없어요', '거래처 연결을 수락하면 1:1 채팅을 시작할 수 있어요.'),
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
              return Item(
                a.name,
                subtitle: rows.isEmpty
                    ? '대화를 시작해 보세요'
                    : rows.first.s('body').isEmpty
                    ? '사진'
                    : rows.first.s('body'),
                trailing: unread == 0 ? null : StatusBadge('$unread'),
                onTap: () => openPage(context, ChatPage(a.id)),
              );
            },
          ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage(this.peerId, {this.requestId = '', super.key});
  final String peerId, requestId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final body = TextEditingController();
  List<String> photos = [];
  String messageId = newId();
  late String requestId = widget.requestId;
  bool sending = false;
  String? sendError;

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
                r.s('product'),
                subtitle: r.s('option'),
                onTap: () => Navigator.pop(context, r.id),
              ),
            ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => requestId = result);
  }

  final marked = <String>{};
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        me = app.session.current!,
        peer = app.workspace.profile(widget.peerId);
    final rows = app.workspace
        .records('messages')
        .where(
          (m) =>
              m.s('senderId') == widget.peerId ||
              m.s('recipientId') == widget.peerId,
        )
        .toList()
        .reversed;
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
    return PageFrame(
      title: peer?.name ?? '채팅',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sendError != null) Info(sendError!, error: true),
          TdsListRow(
            contents: TdsListRowTexts(
              type: TdsListRowTextType.row1TypeA,
              top: Text(
                requestId.isEmpty
                    ? '요청 연결하기'
                    : '현재 요청 · ${app.workspace.request(requestId)?.s('product') ?? ''}',
              ),
            ),
            withArrow: true,
            onPressed: sending ? null : chooseRequest,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TdsTextButton(
                  size: TdsTextButtonSize.small,
                  onPressed: sending
                      ? null
                      : () async {
                          try {
                            final id = await app.attachments.pick(
                              document: false,
                            );
                            if (id != null && mounted) {
                              setState(() => photos.add(id));
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => sendError = e.toString());
                            }
                          }
                        },
                  child: Text(photos.isEmpty ? '사진' : '사진 ${photos.length}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TdsTextField(
                    controller: body,
                    placeholder: '메시지를 입력하세요',
                    semanticLabel: '메시지',
                    variant: TdsTextFieldVariant.box,
                  ),
                ),
                const SizedBox(width: 8),
                TdsButton(
                  size: TdsButtonSize.small,
                  loading: sending,
                  disabled: sending,
                  onPressed: send,
                  child: const Text('전송'),
                ),
              ],
            ),
          ),
        ],
      ),
      children: [
        if (me.role == AppRole.retailer)
          ActionButton(
            '이 거래처에 새 요청',
            weak: true,
            onPressed: () =>
                openPage(context, RequestEditor(peerId: widget.peerId)),
          ),
        if (requestId.isNotEmpty)
          Item(
            '연결된 요청 보기',
            subtitle: app.workspace.request(requestId)?.s('product'),
            onTap: () => openPage(context, RequestDetailPage(requestId)),
          ),
        if (rows.isEmpty)
          const EmptyState('아직 메시지가 없어요', '요청에 관한 이야기를 나눠 보세요.'),
        for (final m in rows)
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
                  TdsBubble(
                    withTail: false,
                    background: m.s('senderId') == me.id
                        ? TdsBubbleBackground.blue
                        : TdsBubbleBackground.grey,
                    child: Text(m.s('body').isEmpty ? '사진' : m.s('body')),
                  ),
                  for (final id in m.list('attachments'))
                    AttachmentPreview(id, compact: true),
                  if (m.s('requestId').isNotEmpty)
                    TdsTextButton(
                      size: TdsTextButtonSize.small,
                      onPressed: () => openPage(
                        context,
                        RequestDetailPage(m.s('requestId')),
                      ),
                      child: const Text('관련 요청 열기'),
                    ),
                  TdsText(
                    '${displayTime(m.s('createdAt'))}${m.s('status') == 'failed'
                        ? ' · 전송 실패'
                        : m.s('senderId') == me.id
                        ? ' · ${m.b('read') ? '읽음' : '안 읽음'}'
                        : ''}',
                    typography: TdsTypography.t7,
                    color: TdsTheme.of(context).color('grey600'),
                  ),
                  if (m.s('status') == 'failed' && m.s('senderId') == me.id)
                    ActionButton(
                      '메시지 다시 보내기',
                      weak: true,
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
    );
  }
}

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        notices = app.workspace.records('notices');
    return PageFrame(
      title: '알림',
      children: [
        const PageHeading('새로 확인할 소식'),
        if (notices.isEmpty)
          const EmptyState('새로운 알림이 없어요', '거래처와 요청의 처리 결과가 여기에 모여요.'),
        for (final n in notices)
          FigmaSurface(
            tinted: !n.b('read'),
            children: [
              Item(
                n.s('title'),
                subtitle: displayTime(n.s('createdAt')),
                trailing: n.b('read') ? null : const StatusBadge('새 알림'),
                onTap: () async {
                  try {
                    await app.session.setDestination({
                      ...n.data,
                      'noticeId': n.id,
                    });
                    if (context.mounted) await openDestination(context);
                  } catch (error) {
                    if (context.mounted) {
                      await confirm(context, '알림을 열지 못했어요', error.toString());
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
