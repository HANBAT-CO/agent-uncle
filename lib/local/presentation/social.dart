import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'requests.dart';
import 'delivery.dart';

class ConnectionsList extends StatelessWidget {
  const ConnectionsList({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        connections = app.workspace.records('connections');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionButton(
          '상대방 연결하기',
          onPressed: () => openPage(context, const AddConnectionPage()),
        ),
        if (connections.isEmpty)
          const EmptyState('연결된 거래처가 없어요', '초대 코드를 주고받아 상대방과 연결해 주세요.'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(
          peer?.name ?? '거래처',
          subtitle: switch (record.s('status')) {
            'pending' => own ? '보낸 요청 · 수락 대기' : '받은 연결 요청',
            'accepted' => '연결 완료',
            'withdrawn' => '연결 요청 철회',
            _ => '연결 요청 거절',
          },
          onTap: () => openPage(context, PartnerPage(peerId)),
        ),
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
      children: [
        const Section('내 초대 코드'),
        Item(
          me.s('code'),
          subtitle: '유효기간 ${displayTime(me.s('codeExpires'))}',
        ),
        ActionButton(
          copied ? '코드를 복사했어요' : '초대 코드 복사',
          weak: true,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: me.s('code')));
            setState(() => copied = true);
          },
        ),
        ActionButton(
          '코드 새로 발급',
          weak: true,
          onPressed: () async {
            await app.workspace.renewCode();
            if (mounted) setState(() => copied = false);
          },
        ),
        const Section('상대방 코드 입력'),
        Field(
          '초대 코드',
          controller: code,
          onChanged: (_) => setState(() => found = null),
        ),
        ActionButton(
          '상대방 확인',
          onPressed: () async {
            final result = await app.workspace.lookupCode(code.text);
            if (mounted) {
              setState(() {
                found = result;
                op = newId();
              });
            }
          },
        ),
        if (found != null) ...[
          const Section('연결할 상대방'),
          Item(
            found!.name,
            subtitle:
                '${found!.role!.label}\n${found!.s('pickupArea')} ${found!.s('deliveryArea')}',
          ),
          ActionButton(
            '연결 요청 보내기',
            onPressed: () async {
              await app.workspace.lookupCode(code.text);
              await app.workspace.connect(found!.id, op);
              if (context.mounted) Navigator.pop(context);
            },
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
    return PageFrame(
      title: a.name,
      subtitle: a.role!.label,
      children: [
        if (a.s('photoId').isNotEmpty && connected)
          AttachmentPreview(a.s('photoId'), compact: true),
        Item('담당자', subtitle: a.s('contact')),
        Item('연락처', subtitle: a.s('phone')),
        if (a.role == AppRole.uncle) ...[
          Item('도매 픽업 구역', subtitle: a.s('pickupArea')),
          Item('소매 배송 지역', subtitle: a.s('deliveryArea')),
          Item('요청 마감시간', subtitle: a.s('deadline')),
          Item('활동 상태', subtitle: a.b('working') ? '업무 중' : '휴무'),
          Item('소개·휴무 안내', subtitle: '${a.s('intro')}\n${a.s('holiday')}'),
        ] else ...[
          Item('기본 배송지', subtitle: '${a.s('address')} ${a.s('addressDetail')}'),
          Item('배송 참고사항', subtitle: a.s('deliveryNote')),
        ],
        if (connected) ...[
          ActionButton(
            '1:1 채팅',
            onPressed: () => openPage(context, ChatPage(id)),
          ),
          if (retailer)
            ActionButton(
              '새 요청',
              weak: true,
              onPressed: () => openPage(context, RequestEditor(peerId: id)),
            )
          else
            ActionButton(
              '이 거래처 전달 목록',
              weak: true,
              onPressed: () => openPage(
                context,
                PageFrame(
                  title: '${a.name} 전달',
                  children: [DeliveryList(peerId: id)],
                ),
              ),
            ),
        ],
        const Section('요청 이력'),
        for (final r
            in app.workspace
                .records('requests')
                .where((r) => r.s(retailer ? 'uncleId' : 'retailerId') == id))
          RequestCard(
            RequestRecord(r.id, r.data),
            onTap: () => openPage(context, RequestDetailPage(r.id)),
          ),
      ],
    );
  }
}

class ChatList extends StatelessWidget {
  const ChatList({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        messages = app.workspace.records('messages'),
        partners = app.workspace.partners.toList();
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
      children: [
        if (me.role == AppRole.retailer)
          ActionButton(
            '이 거래처에 새 요청',
            weak: true,
            onPressed: () =>
                openPage(context, RequestEditor(peerId: widget.peerId)),
          ),
        if (widget.requestId.isNotEmpty)
          Item(
            '연결된 요청 보기',
            subtitle: app.workspace.request(widget.requestId)?.s('product'),
            onTap: () => openPage(context, RequestDetailPage(widget.requestId)),
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
        const Section('메시지 보내기'),
        Field('메시지', controller: body, multiline: true),
        AttachmentField(
          label: '사진',
          multiple: true,
          ids: photos,
          onChanged: (ids) => setState(() => photos = ids),
        ),
        ActionButton(
          '메시지 전송',
          onPressed: () async {
            await app.workspace.sendMessage(
              widget.peerId,
              messageId,
              body.text,
              photos,
              requestId: widget.requestId,
            );
            if (mounted) {
              setState(() {
                body.clear();
                photos = [];
                messageId = newId();
              });
            }
          },
        ),
        const Info(
          '읽음이나 메시지 전송으로 요청을 수락하거나 수량을 변경하지 않아요. 전송에 실패하면 입력을 유지하며 다시 보낼 수 있어요.',
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
        if (notices.isEmpty)
          const EmptyState('새로운 알림이 없어요', '거래처와 요청의 처리 결과가 여기에 모여요.'),
        for (final n in notices)
          Item(
            n.s('title'),
            subtitle: displayTime(n.s('createdAt')),
            trailing: n.b('read') ? null : const StatusBadge('새 알림'),
            onTap: () async {
              try {
                await app.session.setDestination({...n.data, 'noticeId': n.id});
                if (context.mounted) await openDestination(context);
              } catch (error) {
                if (context.mounted) {
                  await confirm(context, '알림을 열지 못했어요', error.toString());
                }
              }
            },
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
