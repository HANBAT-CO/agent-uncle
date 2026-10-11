import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'social.dart';
import 'delivery.dart';

class RequestEditor extends StatefulWidget {
  const RequestEditor({this.draftId, this.requestId, this.peerId, super.key});
  final String? draftId, requestId, peerId;
  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  final fields = <String, TextEditingController>{};
  late String id;
  String peer = '', operation = newId();
  List<String> photos = [];
  FormSaver? saver;
  TabSaveGuard? tabGuard;
  int version = 0;
  bool ready = false, leaving = false;
  bool get editing => widget.requestId != null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    final app = AppScope.read(context), a = app.session.current!;
    id = widget.requestId ?? widget.draftId ?? newId();
    final data = editing
        ? app.workspace.request(id)?.data
        : app.workspace
              .records('drafts')
              .where((r) => r.id == id)
              .firstOrNull
              ?.data;
    peer = textOf(data ?? {}, 'uncleId', widget.peerId ?? '');
    photos = stringsOf(data ?? {}, 'photos');
    version = numberOf(data ?? {}, 'version');
    for (final e in {
      'wholesaler': '',
      'location': '',
      'product': '',
      'option': '',
      'quantity': '1',
      'address': a.s('address'),
      'addressDetail': a.s('addressDetail'),
      'note': a.s('deliveryNote'),
    }.entries) {
      fields[e.key] = TextEditingController(
        text: data?.containsKey(e.key) == true ? '${data![e.key]}' : e.value,
      );
    }
    saver = FormSaver((values) => app.workspace.saveDraft(id, values));
    saver!.addListener(refresh);
    if (!editing) {
      tabGuard = TabSaveScope.of(context);
      tabGuard?.save = flush;
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Data values() => {
    for (final e in fields.entries)
      if (e.key != 'quantity') e.key: e.value.text.trim(),
    'quantity': int.tryParse(fields['quantity']!.text) ?? 0,
    'uncleId': peer,
    'photos': photos,
  };
  void changed() {
    if (!editing) saver!.change(values());
    setState(() {});
  }

  Future<void> leave() async {
    if (!editing) {
      try {
        await flush();
      } catch (_) {
        return;
      }
    }
    if (mounted) {
      setState(() => leaving = true);
      Navigator.pop(context);
    }
  }

  Future<void> flush() async {
    saver!.change(values());
    await saver!.flush();
  }

  @override
  void dispose() {
    if (tabGuard?.save == flush) tabGuard?.save = null;
    saver?.removeListener(refresh);
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selected = app.workspace.partners
        .where((a) => a.id == peer)
        .firstOrNull;
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: PageFrame(
        title: editing ? '요청 내용 수정' : '새 사입 요청',
        subtitle: editing ? '수락 전 최신 내용으로 수정해요' : '상품·옵션 하나를 요청에 담아요',
        bottom: ActionButton(
          editing ? '수정 내용 확인' : '요청 내용 확인',
          bottom: true,
          onPressed: () async {
            if (!editing) {
              saver!.change(values());
              await saver!.flush();
            }
            if (!context.mounted) return;
            final confirmed = await confirm(
              context,
              editing ? '이 내용으로 수정할까요?' : '요청을 보낼까요?',
              '담당: ${selected?.name ?? '미선택'}\n도매처: ${fields['wholesaler']!.text} · ${fields['location']!.text}\n상품: ${fields['product']!.text} / ${fields['option']!.text}\n수량: ${fields['quantity']!.text}개\n배송지: ${fields['address']!.text} ${fields['addressDetail']!.text}',
            );
            if (!confirmed) return;
            if (editing) {
              await app.workspace.updateRequest(
                id,
                values(),
                version,
                operation,
              );
            } else {
              await app.workspace.sendDraft(id, operation);
            }
            if (!context.mounted) return;
            setState(() => leaving = true);
            Navigator.of(context).pushReplacement(
              PageRouteBuilder<void>(
                pageBuilder: (context, a, b) => RequestDetailPage(id),
              ),
            );
          },
        ),
        children: [
          FigmaSurface(
            children: [
              Item(
                '담당 사입삼촌',
                subtitle: selected?.name ?? '선택하지 않음 · 초안 저장 가능',
                onTap: editing
                    ? null
                    : () async {
                        final result = await openPage<String>(
                          context,
                          PageFrame(
                            title: '사입삼촌 선택',
                            children: [
                              if (app.workspace.partners.isEmpty)
                                const EmptyState(
                                  '연결된 사입삼촌이 없어요',
                                  '초안 작성 후 사입삼촌 탭에서 연결해 주세요.',
                                ),
                              for (final a in app.workspace.partners)
                                Builder(
                                  builder: (context) => Item(
                                    a.name,
                                    subtitle:
                                        '${a.s('pickupArea')} · ${a.s('deadline')}',
                                    onTap: () => Navigator.pop(context, a.id),
                                  ),
                                ),
                            ],
                          ),
                        );
                        if (result != null && mounted) {
                          peer = result;
                          changed();
                        }
                      },
              ),
            ],
          ),
          const Section('도매처'),
          FigmaSurface(
            children: [
              Field(
                '도매처 이름',
                controller: fields['wholesaler']!,
                onChanged: (_) => changed(),
              ),
              Field(
                '시장·상가·건물·층',
                controller: fields['location']!,
                onChanged: (_) => changed(),
              ),
            ],
          ),
          const Section('상품·옵션'),
          FigmaSurface(
            children: [
              Field(
                '상품명',
                controller: fields['product']!,
                onChanged: (_) => changed(),
              ),
              Field(
                '색상·사이즈 등 옵션',
                controller: fields['option']!,
                onChanged: (_) => changed(),
              ),
              Field(
                '요청 수량',
                controller: fields['quantity']!,
                numeric: true,
                onChanged: (_) => changed(),
              ),
            ],
          ),
          FigmaSurface(
            children: [
              AttachmentField(
                label: '상품 사진',
                multiple: true,
                ids: photos,
                onChanged: (v) {
                  photos = v;
                  changed();
                },
              ),
              Field(
                '요청사항',
                controller: fields['note']!,
                multiline: true,
                onChanged: (_) => changed(),
              ),
            ],
          ),
          const Section('이번 요청의 배송지'),
          FigmaSurface(
            children: [
              Field(
                '주소',
                controller: fields['address']!,
                onChanged: (_) => changed(),
              ),
              Field(
                '상세주소',
                controller: fields['addressDetail']!,
                onChanged: (_) => changed(),
              ),
            ],
          ),
          if (!editing)
            Info(
              saver!.error ??
                  (saver!.saving ? '초안을 저장하고 있어요' : '초안은 나만 볼 수 있어요.'),
              error: saver!.error != null,
            ),
          if (saver!.error != null)
            ActionButton(
              '초안 저장 다시 시도',
              weak: true,
              onPressed: () => saver!.flush(),
            ),
          ActionButton(
            editing ? '닫기' : '초안 저장 후 닫기',
            weak: true,
            onPressed: leave,
          ),
        ],
      ),
    );
  }
}

