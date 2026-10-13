import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';
import 'data/local_attachments.dart';
import 'data/local_session.dart';
import 'data/local_store.dart';
import 'data/local_workspace.dart';
import 'domain/models.dart';
import '../remote/remote_config.dart';

class AppServices extends ChangeNotifier {
  AppServices({
    required this.session,
    required this.workspace,
    required this.attachments,
    RemoteConfigRepository? config,
  }) : config = config ?? NoopRemoteConfigStore() {
    session.addListener(notifyListeners);
    workspace.addListener(notifyListeners);
    this.config.addListener(notifyListeners);
  }
  final SessionRepository session;
  final WorkspaceRepository workspace;
  final AttachmentRepository attachments;
  final RemoteConfigRepository config;
  static Future<AppServices> local(Database database) async {
    final store = LocalStore(database);
    await store.initialize();
    final session = LocalSessionRepository(store);
    final workspace = LocalWorkspaceRepository(store, session);
    return AppServices(
      session: session,
      workspace: workspace,
      attachments: LocalAttachmentRepository(store, session, workspace),
      config: NoopRemoteConfigStore(),
    );
  }

  @override
  void dispose() {
    session.removeListener(notifyListeners);
    workspace.removeListener(notifyListeners);
    config.removeListener(notifyListeners);
    session.dispose();
    workspace.dispose();
    config.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppServices> {
  const AppScope({
    required AppServices services,
    required super.child,
    super.key,
  }) : super(notifier: services);
  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppServices read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
