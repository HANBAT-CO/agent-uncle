import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/config/supabase_config.dart';
import 'package:agent_uncle/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    AgentUncleApp(
      authRepository: SupabaseAuthRepository(Supabase.instance.client),
    ),
  );
}