class RequestHub extends StatelessWidget {
  const RequestHub({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        drafts = app.workspace.records('drafts'),
        recent = app.workspace.records('requests').take(10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionButton(
          '새로 작성',
          icon: 'plus',
          onPressed: () => openPage(context, const RequestEditor()),
        ),
        const Section('작성 중'),
        if (drafts.isEmpty)
          const EmptyState('작성 중인 요청이 없어요', '연결 전에도 초안을 작성할 수 있어요.'),
        for (final d in drafts) ...[
          Item(
            d.s('product').isEmpty ? '제목 없는 초안' : d.s('product'),
            leading: const FigmaIcon('shirt'),
            subtitle: '${d.s('wholesaler')} · ${displayTime(d.s('updatedAt'))}',
            onTap: () => openPage(context, RequestEditor(draftId: d.id)),
          ),
          ActionButton(
            '초안 삭제',
            weak: true,
            onPressed: () async {
              if (await confirm(
                context,
                '초안을 삭제할까요?',
                '아직 전송하지 않은 요청이에요. 상대방에게는 영향이 없어요.',
              )) {
                await app.workspace.deleteDraft(d.id);
              }
            },
          ),
        ],
        const Section('최근 요청'),
        for (final r in recent) ...[
          RequestCard(
            RequestRecord(r.id, r.data),
            onTap: () => openPage(context, RequestDetailPage(r.id)),
          ),
          ActionButton(
            '다시 작성',
            icon: 'copy',
            weak: true,
            onPressed: () async {
              final id = await app.workspace.repeatRequest(r.id);
              if (context.mounted) {
                await openPage(context, RequestEditor(draftId: id));
              }
            },
          ),
        ],
      ],
    );
  }
}

