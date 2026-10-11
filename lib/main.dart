import 'core/theme/app_theme.dart';
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
  const LocalBootstrap({super.key});
  @override
  State<LocalBootstrap> createState() => _LocalBootstrapState();
}

class _LocalBootstrapState extends State<LocalBootstrap> {
  late Future<AppServices> startup = _open();
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
      if (snapshot.hasData) return AgentUncleApp(services: snapshot.data!);
      return WidgetsApp(
        color: AppColors.background,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => StableViewport(
          child: TdsMobileAITProvider(child: AppTheme(child: child!)),
        ),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          pageBuilder: (context, a, b) => builder(context),
        ),
        home: ColoredBox(
          color: AppColors.background,
          child: Center(
            child: snapshot.hasError
                ? TdsResult(
                    title: const Text('앱을 시작하지 못했어요'),
                    description: const Text(
                      '인터넷 연결과 기기 저장 공간을 확인한 뒤 다시 시도해 주세요.',
                    ),
                    button: TdsResultButton(
                      onPressed: () => setState(() => startup = _open()),
                      child: const Text('다시 시도'),
                    ),
                  )
                : const TdsLoader(),
          ),
        ),
      );
    },
  );
}
