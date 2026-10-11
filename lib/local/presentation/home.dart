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
  final detailOpen = List.filled(5, false);
  late final observers = List.generate(
    5,
    (index) => _TabRouteObserver((open) {
      if (detailOpen[index] == open) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => detailOpen[index] = open);
      });
    }),
  );

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
      a.role == AppRole.uncle
          ? app.workspace
                .records('deliveries')
                .where((d) => d.n('received') < d.n('quantity'))
                .length
          : requests.where((r) => !r.ended).length,
      unread,
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
                                observers: [observers[i]],
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
                if (!detailOpen[selected])
                  FigmaSurface(
                    margin: 12,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < tabs.length; i++)
                            Expanded(
                              child: Semantics(
                                selected: selected == i,
                                label: badges[i] > 0
                                    ? '${tabs[i]}, 알림 ${badges[i]}개'
                                    : tabs[i],
                                child: TdsTextButton(
                                  size: TdsTextButtonSize.xsmall,
                                  colorToken: selected == i
                                      ? 'blue600'
                                      : 'grey600',
                                  onPressed: () => selectTab(i),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          FigmaIcon(
                                            const [
                                              'home',
                                              'bag',
                                              'chat',
                                              'store',
                                              'person',
                                            ][i],
                                            selected: selected == i,
                                          ),
                                          if (badges[i] > 0)
                                            Positioned(
                                              top: -6,
                                              right: -10,
                                              child: TdsBadge(
                                                size: TdsBadgeSize.xsmall,
                                                color: TdsBadgeColor.red,
                                                variant: TdsBadgeVariant.fill,
                                                child: Text('${badges[i]}'),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const TdsSpacing(6),
                                      Text(tabs[i]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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
      1 => BusinessList(onTab: onTab),
      2 => const ChatList(),
      3 => const ConnectionsList(),
      _ => const MyPage(),
    };
    return Column(
      children: [
        TdsRootTopNavigation(
          withSafeAreaTop: false,
          content: Text(index == 0 ? a.name : a.role!.tabs[index]),
          trailing: TdsTopNavigationTextButton(
            onPressed: () => openPage(context, const NoticesPage()),
            child: Text(notices == 0 ? '알림' : '알림 $notices'),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey('${a.id}-tab-$index'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [page, const TdsSpacing(16)],
            ),
          ),
        ),
      ],
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({required this.onTab, super.key});
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), account = app.session.current!;
    final retailer = account.role == AppRole.retailer;
    final all = app.workspace
        .records('requests')
        .map((r) => RequestRecord(r.id, r.data))
        .toList();
    final active = all.where((r) => !r.ended).toList();
    final attention = active
        .where(
          (r) =>
              r.n('openIssues') > 0 ||
              (retailer
                  ? r.needsReply || r.delivered > r.received
                  : r.s('status') == 'pending' || r.overdue),
        )
        .toList();
    final available = active.fold<int>(0, (n, r) => n + r.available);
    final rechecks =
        active
            .where((r) => r.backorder > 0 && r.s('recheck').isNotEmpty)
            .toList()
          ..sort((a, b) => a.s('recheck').compareTo(b.s('recheck')));
    void work() => onTab(1);
    void compose() => openPage(context, const RequestEditor());
    void delivery() => openPage(
      context,
      const PageFrame(title: '상품 전달', children: [DeliveryList()]),
    );
    Widget metric(
      String icon,
      String value,
      String label,
      String action,
      VoidCallback callback,
    ) => TdsListRow(
      left: FigmaIcon(icon, selected: true),
      contents: TdsListRowTexts(
        type: TdsListRowTextType.row2TypeA,
        top: Text(value),
        bottom: Text(label),
      ),
      right: TdsButton(
        size: TdsButtonSize.small,
        variant: TdsButtonVariant.weak,
        onPressed: callback,
        child: Text(action),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!retailer)
          Inset(
            child: TdsText(
              '${account.b('working') ? '업무 중' : '휴무 중'} · 요청 마감 ${account.s('deadline')}',
              typography: TdsTypography.t7,
              color: TdsTheme.of(context).color('grey600'),
            ),
          ),
        FigmaSurface(
          margin: 12,
          tinted: true,
          children: [
            TdsListRow(
              left: FigmaIcon(
                attention.isEmpty ? 'check' : 'clock',
                selected: true,
              ),
              contents: TdsListRowTexts(
                type: TdsListRowTextType.row2TypeA,
                top: Text(
                  attention.isEmpty
                      ? '지금 확인할 일을 모두 마쳤어요'
                      : '지금 확인할 일이 ${attention.length}건 있어요',
                ),
                bottom: Text(
                  retailer ? '사입부터 수령까지 한눈에 확인해요' : '새 요청과 미송 재확인을 확인해요',
                ),
              ),
              withArrow: true,
              onPressed: work,
            ),
          ],
        ),
        FigmaSurface(
          margin: 12,
          children: [
            Item(retailer ? '내 사입 현황' : '오늘 업무', onTap: work),
            metric(
              'bag',
              '${active.length}건',
              '진행 중인 사입 요청',
              retailer ? '요청' : '확인',
              retailer ? compose : work,
            ),
            metric(
              'shirt',
              '$available장',
              '확보 후 전달 대기',
              retailer ? '보기' : '전달',
              retailer ? work : delivery,
            ),
            metric(
              'clock',
              '${active.where((r) => r.delivered > r.received).length}건',
              retailer ? '받은 상품 확인' : '소매업자 수령 확인 대기',
              '확인',
              work,
            ),
            const TdsBorder(),
            Item('사입 내역 전체 보기', onTap: work),
          ],
        ),
        FigmaSurface(
          margin: 12,
          children: [
            Item(
              '상대방 확인 대기',
              trailing: StatusBadge(
                '${active.where((r) => retailer ? r.s('status') == 'pending' : r.needsReply).length}건',
              ),
            ),
            if (active.any(
              (r) => retailer ? r.s('status') == 'pending' : r.needsReply,
            ))
              for (final r
                  in active
                      .where(
                        (r) => retailer
                            ? r.s('status') == 'pending'
                            : r.needsReply,
                      )
                      .take(2))
                Item(
                  r.s('product'),
                  subtitle: '${r.s('option')} · ${r.statusLabel}',
                  onTap: () => openPage(context, RequestDetailPage(r.id)),
                )
            else
              const Info('상대방에게 답변을 기다리는 요청이 없어요.'),
          ],
        ),
        if (rechecks.isNotEmpty)
          FigmaSurface(
            margin: 12,
            children: [
              Item(
                '다음 미송 재확인',
                subtitle: rechecks.first.s('recheck'),
                trailing: const FigmaIcon('clock'),
              ),
              Item(
                rechecks.first.s('product'),
                subtitle: '남은 미송 ${rechecks.first.backorder}장',
                onTap: () =>
                    openPage(context, RequestDetailPage(rechecks.first.id)),
              ),
            ],
          ),
        FigmaSurface(
          margin: 12,
          children: [
            Item('최근 요청', onTap: work),
            if (all.isEmpty) const Info('아직 사입 요청이 없어요'),
            for (final r in all.take(3))
              TdsListRow(
                left: const FigmaIcon('shirt'),
                contents: TdsListRowTexts(
                  type: TdsListRowTextType.row2TypeA,
                  top: Text(r.s('product')),
                  bottom: Text('${r.s('option')} · ${r.statusLabel}'),
                ),
                withArrow: true,
                onPressed: () => openPage(context, RequestDetailPage(r.id)),
              ),
            if (retailer) Item('새 사입 요청하기', onTap: compose),
          ],
        ),
        FigmaSurface(
          margin: 12,
          children: [
            Item(
              retailer ? '함께하는 사입삼촌' : '함께하는 거래처',
              subtitle: '${app.workspace.partners.length}곳 연결됨',
              onTap: () => onTab(3),
            ),
            if (app.workspace.partners.isEmpty)
              Item(
                '거래처 연결하기',
                onTap: () => openPage(context, const AddConnectionPage()),
              ),
          ],
        ),
      ],
    );
  }
}

class BusinessList extends StatefulWidget {
  const BusinessList({required this.onTab, super.key});
  final ValueChanged<int> onTab;
  @override
  State<BusinessList> createState() => _BusinessListState();
}

class _BusinessListState extends State<BusinessList> {
  String filter = '진행 중', group = '거래처별', query = '';
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        retailer = app.session.current!.role == AppRole.retailer;
    final all = app.workspace
        .records('requests')
        .map((r) => RequestRecord(r.id, r.data))
        .toList();
    final rows = all.where((r) {
      final match = switch (filter) {
        '진행 중' => !r.ended,
        '답변 필요' => !r.ended && (r.needsReply || r.n('openIssues') > 0),
        '재확인' => r.overdue,
        '완료' => r.ended,
        _ => true,
      };
      final peer = app.workspace.profile(
        r.s(retailer ? 'uncleId' : 'retailerId'),
      );
      return match &&
          '${r.s('product')} ${r.s('wholesaler')} ${peer?.name ?? ''}'
              .toLowerCase()
              .contains(query.toLowerCase());
    }).toList();
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
    final groups = <String, List<RequestRecord>>{};
    for (final r in rows) {
      final label = retailer
          ? (priority(r) < 3 ? '내 확인이 필요한 요청' : '사입 요청')
          : group == '도매처별'
          ? r.s('wholesaler')
          : app.workspace.profile(r.s('retailerId'))?.name ?? '거래처';
      groups.putIfAbsent(label, () => []).add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Inset(
          child: TdsSearchField(
            placeholder: '상품 또는 거래처 검색',
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Choices(
          options: retailer
              ? const ['진행 중', '답변 필요', '완료', '전체']
              : const ['진행 중', '재확인', '완료', '전체'],
          value: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        if (retailer)
          FigmaSurface(
            children: [
              Item(
                '새로 작성',
                trailing: const FigmaIcon('bag', selected: true),
                onTap: () => openPage(context, const RequestEditor()),
              ),
              Item(
                '임시저장·다시 요청',
                subtitle: '임시저장 ${app.workspace.records('drafts').length}건',
                onTap: () => openPage(
                  context,
                  const PageFrame(title: '요청 작성', children: [RequestHub()]),
                ),
              ),
            ],
          )
        else ...[
          FigmaSurface(
            children: [
              Item(
                '전달할 물품',
                subtitle:
                    '전달 가능 ${all.fold<int>(0, (n, r) => n + r.available)}장',
                onTap: () => openPage(
                  context,
                  const PageFrame(title: '상품 전달', children: [DeliveryList()]),
                ),
              ),
            ],
          ),
          Choices(
            options: const ['거래처별', '도매처별'],
            value: group,
            onChanged: (v) => setState(() => group = v),
          ),
        ],
        if (rows.isEmpty)
          EmptyState(
            all.isEmpty ? '아직 사입 요청이 없어요' : '해당하는 요청이 없어요',
            app.workspace.partners.isEmpty
                ? '거래처와 연결하고 사입을 시작해 보세요.'
                : '새 요청을 보내거나 검색 조건을 바꿔 보세요.',
            action: app.workspace.partners.isEmpty ? '거래처 연결하기' : null,
            onAction: () => widget.onTab(3),
          ),
        for (final e in groups.entries) ...[
          Section('${e.key} ${e.value.length}건'),
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

/// The Figma tab bar belongs to root screens. Each tab still owns its stack,
/// scroll position and save guard when a task temporarily covers the bar.
class _TabRouteObserver extends NavigatorObserver {
  _TabRouteObserver(this.changed);
  final ValueChanged<bool> changed;
  final List<Route<dynamic>> routes = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    changed(routes.length > 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    changed(routes.length > 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    changed(routes.length > 1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = routes.indexOf(oldRoute!);
    if (index >= 0) {
      if (newRoute == null) {
        routes.removeAt(index);
      } else {
        routes[index] = newRoute;
      }
    }
    changed(routes.length > 1);
  }
}
