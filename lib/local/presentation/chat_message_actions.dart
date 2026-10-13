import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';

const deletedMessageLabel = '삭제된 메시지입니다';

bool canChangeMessage(Record message, String? actor) =>
    message.s('senderId') == actor &&
    message.s('status') == 'sent' &&
    !message.b('system') &&
    !message.b('deleted');

/// 말풍선과 첨부를 기존 TDS 문맥 메뉴의 길게 누르기 대상으로 묶는다.
class ChatMessageActions extends StatefulWidget {
  const ChatMessageActions({
    required this.message,
    required this.child,
    super.key,
  });

  final Record message;
  final Widget child;

  @override
  State<ChatMessageActions> createState() => _ChatMessageActionsState();
}

class _ChatMessageActionsState extends State<ChatMessageActions> {
  bool open = false, busy = false;
  String? error;

  @override
  void didUpdateWidget(ChatMessageActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.version != widget.message.version ||
        oldWidget.message.id != widget.message.id) {
      open = false;
      error = null;
    }
  }

  Future<void> choose({required bool delete}) async {
    if (busy) return;
    final app = AppScope.read(context);
    final message = widget.message;
    if (!canChangeMessage(message, app.session.current?.id)) return;
    setState(() {
      open = false;
      busy = true;
      error = null;
    });
    try {
      if (delete) {
        final approved = await confirm(
          context,
          '메시지를 삭제할까요?',
          '상대방에게도 삭제된 메시지로 표시돼요. 삭제 후에는 수정하거나 되돌릴 수 없어요.',
        );
        if (!approved || !mounted) return;
        // 확인창을 열었을 때의 버전으로 실행하여 이후 변경을 덮지 않는다.
        await app.workspace.deleteMessage(message.id, message.version, newId());
      } else {
        await openPage(context, ChatMessageEditor(message));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!canChangeMessage(widget.message, app.session.current?.id)) {
      return widget.child;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (busy)
          widget.child
        else
          TdsMenuTrigger(
            openOnLongPress: true,
            open: open,
            placement: TdsOverlayPlacement.bottomEnd,
            onOpen: () => setState(() => open = true),
            onClose: () => setState(() => open = false),
            dropdown: TdsMenuDropdown(
              children: [
                TdsMenuDropdownItem(
                  onPressed: () => choose(delete: false),
                  child: const Text('메시지 수정'),
                ),
                TdsMenuDropdownItem(
                  onPressed: () => choose(delete: true),
                  child: const Text('메시지 삭제'),
                ),
              ],
            ),
            child: widget.child,
          ),
        if (error != null) Info(error!, error: true),
      ],
    );
  }
}

class ChatMessageEditor extends StatefulWidget {
  const ChatMessageEditor(this.message, {super.key});
  final Record message;

  @override
  State<ChatMessageEditor> createState() => _ChatMessageEditorState();
}

class _ChatMessageEditorState extends State<ChatMessageEditor> {
  late final body = TextEditingController(text: widget.message.s('body'));
  String? submittedBody;
  String operationId = newId();
  bool saving = false;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final value = body.text.trim();
    if (submittedBody != value) operationId = newId();
    submittedBody = value;
    setState(() => saving = true);
    try {
      await AppScope.read(context).workspace.editMessage(
        widget.message.id,
        value,
        widget.message.version,
        operationId,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.workspace
        .records('messages')
        .where((m) => m.id == widget.message.id)
        .firstOrNull;
    final unavailable =
        current == null || !canChangeMessage(current, app.session.current?.id);
    final changed = !unavailable && current.version != widget.message.version;
    return PageFrame(
      title: '메시지 수정',
      bottom: unavailable || changed
          ? ActionButton('돌아가기', onPressed: () => Navigator.pop(context))
          : ActionButton('수정 저장', onPressed: save, enabled: !saving),
      children: [
        if (unavailable)
          const Info('삭제되었거나 수정할 수 없는 메시지예요.')
        else if (changed)
          const Info('다른 곳에서 메시지가 변경됐어요. 대화로 돌아가 다시 확인해 주세요.')
        else ...[
          TdsTextField(
            controller: body,
            variant: TdsTextFieldVariant.box,
            semanticLabel: '수정할 메시지',
            label: '메시지 내용',
            multiline: true,
            autofocus: true,
            disabled: saving,
          ),
          if (current.list('attachments').isNotEmpty)
            const Info('첨부된 사진은 유지되며 메시지 내용만 수정돼요.'),
          ActionButton(
            '취소',
            weak: true,
            enabled: !saving,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ],
    );
  }
}
