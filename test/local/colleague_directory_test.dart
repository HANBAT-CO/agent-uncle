import 'package:flutter_test/flutter_test.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'workspace_test.dart' show Fixture;

void main() {
  test('동료 검색은 이름·코드와 공개 소속만 제공하고 접근 권한을 늘리지 않는다', () async {
    final f = Fixture();
    await f.start();
    addTearDown(f.close);
    final colleague = await f.account('동료 검색용 삼촌', AppRole.uncle);
    await f.store.write(colleague, '', (s) {
      s.put('accounts', colleague, {
        ...s.require('accounts', colleague),
        'nickname': '서부 동료',
        'contact': '010-9999-9999',
        'bankAccount': '비공개',
      });
      s.put('teams', 'private-team', {
        'name': '서부팀',
        'status': 'active',
        'memberIds': [colleague],
        'readers': [colleague],
        'bankAccount': '비공개',
      });
      return '';
    });
    await f.session.signIn(f.uncle);
    final result = await f.workspace.searchColleagues(query: '서부 동료');
    expect(result.single.id, colleague);
    expect(result.single.data.containsKey('contact'), false);
    expect(result.single.data.containsKey('bankAccount'), false);
    expect(result.single.data['teamMemberships'], [
      {'id': 'private-team', 'name': '서부팀'},
    ]);
    expect(f.workspace.records('teams'), isEmpty);
    await f.store.write(f.uncle, '', (s) {
      s.put('colleagueConnections', 'public-colleague', {
        'fromId': f.uncle,
        'toId': colleague,
        'status': 'accepted',
        'readers': [f.uncle, colleague],
      });
      return '';
    });
    final connectedProfile = f.workspace.profile(colleague)!;
    expect(
      connectedProfile.data['teamMemberships'],
      result.single.data['teamMemberships'],
    );
    expect(connectedProfile.data.containsKey('phone'), false);
    expect(connectedProfile.data.containsKey('bankAccount'), false);
    expect(f.workspace.records('teams'), isEmpty);
    final byCode = await f.workspace.searchColleagues(
      query: result.single.publicCode,
    );
    expect(byCode.single.id, colleague);
    expect(
      await f.workspace.searchColleagues(query: '서부 동료', offset: 1),
      isEmpty,
    );
    await expectLater(
      f.workspace.searchColleagues(query: ''),
      throwsA(isA<AppFailure>()),
    );
    await f.session.signIn(f.retailer);
    await expectLater(
      f.workspace.searchColleagues(query: '서부 동료'),
      throwsA(isA<AppFailure>()),
    );
  });
}
