import 'package:agent_uncle/local/data/convenience_commands.dart';
import 'package:agent_uncle/local/data/local_store.dart';
import 'package:agent_uncle/local/domain/convenience_models.dart';
import 'package:agent_uncle/local/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Map<String, Data>> _tables() => {
  for (final name in collections) name: <String, Data>{},
};

class _Fixture {
  _Fixture() : state = MutableWorkspace(_tables()) {
    _putAccount('retailer', AppRole.retailer);
    _putAccount('uncle', AppRole.uncle);
  }

  final MutableWorkspace state;

  void _putAccount(String id, AppRole role) {
    state.put('accounts', id, {
      'name': id,
      'nickname': id,
      'role': role.name,
      'complete': true,
      'version': 0,
    });
  }

  String run(String actor, String command, Data args) =>
      applyConvenience(state, actor, command, args);

  Data row(String table, String id) => state.tables[table]![id]!;
}

void main() {
  test('즐겨찾기 저장은 legacy 결제 모드를 canonical 로 정규화한다', () {
    final fixture = _Fixture();

    final favoriteId = fixture.run('retailer', 'upsertFavoriteWholesaler', {
      'favoriteId': 'favorite-a',
      'wholesaler': '남평화 1층',
      'location': 'A열',
      'paymentMode': 'direct_paid',
    });

    expect(favoriteId, 'favorite-a');
    expect(
      fixture.row('favoriteWholesalers', favoriteId)['paymentMode'],
      conveniencePaymentModeDirect,
    );
    expect(
      fixture.row('favoriteWholesalers', favoriteId)['ownerId'],
      'retailer',
    );
  });

  test('같은 도매처를 다시 저장하면 기존 즐겨찾기를 재사용한다', () {
    final fixture = _Fixture();

    final first = fixture
        .run('retailer', 'convenience.upsertFavoriteWholesaler', {
          'favoriteId': 'favorite-a',
          'wholesaler': '동평화',
          'location': 'B열',
          'paymentMode': 'advance',
        });
    final second = fixture.run('retailer', 'upsertFavoriteWholesaler', {
      'wholesaler': '동평화',
      'location': 'B열',
      'paymentMode': 'needs_check',
    });

    expect(second, first);
    expect(fixture.state.tables['favoriteWholesalers']!.length, 1);
    expect(
      fixture.row('favoriteWholesalers', first)['paymentMode'],
      conveniencePaymentModeReview,
    );
  });

  test('재사용 도매처는 민감 필드를 지우고 항상 review 로 되돌린다', () {
    final sanitized = sanitizeReusableWholesaler({
      'wholesaler': '디자이너클럽',
      'location': '3층',
      'paymentMode': 'direct',
      'invoiceId': 'invoice-1',
      'fieldPaymentId': 'payment-1',
      'directPaidAmount': 10000,
    });

    expect(sanitized['paymentMode'], conveniencePaymentModeReview);
    expect(sanitized.containsKey('invoiceId'), isFalse);
    expect(sanitized.containsKey('fieldPaymentId'), isFalse);
    expect(sanitized.containsKey('directPaidAmount'), isFalse);
  });

  test('즐겨찾기 삭제는 본인 레코드만 제거한다', () {
    final fixture = _Fixture();
    final favoriteId = fixture.run('retailer', 'upsertFavoriteWholesaler', {
      'favoriteId': 'favorite-delete',
      'wholesaler': '유어스',
      'location': '5층',
      'paymentMode': 'advance_request',
    });

    final deleted = fixture.run('retailer', 'deleteFavoriteWholesaler', {
      'favoriteId': favoriteId,
    });

    expect(deleted, favoriteId);
    expect(fixture.state.tables['favoriteWholesalers']!, isEmpty);
  });
}
