import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'delivery.dart';
import 'entry.dart';
import 'requests.dart';
import 'social.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int selected = 0;
  bool ready = false;
  Timer? timer;
  final navigators = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final guards = List.generate(5, (_) => TabSaveGuard());

  Future<void> selectTab(int index) async {
    if (index == selected) return;
    try {
      await guards[selected].save?.call();
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) setState(() => selected = index);
    } catch (_) {
      // The editor shows its save failure and retains the active input.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    ready = true;
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await refresh();
      if (mounted &&
          AppScope.read(context).session.pendingDestination != null) {
        final destinationContext =
            navigators[selected].currentState?.overlay?.context;
        if (destinationContext != null && destinationContext.mounted) {
          try {
            await openDestination(destinationContext);
          } catch (error) {
            if (destinationContext.mounted) {
              await confirm(
                destinationContext,
                '알림을 열지 못했어요',
                error.toString(),
              );
            }
          }
        }
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;
    try {
      await AppScope.read(context).workspace.refreshReminders();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        a = app.session.current!,
        tabs = a.role!.tabs;
    final requests = app.workspace
        .records('requests')
        .map((r) => RequestRecord(r.id, r.data));
    final unread = app.workspace
        .records('messages')
        .where((m) => m.s('recipientId') == a.id && !m.b('read'))
        .length;
    final badges = [
      requests
          .where(
            (r) => a.role == AppRole.retailer
                ? (r.needsReply ||
                      r.delivered > r.received ||
                      r.n('openIssues') > 0)
                : r.s('status') == 'pending' || r.overdue,
          )
          .length,
      unread,
      a.role == AppRole.uncle
          ? app.workspace
                .records('deliveries')
                .where((d) => d.n('received') < d.n('quantity'))
                .length
          : 0,
      app.workspace
          .records('connections')
          .where((c) => c.s('status') == 'pending' && c.s('to') == a.id)
          .length,
      0,
    ];
    return TdsToastProvider(
      child: TdsDialogProvider(
        child: ColoredBox(
          color: TdsTheme.of(context).color('background'),
          child: SafeArea(
            child: Column(
              children: [
                if (app.session.syncError != null)
                  Inset(
                    child: TdsTextButton(
                      size: TdsTextButtonSize.small,
                      onPressed: () async {
                        try {
                          await app.session.retrySync();
                        } catch (_) {}
                      },
                      child: Text('${app.session.syncError} 다시 연결'),
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: selected,
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        TickerMode(
                          enabled: selected == i,
                          child: TabSaveScope(
                            guard: guards[i],
                            child: NavigatorPopHandler<Object?>(
                              enabled: selected == i,
                              onPopWithResult: (_) =>
                                  navigators[i].currentState?.maybePop(),
                              child: Navigator(
                                key: navigators[i],
                                onGenerateRoute: (_) => PageRouteBuilder<void>(
                                  pageBuilder: (context, a, b) =>
                                      HomeTabPage(index: i, onTab: selectTab),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const TdsBorder(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: selected == i,
                            label: tabs[i],
                            child: TdsTextButton(
                              size: TdsTextButtonSize.xsmall,
                              colorToken: selected == i ? 'blue600' : 'grey600',
                              onPressed: () => selectTab(i),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 24,
                                    child: Center(
                                      child: badges[i] > 0
                                          ? StatusBadge('${badges[i]}')
                                          : null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Center(child: Text(tabs[i])),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTabPage extends StatelessWidget {
  const HomeTabPage({required this.index, required this.onTab, super.key});
  final int index;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.session.current!;
    final notices = app.workspace
        .records('notices')
        .where(
          (n) =>
              !n.b('read') &&
              mapOf(a.data, 'notificationSettings')[n.s('kind')] != false,
        )
        .length;
    final page = switch (index) {
      0 => Dashboard(onTab: onTab),
      1 => const ChatList(),
      2 =>
        a.role == AppRole.retailer
            ? const RequestHub()
            : DeliveryList(onWork: () => onTab(0)),
      3 => const ConnectionsList(),
      _ => const MyPage(),
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TdsTop(
                title: TdsTopTitleParagraph(a.role!.tabs[index], size: 28),
                subtitleBottom: TdsTopSubtitleParagraph(a.name),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: TdsTextButton(
                size: TdsTextButtonSize.small,
                onPressed: () => openPage(context, const NoticesPage()),
                child: Text(notices == 0 ? '알림' : '알림 $notices'),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey('${a.id}-tab-$index'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [page, const TdsSpacing(24)],
            ),
          ),
        ),
      ],
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({required this.onTab, super.key});
  final ValueChanged<int> onTab;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String filter = '전체', group = '거래처별';
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        retailer = app.session.current!.role == AppRole.retailer,
        all = app.workspace
            .records('requests')
            .map((r) => RequestRecord(r.id, r.data))
            .toList();
    final rows = all
        .where(
          (r) => switch (filter) {
            '진행 중' => !r.ended && r.s('status') != 'pending',
            '답변 필요' => r.needsReply || r.n('openIssues') > 0,
            '새 요청' => r.s('status') == 'pending',
            '재확인' => r.overdue,
            '완료·종료' => r.ended,
            _ => true,
          },
        )
        .toList();
    int priority(RequestRecord r) => r.n('openIssues') > 0
        ? 0
        : r.needsReply
        ? 1
        : r.delivered > r.received
        ? 2
        : r.overdue
        ? 3
        : 4;
    rows.sort((a, b) {
      final p = priority(a).compareTo(priority(b));
      return p != 0 ? p : b.s('createdAt').compareTo(a.s('createdAt'));
    });
    final summary = retailer
        ? {
            '확인 대기': all.where((r) => r.s('status') == 'pending').length,
            '진행 중': all
                .where((r) => !r.ended && r.s('status') != 'pending')
                .length,
            '답변 필요': all.where((r) => r.needsReply).length,
            '수령 대기': all.where((r) => r.delivered > r.received).length,
          }
        : {
            '새 요청': all.where((r) => r.s('status') == 'pending').length,
            '사입 진행 중': all
                .where((r) => !r.ended && r.s('status') != 'pending')
                .length,
            '재확인할 미송': all.where((r) => r.overdue).length,
            '소매업자 답변 대기': all.where((r) => r.needsReply).length,
          };
    final groups = <String, List<RequestRecord>>{};
    for (final r in rows) {
      final label = retailer
          ? ''
          : group == '도매처별'
          ? r.s('wholesaler')
          : app.workspace.profile(r.s('retailerId'))?.name ?? '';
      groups.putIfAbsent(label, () => []).add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in summary.entries)
          Item(e.key, trailing: StatusBadge('${e.value}')),
        if (retailer)
          ActionButton('새 요청', onPressed: () => widget.onTab(2))
        else
          Item(
            '전달할 물품',
            subtitle:
                '전달 가능 ${all.fold<int>(0, (sum, r) => sum + r.available)}개',
            onTap: () => widget.onTab(2),
          ),
        Choices(
          options: retailer
              ? const ['전체', '진행 중', '답변 필요', '완료·종료']
              : const ['전체', '새 요청', '진행 중', '재확인', '완료·종료'],
          value: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        if (!retailer)
          Choices(
            options: const ['거래처별', '도매처별'],
            value: group,
            onChanged: (v) => setState(() => group = v),
          ),
        if (rows.isEmpty)
          EmptyState(
            all.isEmpty ? '아직 사입 요청이 없어요' : '해당하는 요청이 없어요',
            app.workspace.partners.isEmpty
                ? '거래처와 연결하고 사입을 시작해 보세요.'
                : retailer
                ? '첫 요청을 작성해 보세요.'
                : '거래처를 확인하거나 1:1 채팅을 시작해 보세요.',
            action: app.workspace.partners.isEmpty
                ? '거래처 연결하기'
                : retailer
                ? '첫 요청 작성'
                : '거래처 확인',
            onAction: () => widget.onTab(
              app.workspace.partners.isEmpty || !retailer ? 3 : 2,
            ),
          ),
        for (final e in groups.entries) ...[
          if (e.key.isNotEmpty) Section(e.key),
          for (final r in e.value)
            RequestCard(
              r,
              onTap: () => openPage(context, RequestDetailPage(r.id)),
            ),
        ],
      ],
    );
  }
}
