import 'package:flutter/widgets.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';

/// 서버 응답이 없는 작업은 원래 작업 번호와 입력으로만 다시 보낸다.
class WorkflowSyncNotice extends StatelessWidget {
  const WorkflowSyncNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = AppScope.of(context).workspace.records('workflowPending');
    if (pending.isEmpty) return const SizedBox.shrink();
    return Item(
      '서버 확인이 필요한 작업 ${pending.length}건',
      subtitle: '입력은 기기에 보관 중이에요',
      onTap: () => openPage(context, const WorkflowSyncPage()),
    );
  }
}

class WorkflowSyncPage extends StatelessWidget {
  const WorkflowSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = AppScope.of(context).workspace;
    final pending = workspace.records('workflowPending');
    return PageFrame(
      title: '동기화 대기',
      children: [
        if (pending.isEmpty) const Info('확인 대기 중인 작업이 없어요.'),
        for (final record in pending)
          FigmaSurface(
            children: [
              Item(
                workflowCommandLabel(record.s('command')),
                subtitle: displayTime(record.s('createdAt')),
                trailing: StatusBadge(
                  record.s('status') == 'rejected' ? '입력 확인 필요' : '서버 확인 대기',
                ),
              ),
              if (record.s('error').isNotEmpty) Info(record.s('error')),
              ActionButton(
                '같은 작업 다시 확인',
                onPressed: () async {
                  await workspace.workflow(
                    record.s('command'),
                    mapOf(record.data, 'args'),
                    record.s('operationId'),
                  );
                },
              ),
              if (record.s('status') == 'rejected')
                ActionButton(
                  '실패 기록 지우기',
                  weak: true,
                  onPressed: () => workspace.discardRejectedWorkflow(
                    record.s('operationId'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

String workflowCommandLabel(String command) {
  command = command.toLowerCase();
  if (command.contains('invoice')) return '청구서 처리';
  if (command.contains('payment')) return '지급·입금 기록';
  if (command.contains('handoff')) return '물품 인계';
  if (command.contains('package')) return '포장 처리';
  if (command.contains('team')) return '팀 업무';
  if (command.contains('colleague')) return '사입 동료 연결';
  return '업무 기록';
}
