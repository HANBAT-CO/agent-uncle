import 'package:agent_uncle/local/domain/models.dart';

import '../local/workspace_test.dart' show Fixture;

Future<String> createRetailerRequest(
  Fixture fixture, {
  required String product,
  int quantity = 3,
}) async {
  await fixture.session.signIn(fixture.retailer);
  final id = newId();
  await fixture.workspace.saveDraft(id, {
    'uncleId': fixture.uncle,
    'wholesaler': '동대문 도매상',
    'location': 'A동 2층',
    'product': product,
    'option': '기본',
    'quantity': quantity,
    'address': '서울시 중구',
    'addressDetail': '101호',
  });
  await fixture.workspace.sendDraft(id, 'send-$id');
  return id;
}

Future<void> acceptRequest(Fixture fixture, String requestId) =>
    fixture.accept(requestId);

Future<void> shareResult(
  Fixture fixture,
  String requestId, {
  required int acquired,
  required int backorder,
  bool needsReply = true,
}) async {
  await fixture.session.signIn(fixture.uncle);
  await fixture.workspace.act(
    requestId,
    'result',
    {
      'acquired': acquired,
      'backorder': backorder,
      'recheck': backorder > 0
          ? dateOnly(DateTime.now().add(const Duration(days: 1)))
          : '',
      'reason': backorder > 0 ? '미송 확인' : '',
      'needsReply': needsReply,
    },
    fixture.workspace.request(requestId)!.version,
    newId(),
  );
}

Future<String> deliverRequest(
  Fixture fixture,
  String requestId,
  int quantity,
) async {
  await fixture.session.signIn(fixture.uncle);
  await fixture.workspace.deliver(
    {requestId: quantity},
    {requestId: fixture.workspace.request(requestId)!.version},
    newId(),
  );
  final deliveries =
      fixture.workspace
          .records('deliveries')
          .where((delivery) => delivery.s('requestId') == requestId)
          .toList()
        ..sort((a, b) => a.s('createdAt').compareTo(b.s('createdAt')));
  return deliveries.last.id;
}

Future<void> receiveDelivery(
  Fixture fixture,
  String deliveryId,
  int quantity,
) => fixture.receive(deliveryId, quantity);
