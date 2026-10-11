import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/app_services.dart';
import 'remote_attachments.dart';
import 'remote_session.dart';
import 'remote_store.dart';
import 'remote_workspace.dart';

Future<AppServices> openRemoteServices(
  SupabaseClient client,
  Database device,
) async {
  final store = RemoteStore(client, device);
  await store.initialize();
  final session = RemoteSessionRepository(store);
  final workspace = RemoteWorkspaceRepository(store);
  await session.initialize();
  return AppServices(
    session: session,
    workspace: workspace,
    attachments: RemoteAttachmentRepository(store),
  );
}
