import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/navigation/app_page_route.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';
import 'entry.dart';
import 'retailer_home.dart';
import 'retailer_purchase.dart';
import 'social.dart';
import 'uncle_home.dart';
import 'uncle_orders.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int selected = AppTab.home.index;
  bool changingTab = false;
  bool handlingSystemBack = false;
  bool ready = false;
  Timer? timer;
  final navigators = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final uncleOrdersKey = GlobalKey<UncleOrdersSectionState>();
  final guards = List.generate(5, (_) => TabSaveGuard());
  final detailOpen = List.filled(5, false);
  late final observers = List.generate(
    5,
    (index) => _TabRouteObserver((open) {
      void update() {
        if (mounted && detailOpen[index] != open) {
          setState(() => detailOpen[index] = open);
        }
      }

      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) => update());
      } else {
        // 전환 완료 콜백은 마지막 프레임 이후에도 올 수 있으므로 바로 갱신한다.
        update();
      }
    }),
  );

  Future<bool> selectTab(int index) async {
    if (index < 0 || index >= navigators.length || changingTab) return false;
    if (index == selected) return true;
    changingTab = true;
    try {
      await guards[selected].save?.call();
      if (!mounted) return false;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => selected = index);
      return true;
    } catch (_) {
      // Both UIKit and TDS keep the active tab if the draft cannot be saved.
      return false;
    } finally {
      changingTab = false;
    }
  }

  Future<void> openHomeOrders() async {
    if (!await selectTab(AppTab.home.index) || !mounted) return;
    uncleOrdersKey.currentState?.showFilter(UncleOrderFilter.all);
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
        order = a.role!.tabOrder;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // iOS의 떠 있는 탭만 낮추고 Android 시스템 탐색 영역은 확보한다.
    final tabBottom =
        TdsTheme.of(context).platform.os == TdsOS.ios && bottomInset > 24
        ? bottomInset - 24
        : bottomInset;
    final requests = app.workspace
        .records('requests')
        .map((r) => RequestRecord(r.id, r.data));
    final unread = app.workspace
        .records('messages')
        .where((m) => m.s('recipientId') == a.id && !m.b('read'))
        .length;
    final attentionCount = requests
        .where(
          (r) => a.role == AppRole.retailer
              ? (r.needsReply ||
                    r.delivered > r.received ||
                    r.n('openIssues') > 0)
              : r.s('status') == 'pending' || r.overdue,
        )
        .length;
    final businessCount = a.role == AppRole.uncle
        ? app.workspace
              .records('deliveries')
              .where((d) => d.n('received') < d.n('quantity'))
              .length
        : 0;
    final badges = [
      businessCount,
      unread,
      attentionCount,
      app.workspace
          .records('connections')
          .where((c) => c.s('status') == 'pending' && c.s('to') == a.id)
          .length,
      0,
    ];
    return TdsToastProvider(
      child: TdsDialogProvider(
        child: PopScope(
          canPop: !detailOpen[selected],
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || handlingSystemBack) return;
            final navigator = navigators[selected].currentState;
            if (navigator == null) return;
            handlingSystemBack = true;
            unawaited(
              navigator.maybePop().whenComplete(() {
                handlingSystemBack = false;
              }),
            );
          },
          child: HomeBackdrop(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (app.session.syncError != null)
                    Semantics(
                      liveRegion: true,
                      child: FigmaSurface(
                        tinted: true,
                        children: [
                          TdsListRow(
                            contents: TdsText(
                              app.session.syncError!,
                              typography: TdsTypography.t5,
                              fontWeight: TdsFontWeight.semibold,
                            ),
                            left: const ExcludeSemantics(
                              child: FigmaIcon('refresh', selected: true),
                            ),
                            onPressed: () async {
                              try {
                                await app.session.retrySync();
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // 비활성 탭의 알림이 앱의 뒤로가기 상태를 바꾸지 않게
                          // 선택된 탭의 상태만 위 PopScope에서 전달한다.
                          child: NotificationListener<NavigationNotification>(
                            onNotification: (_) => true,
                            child: IndexedStack(
                              index: selected,
                              children: [
                                for (var i = 0; i < order.length; i++)
                                  TickerMode(
                                    enabled: selected == i,
                                    child: TabSaveScope(
                                      guard: guards[i],
                                      child: Navigator(
                                        key: navigators[i],
                                        observers: [observers[i]],
                                        onGenerateRoute: (settings) =>
                                            appPageRoute<void>(
                                              settings: settings,
                                              builder: (context) => HomeTabPage(
                                                index: i,
                                                onTab: selectTab,
                                                onOpenOrders: openHomeOrders,
                                                uncleOrdersKey: uncleOrdersKey,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: tabBottom,
                          // Keep the native selection lens alive on detail pages.
                          // Hidden controls cannot paint, receive focus or taps,
                          // appear in semantics, or keep fallback tickers active.
                          child: Visibility(
                            visible: !detailOpen[selected],
                            maintainState: true,
                            child: TdsFontScaleLimit(
                              limit: MediaQuery.sizeOf(context).width < 360
                                  ? 100
                                  : 110,
                              child: TdsLiquidTabBar(
                                selectedIndex: order.indexOf(
                                  AppTab.values[selected],
                                ),
                                onSelected: (index) =>
                                    selectTab(order[index].index),
                                fontAsset: 'assets/fonts/Paperlogy-5Medium.ttf',
                                items: [
                                  for (final tab in order)
                                    TdsLiquidTab(
                                      label: a.role!.tabLabel(tab),
                                      symbol: const [
                                        'bag',
                                        'bubble.left.and.bubble.right',
                                        'house',
                                        'storefront',
                                        'person.crop.circle',
                                      ][tab.index],
                                      icon: FigmaIcon(
                                        const [
                                          'bag',
                                          'chat',
                                          'home',
                                          'store',
                                          'person',
                                        ][tab.index],
                                        selected: selected == tab.index,
                                      ),
                                      badge: badges[tab.index],
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
      ),
    );
  }
}

class HomeTabPage extends StatelessWidget {
  const HomeTabPage({
    required this.index,
    required this.onTab,
    required this.onOpenOrders,
    required this.uncleOrdersKey,
    super.key,
  });
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onOpenOrders;
  final GlobalKey<UncleOrdersSectionState> uncleOrdersKey;
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), a = app.session.current!;
    final isHome = index == AppTab.home.index;
    final homeName = a.role == AppRole.uncle && !a.name.trim().endsWith('삼촌')
        ? '${a.name.trim()} 삼촌'
        : a.name;
    final notices = app.workspace
        .records('notices')
        .where(
          (n) =>
              !n.b('read') &&
              mapOf(a.data, 'notificationSettings')[n.s('kind')] != false,
        )
        .length;
    final page = switch (index) {
      0 =>
        a.role == AppRole.retailer
            ? const RetailerPurchaseTab()
            : BusinessList(onOpenOrders: onOpenOrders),
      1 => const ChatList(),
      2 => BackdropGroup(
        child: Dashboard(onTab: onTab, uncleOrdersKey: uncleOrdersKey),
      ),
      3 => const ConnectionsList(),
      _ => const MyPage(),
    };
    return PageFrame(
      title: isHome ? homeName : a.role!.tabLabel(AppTab.values[index]),
      back: false,
      showHeaderDivider: false,
      navigationLeading: isHome ? const AppLogo(width: 40) : null,
      navigationSubtitle: isHome ? a.role!.label : null,
      trailing: isHome
          ? TdsGlassIconButton(
              semanticLabel: '알림',
              symbol: 'bell',
              icon: const FigmaIcon('bell'),
              unreadCount: notices,
              onPressed: () => openPage(context, const NoticesPage()),
            )
          : null,
      scrollKey: '${a.id}-tab-$index',
      children: [if (isHome) const TdsSpacing(8), page, const TdsSpacing(88)],
    );
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({required this.onTab, this.uncleOrdersKey, super.key});
  final ValueChanged<int> onTab;
  final GlobalKey<UncleOrdersSectionState>? uncleOrdersKey;

  @override
  Widget build(BuildContext context) =>
      AppScope.of(context).session.current!.role == AppRole.retailer
      ? RetailerDashboard(onTab: onTab)
      : UncleDashboard(onTab: onTab, ordersKey: uncleOrdersKey);
}

class BusinessList extends StatelessWidget {
  const BusinessList({required this.onOpenOrders, super.key});
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) =>
      UncleWorkTab(onOpenOrders: onOpenOrders);
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
    if (routes.length <= 1 && route is TransitionRoute<dynamic>) {
      // 스와이프가 끝나기 전에 탭이 상세 화면 위로 나타나지 않게 한다.
      // 진행 중 새 화면이 열렸다면 완료 시점의 스택을 다시 확인한다.
      unawaited(route.completed.then((_) => changed(routes.length > 1)));
    } else {
      changed(routes.length > 1);
    }
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
