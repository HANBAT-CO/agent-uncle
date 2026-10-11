import 'package:agent_uncle/app.dart';
import 'package:agent_uncle/core/theme/app_theme.dart';
import 'package:agent_uncle/local/app_services.dart';
import 'package:agent_uncle/local/data/local_attachments.dart';
import 'package:agent_uncle/local/data/local_session.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/data/local_workspace.dart';
import 'package:agent_uncle/local/presentation/entry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../local/app_flow_test.dart' show drainClose;

class SocialTestSession extends LocalSessionRepository {
  SocialTestSession(super.store);
  final providers = <String>[];
  @override
  bool get isRemote => true;
  @override
  bool get onboardingSeen => true;
  @override
  Future<void> signInWithSocial(String provider) async {
    providers.add(provider);
  }
}

void main() {
  testWidgets('real-mode entry uses Paperlogy and both social providers', (
    tester,
  ) async {
    final store = LocalStore(
      await databaseFactoryMemory.openDatabase('social-ui'),
    );
    final session = SocialTestSession(store);
    final workspace = LocalWorkspaceRepository(store, session);
    final services = AppServices(
      session: session,
      workspace: workspace,
      attachments: LocalAttachmentRepository(store, session, workspace),
    );

    await tester.pumpWidget(AgentUncleApp(services: services));
    expect(find.byType(SocialLoginPage), findsOneWidget);
    expect(find.text('로컬 계정 만들기'), findsNothing);
    for (final entry in {'Google로 로그인': 'google', '카카오 로그인': 'kakao'}.entries) {
      final button = find.bySemanticsLabel(entry.key);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(session.providers.last, entry.value);
      final context = tester.element(button);
      expect(TdsTheme.of(context).textStyle().fontFamily, 'Paperlogy');
      expect(DefaultTextStyle.of(context).style.fontFamily, 'Paperlogy');
    }
    expect(
      const PaperlogyTheme()
          .copyWith(colorScheme: TdsColorPreference.dark)
          .textStyle()
          .fontFamily,
      'Paperlogy',
    );
    await tester.pumpWidget(const SizedBox());
    services.dispose();
    await drainClose(tester, store.close());
  });
}
