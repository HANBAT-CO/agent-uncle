import 'core/theme/app_theme.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/google_auth_app.dart';
import 'local/app_services.dart';
import 'local/presentation/entry.dart';

class AgentUncleApp extends StatelessWidget {
  const AgentUncleApp({this.services, this.authRepository, super.key})
    : assert(services != null || authRepository != null);
  final AppServices? services;
  // Legacy authentication harness remains injectable for isolated auth tests.
  final AuthRepository? authRepository;
  @override
  Widget build(BuildContext context) {
    if (services == null) return GoogleAuthApp(authRepository: authRepository!);
    return AppScope(
      services: services!,
      child: WidgetsApp(
        debugShowCheckedModeBanner: false,
        title: '사입삼춘',
        color: AppColors.background,
        builder: (context, child) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: StableViewport(
              child: TdsMobileAITProvider(child: AppTheme(child: child!)),
            ),
          ),
        ),
        home: const SessionGate(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, a, b) => builder(context),
        ),
      ),
    );
  }
}

/// Android can briefly report a zero-size surface when starting or opening a
/// native picker. Keep the last valid layout and its navigation/form state.
class StableViewport extends StatefulWidget {
  const StableViewport({required this.child, super.key});
  final Widget child;
  @override
  State<StableViewport> createState() => _StableViewportState();
}

class _StableViewportState extends State<StableViewport> {
  Size? lastSize;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 0 &&
          constraints.maxHeight > 0 &&
          constraints.hasBoundedWidth &&
          constraints.hasBoundedHeight) {
        lastSize = constraints.biggest;
      }
      final size = lastSize;
      if (size == null) return const SizedBox.shrink();
      return OverflowBox(
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: widget.child,
        ),
      );
    },
  );
}
