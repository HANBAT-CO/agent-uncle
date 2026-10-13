import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repositories_test.dart' show Harness, reply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = [
    (
      name: '누락된 RPC의 서버 준비 오류를 보존한다',
      body: '{"code":"PGRST202","message":"Function not found"}',
      status: 404,
      message: '서버 준비가 아직 완료되지 않았어요. 잠시 후 다시 시도해 주세요.',
    ),
    (
      name: '서버 장애를 인터넷 연결 문제로 표시하지 않는다',
      body: '{"code":"XX000","message":"Internal server error"}',
      status: 500,
      message: '연락처 중복 여부를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
    ),
    (
      name: '서버의 연락처 형식 안내를 보존한다',
      body: '{"code":"P0001","message":"연락처를 확인해 주세요."}',
      status: 400,
      message: '연락처를 확인해 주세요.',
    ),
    (
      name: '잘못된 성공 응답을 중복 번호로 판단하지 않는다',
      body: 'null',
      status: 200,
      message: '연락처 확인 응답을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
    ),
  ];

  for (final scenario in cases) {
    test(scenario.name, () async {
      final h = Harness();
      await h.open();
      addTearDown(h.close);
      h.phoneResponse = reply(scenario.body, scenario.status);
      await expectLater(
        h.session.checkPhoneAvailable('01012345678'),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.message,
            'message',
            scenario.message,
          ),
        ),
      );
      h.phoneResponse = null;
      expect(await h.session.checkPhoneAvailable('01012345678'), isTrue);
    });
  }
}
