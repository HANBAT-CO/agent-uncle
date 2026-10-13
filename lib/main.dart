import 'dart:async';

import 'core/theme/app_theme.dart';
import 'core/presentation/app_splash.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'app.dart';
import 'local/app_services.dart';
import 'local/data/open_database.dart';
import 'core/config/supabase_config.dart';
import 'remote/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocalBootstrap());
}

class LocalBootstrap extends StatefulWidget {
  const LocalBootstrap({this.initialize, super.key});
  final Future<AppServices> Function()? initialize;
  @override
  State<LocalBootstrap> createState() => _LocalBootstrapState();
}

class _LocalBootstrapState extends State<LocalBootstrap> {
  /// 로고와 문구가 읽히도록 스플래시를 최소 1초 보여 준다. 최소 시간은 여기서만
  /// 재고, 이후 계정 확인 스플래시(AccountLanding)는 실제 로딩 시간만큼만 이어져
  /// 두 단계가 각각 1초씩 기다리지 않는다.
  static const minimumSplash = Duration(seconds: 1);
  late Future<AppServices> startup;
  Timer? _minimumHold;
  bool _holding = true;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  void _begin() {
    _holding = true;
    _minimumHold?.cancel();
    _minimumHold = Timer(minimumSplash, () {
      if (!mounted) return;
      setState(() => _holding = false);
    });
    startup = (widget.initialize ?? _open)();
  }

  @override
  void dispose() {
    _minimumHold?.cancel();
    super.dispose();
  }

  Future<AppServices> _open() async {
    final database = await openLocalDatabase();
    if (const bool.fromEnvironment('LOCAL_MODE')) {
      return AppServices.local(database);
    }
    if (!_supabaseReady) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _supabaseReady = true;
    }
    return openRemoteServices(Supabase.instance.client, database);
  }

  static bool _supabaseReady = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
    future: startup,
    builder: (context, snapshot) {
      if (!_holding && snapshot.hasData) {
        return AgentUncleApp(services: snapshot.data!);
      }
      return WidgetsApp(
        color: TdsPalette.white,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => StableViewport(
          child: TdsMobileAITProvider(child: AppTheme(child: child!)),
        ),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          pageBuilder: (context, a, b) => builder(context),
        ),
        home:
            !_holding &&
                snapshot.connectionState == ConnectionState.done &&
                snapshot.hasError
            ? ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: TdsResult(
                    title: const Text('앱을 시작하지 못했어요'),
                    description: const Text(
                      '인터넷 연결과 기기 저장 공간을 확인한 뒤 다시 시도해 주세요.',
                    ),
                    button: TdsResultButton(
                      onPressed: () => setState(_begin),
                      child: const Text('다시 시도'),
                    ),
                  ),
                ),
              )
            : const AppSplashScreen(),
      );
    },
  );
}
