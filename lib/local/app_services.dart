import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';
import 'data/local_attachments.dart';
import 'data/local_session.dart';
import 'data/local_store.dart';
import 'data/local_workspace.dart';
import 'domain/models.dart';
import '../remote/push_notifications.dart';

class AppServices extends ChangeNotifier {
  AppServices({
    required this.session,
    required this.workspace,
    required this.attachments,
    this.push,
  }) {
    session.addListener(notifyListeners);
    workspace.addListener(notifyListeners);
    push?.addListener(notifyListeners);
    push?.start();
  }
  final SessionRepository session;
  final WorkspaceRepository workspace;
  final AttachmentRepository attachments;
  final PushNotifications? push;
  static Future<AppServices> local(Database database) async {
    final store = LocalStore(database);
    await store.initialize();
    final session = LocalSessionRepository(store);
    final workspace = LocalWorkspaceRepository(store, session);
    return AppServices(
      session: session,
      workspace: workspace,
      attachments: LocalAttachmentRepository(store, session, workspace),
    );
  }

  @override
  void dispose() {
    push?.removeListener(notifyListeners);
    push?.dispose();
    session.removeListener(notifyListeners);
    workspace.removeListener(notifyListeners);
    session.dispose();
    workspace.dispose();
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