class RequestDetailPage extends StatelessWidget {
  const RequestDetailPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), r = app.workspace.request(id);
    if (r == null) {
      return const PageFrame(
        title: '요청 상세',
        children: [EmptyState('요청을 열 수 없어요', '현재 계정이 참여한 요청인지 확인해 주세요.')],
      );
    }
    final retailer = app.session.current!.id == r.s('retailerId'),
        peer = r.s(retailer ? 'uncleId' : 'retailerId');
    final deliveries = app.workspace
        .records('deliveries')
        .where((d) => d.s('requestId') == id);
    final proposals = app.workspace
        .records('proposals')
        .where((p) => p.s('requestId') == id);
    final issues = app.workspace
        .records('issues')
        .where((i) => i.s('requestId') == id);
    final awaiting = deliveries
        .where((d) => !d.b('receiptRecorded'))
        .firstOrNull;
    final primary = !r.ended && !retailer && r.s('status') == 'pending'
        ? ActionButton(
            '요청 수락',
            bottom: true,
            onPressed: () async {
              if (await confirm(
                context,
                '요청을 수락할까요?',
                '상품·수량·도매처·배송지를 확인했어요.',
              )) {
                await app.workspace.act(id, 'accept', {}, r.version, newId());
              }
            },
          )
        : !r.ended && !retailer && r.s('status') == 'accepted'
        ? ActionButton(
            '이번 추가 확보 입력',
            bottom: true,
            onPressed: () => openPage(context, RequestActionPage(id, 'result')),
          )
        : !r.ended && retailer && r.needsReply
        ? ActionButton(
            '미송 ${r.backorder}장 답변하기',
            bottom: true,
            onPressed: () => openPage(context, BackorderReplyPage(id)),
          )
        : retailer && awaiting != null
        ? ActionButton(
            '이번 전달분 수령 확인',
            bottom: true,
            onPressed: () => openPage(
              context,
              RequestActionPage(id, 'receive', deliveryId: awaiting.id),
            ),
          )
        : null;
    return PageFrame(
      title: '사입 요청 상세',
      navigationSubtitle: '${r.s('product')} · ${r.statusLabel}',
      bottom: primary,
      children: [
        FigmaSurface(
          children: [
            Inset(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    r.statusLabel,
                    attention: r.needsReply || r.n('openIssues') > 0,
                  ),
                  TdsText(
                    displayTime(r.s('createdAt')),
                    typography: TdsTypography.t7,
                    color: TdsTheme.of(context).color('grey600'),
                  ),
                ],
              ),
            ),
            PageHeading(
              r.s('product'),
              description: '${r.s('option')} · 요청 ${r.quantity}장',
            ),
            const TdsBorder(),
            Item(
              app.workspace.profile(peer)?.name ?? '거래처',
              leading: const FigmaIcon('store'),
              subtitle: retailer ? '담당 사입삼촌' : '요청한 소매업자',
              onTap: () => openPage(context, PartnerPage(peer)),
            ),
          ],
        ),
        Info(
          retailer && r.needsReply
              ? '남은 미송 ${r.backorder}장을 결정해 주세요'
              : r.s('status') == 'pending'
              ? (retailer ? '사입삼촌의 확인을 기다려요' : '새 사입 요청을 확인해 주세요')
              : r.delivered > r.received
              ? '받은 상품을 확인해 주세요'
              : r.ended
              ? '요청 처리를 마쳤어요'
              : '사입 진행 상황을 확인해요',
        ),
        FigmaSurface(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                children: [
                  for (final metric in {
                    '누적 확보': r.acquired,
                    '전달 대기': r.available,
                    '누적 전달': r.delivered,
                    r.b('resultShared') ? '남은 미송' : '미확인 수량': r.remaining,
                  }.entries)
                    SizedBox(
                      width: constraints.maxWidth / 2,
                      child: TdsListRow(
                        contents: TdsListRowTexts(
                          type: TdsListRowTextType.row2TypeD,
                          top: Text(metric.key),
                          bottom: Text('${metric.value}장'),
                          topProps: const TdsListRowTextStyle(
                            typography: TdsTypography.t7,
                          ),
                          bottomProps: TdsListRowTextStyle(
                            typography: TdsTypography.t3,
                            fontWeight: TdsFontWeight.bold,
                            color: TdsTheme.of(context).color('grey900'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (r.cancelled > 0) QuantityRow('취소', '${r.cancelled}장'),
            if (r.n('held') > 0) QuantityRow('처리 보류', '${r.n('held')}장'),
          ],
        ),
        if (r.s('recheck').isNotEmpty && r.backorder > 0)
          FigmaSurface(
            tinted: true,
            children: [
              Item(
                '${r.s('recheck')} 미송 재확인',
                subtitle: r.needsReply
                    ? '확보한 상품은 먼저 전달할 수 있어요. 남은 미송의 처리 방법을 답변해 주세요.'
                    : '남은 미송은 재확인일에 다시 확인해요.',
              ),
            ],
          ),
        const Section('사입·배송 정보'),
        FigmaSurface(
          children: [
            Item(
              '사입할 곳',
              subtitle: '${r.s('wholesaler')} · ${r.s('location')}',
            ),
            Item(
              '이번 요청 수령지',
              subtitle: '${r.s('address')} ${r.s('addressDetail')}',
            ),
            if (r.s('note').isNotEmpty) Item('요청사항', subtitle: r.s('note')),
          ],
        ),
        if (r.list('photos').isNotEmpty)
          FigmaSurface(
            children: [
              for (final photo in r.list('photos'))
                AttachmentPreview(photo, compact: true),
            ],
          ),
        const Section('요청 관리'),
        FigmaSurface(
          children: [
            Item(
              '관련 채팅 열기',
              leading: const FigmaIcon('chat'),
              onTap: () => openPage(context, ChatPage(peer, requestId: id)),
            ),
            if (!r.ended) ...[
              if (!retailer && r.s('status') == 'pending') ...[
                Item(
                  '요청 거절',
                  leading: const FigmaIcon('x_circle'),
                  onTap: () =>
                      openPage(context, RequestActionPage(id, 'reject')),
                ),
              ],
              if (retailer && r.s('status') == 'pending') ...[
                Item(
                  '내용 수정',
                  leading: const FigmaIcon('pencil'),
                  onTap: () => openPage(context, RequestEditor(requestId: id)),
                ),
                ActionButton(
                  '요청 취소',
                  weak: true,
                  danger: true,
                  onPressed: () async {
                    if (await confirm(
                      context,
                      '요청을 취소할까요?',
                      '취소하면 상대방이 수락할 수 없어요.',
                    )) {
                      await app.workspace.act(
                        id,
                        'cancel',
                        {},
                        r.version,
                        newId(),
                      );
                    }
                  },
                ),
              ],
              if (r.s('status') == 'accepted') ...[
                if (!retailer && r.s('proposalId').isEmpty)
                  Item(
                    '확보 수량 정정',
                    leading: const FigmaIcon('refresh'),
                    onTap: () =>
                        openPage(context, ProposalPage(id, 'correction')),
                  ),
                if (r.s('proposalId').isEmpty) ...[
                  Item(
                    '상품·수량·배송지 변경 협의',
                    leading: const FigmaIcon('pencil'),
                    onTap: () => openPage(context, ProposalPage(id, 'change')),
                  ),
                  Item(
                    '취소 협의',
                    leading: const FigmaIcon('x_circle'),
                    onTap: () => openPage(context, ProposalPage(id, 'cancel')),
                  ),
                ],
              ],
            ],
            if (retailer &&
                !['pending', 'cancelled', 'rejected'].contains(r.s('status')))
              Item(
                '문제 알리기',
                leading: const FigmaIcon('bell'),
                onTap: () => openPage(context, RequestActionPage(id, 'issue')),
              ),
            if (!retailer && r.s('status') == 'accepted')
              Item(
                '상품 전달하기',
                leading: const FigmaIcon('truck'),
                subtitle: '실제로 전달한 수량을 기록해요',
                onTap: () => openPage(context, DeliveryBatchPage([id])),
              ),
          ],
        ),
        if (proposals.isNotEmpty) const Section('변경·취소·정정'),
        for (final p in proposals) ProposalCard(p),
        const Section('전달·수령 내역'),
        if (deliveries.isEmpty)
          const FigmaSurface(children: [Info('아직 전달 기록이 없어요.')]),
        for (final d in deliveries) DeliveryCard(d),
        if (issues.isNotEmpty) const Section('문제와 조치'),
        for (final issue in issues) IssueCard(issue),
        const Section('처리 이력'),
        FigmaSurface(
          children: [
            for (final e
                in app.workspace
                    .records('events')
                    .where((e) => e.s('requestId') == id))
              Item(
                e.s('title'),
                subtitle: displayTime(e.s('createdAt')),
                onTap: () => openPage(context, EventPage(e)),
              ),
          ],
        ),
      ],
    );
  }
}

class EventPage extends StatelessWidget {
  const EventPage(this.record, {super.key});
  final Record record;
  @override
  Widget build(BuildContext context) {
    final before = mapOf(record.data, 'before'),
        after = mapOf(record.data, 'after');
    return PageFrame(
      title: '처리 이력',
      subtitle: displayTime(record.s('createdAt')),
      children: [
        PageHeading(record.s('title')),
        FigmaSurface(
          children: [
            for (final e in {
              'product': '상품',
              'option': '옵션',
              'quantity': record.s('deliveryId').isEmpty ? '요청 수량' : '이번 전달 수량',
              'acquired': '확보 수량',
              'delivered': '전달 수량',
              'received': '수령 수량',
              'cancelled': '취소 수량',
              'address': '배송지',
              'addressDetail': '상세주소',
              'recheck': '재확인일',
              'status': '처리 상태',
            }.entries)
              if (before[e.key] != after[e.key])
                Item(
                  e.value,
                  subtitle:
                      '${before[e.key] ?? '없음'} → ${after[e.key] ?? '없음'}',
                ),
          ],
        ),
      ],
    );
  }
}

class RequestActionPage extends StatefulWidget {
  const RequestActionPage(
    this.id,
    this.action, {
    this.deliveryId,
    this.issueId,
    super.key,
  });
  final String id, action;
  final String? deliveryId, issueId;
  @override
  State<RequestActionPage> createState() => _RequestActionPageState();
}

class _RequestActionPageState extends State<RequestActionPage> {
  final reason = TextEditingController(),
      quantity = TextEditingController(),
      backorder = TextEditingController(),
      held = TextEditingController(text: '0');
  String date = '', op = newId();
  String issueDelivery = '', issueType = '상품·옵션이 달라요';
  bool needsReply = true, ready = false;
  late int version;
  late RequestRecord initial;
  int additional = 0;
  bool mismatch = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    final app = AppScope.read(context), r = app.workspace.request(widget.id)!;
    initial = r;
    version = r.version;
    if (widget.deliveryId != null) {
      final d = app.workspace
          .records('deliveries')
          .firstWhere((d) => d.id == widget.deliveryId);
      version = d.version;
      quantity.text = '${d.n('quantity')}';
    } else {
      quantity.text = '${r.acquired}';
      backorder.text = '${r.remaining}';
    }
    if (widget.issueId != null) {
      version = app.workspace
          .records('issues')
          .firstWhere((i) => i.id == widget.issueId)
          .version;
    }
    date = r.s('recheck').isEmpty
        ? dateOnly(DateTime.now().add(const Duration(days: 1)))
        : r.s('recheck');
  }

  @override
  void dispose() {
    reason.dispose();
    quantity.dispose();
    backorder.dispose();
    held.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), r = app.workspace.request(widget.id)!;
    if (widget.action == 'result') return acquisition(context, r);
    if (widget.action == 'receive') return receipt(context, r);
    final title = switch (widget.action) {
      'result' => '확보·미송 결과',
      'receive' => '수령 확인',
      'issue' => '문제 알리기',
      'action' => '문제 조치 기록',
      _ => '요청 거절',
    };
    return PageFrame(
      title: title,
      subtitle: '${r.s('product')} · 요청 ${r.quantity}개',
      bottom: ActionButton(
        switch (widget.action) {
          'result' => '결과 공유',
          'receive' => '수령 확인',
          'issue' => '문제 신고',
          'action' => '조치 기록',
          _ => '사유와 함께 거절',
        },
        bottom: true,
        onPressed: () async {
          if (widget.action == 'receive') {
            await app.workspace.receive(
              widget.deliveryId!,
              int.tryParse(quantity.text) ?? -1,
              reason.text,
              version,
              op,
            );
          } else if (widget.action == 'issue') {
            if (reason.text.trim().isEmpty) {
              throw const AppFailure('문제 상황을 입력해 주세요.');
            }
            await app.workspace.reportIssue(
              widget.id,
              {
                'reason': '$issueType\n${reason.text.trim()}',
                'held': int.tryParse(held.text) ?? -1,
                if (issueDelivery.isNotEmpty) 'deliveryId': issueDelivery,
              },
              version,
              op,
            );
          } else if (widget.action == 'action') {
            await app.workspace.actOnIssue(
              widget.issueId!,
              'action',
              reason.text,
              version,
              op,
            );
          } else {
            await app.workspace.act(
              widget.id,
              widget.action,
              {
                'reason': reason.text,
                'acquired': int.tryParse(quantity.text) ?? -1,
                'backorder': int.tryParse(backorder.text) ?? -1,
                'recheck': date,
                'needsReply': needsReply,
              },
              version,
              op,
            );
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        if (widget.action == 'issue') ...[
          const PageHeading('받은 상품이 다른 점'),
          FigmaSurface(
            children: [
              for (final label in const [
                '상품·옵션이 달라요',
                '수량이 부족해요',
                '오염·파손이 있어요',
              ])
                Inset(
                  child: TdsCheckbox(
                    inputType: TdsCheckboxInputType.radio,
                    checked: issueType == label,
                    onChanged: (_) => setState(() => issueType = label),
                    child: Text(label),
                  ),
                ),
            ],
          ),
          const Section('문제가 있는 전달 회차'),
          FigmaSurface(
            children: [
              Choices(
                options: const ['요청 전체', '전달 회차 선택'],
                value: issueDelivery.isEmpty ? '요청 전체' : '전달 회차 선택',
                onChanged: (value) async {
                  if (value == '요청 전체') {
                    setState(() => issueDelivery = '');
                    return;
                  }
                  final selected = await openPage<String>(
                    context,
                    PageFrame(
                      title: '전달 회차 선택',
                      children: [
                        for (final d
                            in app.workspace
                                .records('deliveries')
                                .where((d) => d.s('requestId') == widget.id))
                          Builder(
                            builder: (context) => Item(
                              '${displayTime(d.s('createdAt'))} · ${d.n('quantity')}개',
                              subtitle: '${d.s('product')} · ${d.s('option')}',
                              onTap: () => Navigator.pop(context, d.id),
                            ),
                          ),
                        if (!app.workspace
                            .records('deliveries')
                            .any((d) => d.s('requestId') == widget.id))
                          const EmptyState('전달 내역이 없어요', '요청 전체의 문제로 알려 주세요.'),
                      ],
                    ),
                  );
                  if (mounted && selected != null) {
                    setState(() => issueDelivery = selected);
                  }
                },
              ),
              Field('보류할 미전달 확보 수량', controller: held, numeric: true),
              Info('현재 전달 가능 ${r.available}개예요. 해당 물량만 다음 처리를 보류해요.'),
              Item(
                '문제 상품 사진 보내기',
                subtitle: '이 요청에 연결된 채팅에 사진을 남겨요',
                onTap: () => openPage(
                  context,
                  ChatPage(r.s('uncleId'), requestId: r.id),
                ),
              ),
            ],
          ),
        ],
        FigmaSurface(
          children: [
            Field(
              widget.action == 'receive' ? '수량 차이 설명 (일치하면 선택)' : '사유·설명·조치 내용',
              controller: reason,
              multiline: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget acquisition(BuildContext context, RequestRecord current) {
    final app = AppScope.of(context),
        remaining = initial.remaining - additional;
    return PageFrame(
      title: '확보 결과 입력',
      bottom: ActionButton(
        '추가 확보 $additional장 공유',
        bottom: true,
        onPressed: () async {
          await app.workspace.act(
            widget.id,
            'result',
            {
              'acquired': initial.acquired + additional,
              'backorder': remaining,
              'recheck': date,
              'needsReply': remaining > 0 && needsReply,
              'reason': reason.text,
            },
            version,
            op,
          );
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        PageHeading(
          '이번에 추가로 확보한 수량',
          eyebrow: app.workspace.profile(initial.s('retailerId'))?.name,
        ),
        FigmaSurface(
          children: [
            Item(
              initial.s('product'),
              subtitle:
                  '${initial.s('option')} · 요청 ${initial.quantity}장\n이전 누적 확보 ${initial.acquired}장 · 이전 전달 ${initial.delivered}장',
            ),
          ],
        ),
        const Section('이번 추가 확보'),
        FigmaSurface(
          children: [
            const TdsSpacing(12),
            Center(
              child: TdsNumericSpinner(
                size: TdsNumericSpinnerSize.large,
                number: additional,
                minNumber: 0,
                maxNumber: initial.remaining,
                semanticLabel: '이번 추가 확보 수량',
                onNumberChange: (n) => setState(() => additional = n),
              ),
            ),
          ],
        ),
        Info('추가 가능한 수량 0–${initial.remaining}장'),
        const Section('저장 후 진행 상황'),
        FigmaSurface(
          children: [
            QuantityRow('기존 확보', '${initial.acquired}장'),
            QuantityRow('저장 후 누적 확보', '${initial.acquired + additional}장'),
            QuantityRow('확보 후 전달 대기', '${initial.available + additional}장'),
            QuantityRow('남은 미송', '$remaining장'),
          ],
        ),
        if (remaining > 0) ...[
          const Section('남은 미송'),
          FigmaSurface(
            children: [
              Item(
                '재확인일',
                subtitle: date,
                onTap: () async {
                  final value = await openPage<String>(context, DatePage(date));
                  if (value != null && mounted) setState(() => date = value);
                },
              ),
              Field('미송 사유', controller: reason, multiline: true),
              Toggle(
                '소매업자 응답 요청',
                value: needsReply,
                onChanged: (v) => setState(() => needsReply = v),
              ),
            ],
          ),
        ],
        if (current.version != version)
          const Info('다른 작업으로 요청이 변경됐어요. 뒤로 돌아가 최신 수량을 확인해 주세요.', error: true),
        Item(
          '이전 기록이 틀렸나요? 기록 수정',
          onTap: () => openPage(context, ProposalPage(widget.id, 'correction')),
        ),
      ],
    );
  }

  Widget receipt(BuildContext context, RequestRecord r) {
    final app = AppScope.of(context);
    final batches =
        app.workspace
            .records('deliveries')
            .where((d) => d.s('requestId') == widget.id)
            .toList()
          ..sort((a, b) => a.s('createdAt').compareTo(b.s('createdAt')));
    final current = batches.firstWhere((d) => d.id == widget.deliveryId);
    final actual = int.tryParse(quantity.text) ?? -1;
    final completes =
        actual == current.n('quantity') &&
        r.n('openIssues') == 0 &&
        r.s('proposalId').isEmpty &&
        r.backorder == 0 &&
        r.received + actual == r.quantity - r.cancelled &&
        r.delivered == r.quantity - r.cancelled;
    return PageFrame(
      title: '상품 수령 확인',
      bottom: ActionButton(
        '$actual장 수령 확인${completes ? ' · 요청 완료' : ''}',
        bottom: true,
        onPressed: () async {
          await app.workspace.receive(
            widget.deliveryId!,
            actual,
            reason.text,
            version,
            op,
          );
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        PageHeading('이번에 받은 ${current.n('quantity')}장이 맞나요?'),
        FigmaSurface(
          children: [
            Item(
              '${app.workspace.profile(r.s('uncleId'))?.name ?? '사입삼촌'} · ${current.s('product')}',
              subtitle:
                  '${current.s('option')} · 전체 받을 수량 ${r.quantity - r.cancelled}장',
            ),
          ],
        ),
        const Section('전달 회차'),
        FigmaSurface(
          children: [
            for (var i = 0; i < batches.length; i++)
              QuantityRow(
                '${i + 1}차 · ${displayTime(batches[i].s('createdAt'))}',
                '${batches[i].n('quantity')}장 · ${batches[i].id == current.id
                    ? '이번 확인'
                    : batches[i].b('receiptRecorded')
                    ? '수령 확인됨'
                    : '확인 대기'}',
              ),
            const TdsBorder(),
            QuantityRow('누적 전달', '${r.delivered}장'),
            QuantityRow('남은 미송', '${r.backorder}장'),
          ],
        ),
        FigmaSurface(
          tinted: true,
          children: [
            Item(
              '상품·옵션·수량을 비교해 주세요',
              subtitle: completes
                  ? '이번 ${current.n('quantity')}장이 맞으면 요청을 마쳐요.'
                  : '이번 전달분만 확인해요. 남은 미송과 다른 전달분은 계속 확인할 수 있어요.',
            ),
          ],
        ),
        FigmaSurface(
          children: [
            Item(
              '상품이나 수량이 달라요',
              onTap: () => setState(() => mismatch = !mismatch),
            ),
            if (mismatch) ...[
              Field(
                '실제 받은 수량',
                controller: quantity,
                numeric: true,
                onChanged: (_) => setState(() {}),
              ),
              Field('수량 차이 설명 (일치하면 선택)', controller: reason, multiline: true),
              Item(
                '상품·옵션 문제 알리기',
                onTap: () =>
                    openPage(context, RequestActionPage(widget.id, 'issue')),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class DatePage extends StatefulWidget {
  const DatePage(this.initial, {super.key});
  final String initial;
  @override
  State<DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<DatePage> {
  late DateTime selected = DateTime.tryParse(widget.initial) ?? DateTime.now();
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '재확인일 선택',
    children: [
      SizedBox(
        height: 420,
        child: TdsDatePicker(
          selectedDate: selected,
          initialMonth: selected,
          controlled: true,
          onDateChange: (date) {
            if (date != null) setState(() => selected = date);
          },
        ),
      ),
      ActionButton(
        '${dateOnly(selected)} 선택',
        onPressed: () => Navigator.pop(context, dateOnly(selected)),
      ),
    ],
  );
}

class ProposalPage extends StatefulWidget {
  const ProposalPage(this.id, this.kind, {this.deliveryId, super.key});
  final String id, kind;
  final String? deliveryId;
  @override
  State<ProposalPage> createState() => _ProposalPageState();
}

class _ProposalPageState extends State<ProposalPage> {
  final fields = <String, TextEditingController>{};
  bool ready = false;
  late int version;
  String op = newId();
  String recheck = dateOnly(DateTime.now().add(const Duration(days: 1)));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    final app = AppScope.read(context), r = app.workspace.request(widget.id)!;
    version = r.version;
    if (r.s('recheck').isNotEmpty) recheck = r.s('recheck');
    for (final key in [
      'product',
      'option',
      'wholesaler',
      'location',
      'address',
      'addressDetail',
      'note',
    ]) {
      fields[key] = TextEditingController(text: r.s(key));
    }
    final d = app.workspace
        .records('deliveries')
        .where((d) => d.id == widget.deliveryId)
        .firstOrNull;
    for (final e in {
      'quantity': widget.kind == 'cancel'
          ? r.remaining
          : d?.n('quantity') ?? r.quantity,
      'acquired': r.acquired,
      'received': d?.n('received') ?? r.received,
      'acquiredCancelled': 0,
    }.entries) {
      fields[e.key] = TextEditingController(text: '${e.value}');
    }
    fields['reason'] = TextEditingController();
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), r = app.workspace.request(widget.id)!;
    return PageFrame(
      title: switch (widget.kind) {
        'change' => '변경안 작성',
        'cancel' => '취소 협의',
        _ => widget.deliveryId == null ? '확보 수량 정정' : '전달 기록 정정',
      },
      bottom: ActionButton(
        '상대방에게 확인 요청',
        bottom: true,
        onPressed: () async {
          final values = <String, Object?>{
            for (final e in fields.entries)
              e.key:
                  [
                    'quantity',
                    'acquired',
                    'received',
                    'acquiredCancelled',
                  ].contains(e.key)
                  ? int.tryParse(e.value.text) ?? -1
                  : e.value.text.trim(),
            if (widget.deliveryId != null) 'deliveryId': widget.deliveryId,
            if (widget.kind == 'correction') 'recheck': recheck,
            'uncleId': r.s('uncleId'),
            'photos': r.list('photos'),
          };
          await app.workspace.propose(
            widget.id,
            widget.kind,
            values,
            version,
            op,
          );
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        Info(
          '요청 ${r.quantity} · 확보 ${r.acquired} · 전달 ${r.delivered} · 수령 ${r.received} · 취소 ${r.cancelled}',
        ),
        FigmaSurface(
          children: [
            if (widget.kind == 'change') ...[
              for (final e in {
                'product': '상품명',
                'option': '옵션',
                'wholesaler': '도매처',
                'location': '도매처 위치',
                'address': '배송지',
                'addressDetail': '상세주소',
                'note': '요청사항',
              }.entries)
                Field(e.value, controller: fields[e.key]!),
              Field(
                '변경 후 요청 수량',
                controller: fields['quantity']!,
                numeric: true,
              ),
            ],
            if (widget.kind == 'cancel') ...[
              Field('이번 취소 수량', controller: fields['quantity']!, numeric: true),
              Field(
                '취소 수량 중 이미 확보한 수량',
                controller: fields['acquiredCancelled']!,
                numeric: true,
              ),
              const Info(
                '이미 전달한 물량은 바로 취소할 수 없어요. 확보한 물품의 처리 방법을 사유에 함께 기록해 주세요.',
              ),
            ],
            if (widget.kind == 'correction') ...[
              if (widget.deliveryId != null)
                Field(
                  '정정 후 이번 전달 수량',
                  controller: fields['quantity']!,
                  numeric: true,
                ),
              Field(
                '정정 후 누적 확보 수량',
                controller: fields['acquired']!,
                numeric: true,
              ),
              if (widget.deliveryId != null)
                Field(
                  '정정 후 이번 수령 확인 수량',
                  controller: fields['received']!,
                  numeric: true,
                ),
              const Info('원래 기록과 정정 사유를 남기고 상대방이 확인한 뒤 반영해요.'),
              Item(
                '정정 후 미송이 남으면 재확인할 날짜',
                subtitle: recheck,
                onTap: () async {
                  final value = await openPage<String>(
                    context,
                    DatePage(recheck),
                  );
                  if (value != null && mounted) setState(() => recheck = value);
                },
              ),
            ],
            Field(
              '사유·협의할 처리 방법',
              controller: fields['reason']!,
              multiline: true,
            ),
          ],
        ),
      ],
    );
  }
}

class ProposalCard extends StatelessWidget {
  const ProposalCard(this.p, {super.key});
  final Record p;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        v = mapOf(p.data, 'values'),
        own = p.s('proposerId') == app.session.current!.id;
    final label = switch (p.s('kind')) {
      'cancel' => '취소',
      'change' => '변경',
      _ => '정정',
    };
    return FigmaSurface(
      children: [
        Item(
          '$label · ${switch (p.s('status')) {
            'pending' => '상대 확인 대기',
            'approved' => '확정',
            'withdrawn' => '철회',
            _ => '거절',
          }}',
          subtitle: '${textOf(v, 'reason')}\n${displayTime(p.s('createdAt'))}',
          onTap: () => openPage(
            context,
            PageFrame(
              title: '$label 내용',
              children: [
                for (final e in {
                  'product': '상품',
                  'option': '옵션',
                  'quantity': '수량',
                  'acquired': '누적 확보',
                  'received': '이번 수령 확인',
                  'acquiredCancelled': '확보분 취소',
                  'address': '배송지',
                  'addressDetail': '상세주소',
                  'reason': '사유',
                  'recheck': '미송 재확인일',
                }.entries)
                  if (v.containsKey(e.key))
                    Item(e.value, subtitle: '${v[e.key]}'),
              ],
            ),
          ),
        ),
        if (p.s('status') == 'pending') ...[
          if (!own)
            ActionButton(
              '$label 내용 확인·확정',
              onPressed: () async {
                if (await confirm(
                  context,
                  '협의한 내용을 확정할까요?',
                  '변경 전후 내용과 수량을 확인해 주세요. 확정 후 최신 기록에 반영돼요.',
                )) {
                  await app.workspace.respondProposal(
                    p.id,
                    true,
                    p.version,
                    newId(),
                  );
                }
              },
            ),
          ActionButton(
            own ? '제안 철회' : '제안 거절',
            weak: true,
            onPressed: () =>
                app.workspace.respondProposal(p.id, false, p.version, newId()),
          ),
        ],
      ],
    );
  }
}

class DeliveryCard extends StatelessWidget {
  const DeliveryCard(this.d, {super.key});
  final Record d;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.workspace
        .records('deliveries')
        .where((row) => row.id == this.d.id)
        .firstOrNull;
    if (current == null) return const Info('전달 기록을 찾을 수 없어요.');
    final d = current, r = app.workspace.request(d.s('requestId'))!;
    final retailer = app.session.current!.role == AppRole.retailer;
    return FigmaSurface(
      children: [
        Inset(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                d.b('receiptRecorded')
                    ? (d.n('received') == d.n('quantity') ? '수령 확인' : '수량 차이')
                    : '수령 대기',
                attention:
                    d.b('receiptRecorded') &&
                    d.n('received') != d.n('quantity'),
              ),
              TdsText(
                displayTime(d.s('createdAt')),
                typography: TdsTypography.t7,
                color: TdsTheme.of(context).color('grey600'),
              ),
            ],
          ),
        ),
        Item(
          d.s('product'),
          subtitle: d.s('option'),
          onTap: () => openPage(context, RequestDetailPage(r.id)),
        ),
        QuantityRow('이번 전달', '${d.n('quantity')}장'),
        QuantityRow('확인한 수량', '${d.n('received')}장'),
        if (d.data.containsKey('actual'))
          QuantityRow('실제 받은 수량', '${d.n('actual')}장'),
        const TdsBorder(),
        Item('수령지', subtitle: '${d.s('address')} ${d.s('addressDetail')}'),
        Item(
          '관련 채팅',
          leading: const FigmaIcon('chat'),
          onTap: () => openPage(
            context,
            ChatPage(r.s(retailer ? 'uncleId' : 'retailerId'), requestId: r.id),
          ),
        ),
        if (retailer && !d.b('receiptRecorded'))
          ActionButton(
            '이번 전달분 수령 확인',
            onPressed: () => openPage(
              context,
              RequestActionPage(r.id, 'receive', deliveryId: d.id),
            ),
          ),
        if (!retailer && r.s('proposalId').isEmpty)
          Item(
            '전달 기록 정정',
            onTap: () => openPage(
              context,
              ProposalPage(r.id, 'correction', deliveryId: d.id),
            ),
          ),
      ],
    );
  }
}

class IssueCard extends StatelessWidget {
  const IssueCard(this.issue, {super.key});
  final Record issue;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        retailer = app.session.current!.role == AppRole.retailer;
    return FigmaSurface(
      children: [
        Item(
          issue.s('reason'),
          subtitle:
              '${issue.s('status') == 'resolved'
                  ? '해결 확인'
                  : issue.s('status') == 'actionTaken'
                  ? '조치 완료 · 해결 확인 대기'
                  : '문제 확인 중'}\n보류 ${issue.n('held')}개${issue.data.containsKey('actual') ? ' · 실제 받은 수량 ${issue.n('actual')}개' : ''}\n${issue.s('action')}',
        ),
        if (issue.s('status') != 'resolved')
          ActionButton(
            retailer ? '문제 해결 확인' : '조치 내용 기록',
            weak: true,
            onPressed: () async {
              if (retailer) {
                if (await confirm(
                  context,
                  '문제가 해결됐나요?',
                  '실제 물품과 수량을 확인한 뒤 해결을 확정해 주세요.',
                )) {
                  await app.workspace.actOnIssue(
                    issue.id,
                    'resolve',
                    '',
                    issue.version,
                    newId(),
                  );
                }
              } else if (context.mounted) {
                await openPage(
                  context,
                  RequestActionPage(
                    issue.s('requestId'),
                    'action',
                    issueId: issue.id,
                  ),
                );
              }
            },
          ),
      ],
    );
  }
}

class BackorderReplyPage extends StatelessWidget {
  const BackorderReplyPage(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), r = app.workspace.request(id);
    if (r == null) {
      return const PageFrame(title: '미송 답변', children: [Info('요청을 찾을 수 없어요.')]);
    }
    return PageFrame(
      title: '미송 답변',
      bottom: ActionButton(
        '미송 ${r.backorder}장 기다리기 확정',
        bottom: true,
        onPressed: () async {
          await app.workspace.act(id, 'wait', {}, r.version, newId());
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        PageHeading('남은 미송 ${r.backorder}장을 어떻게 할까요?'),
        FigmaSurface(
          children: [
            Item(
              r.s('product'),
              subtitle: '${r.s('option')} · ${r.s('recheck')} 재확인',
            ),
            QuantityRow('확보 완료', '${r.acquired}장'),
            QuantityRow('남은 미송', '${r.backorder}장'),
          ],
        ),
        const Info('기다리기를 확정하면 사입삼촌에게 답변이 전달돼요. 취소는 상대방과 협의 후 확정돼요.'),
        ActionButton(
          '미송 취소 요청',
          weak: true,
          enabled: r.s('proposalId').isEmpty,
          onPressed: () => openPage(context, ProposalPage(id, 'cancel')),
        ),
      ],
    );
  }
}
