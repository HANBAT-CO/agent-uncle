import 'dart:async';

import 'package:agent_uncle/core/address/address_search.dart';
import 'package:agent_uncle/local/presentation/address_search.dart';
import 'package:agent_uncle/local/presentation/common.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import 'brand_surfaces_test.dart' show branded;

const _address = AddressSearchResult(
  postcode: '04564',
  roadAddress: '서울 중구 을지로 281',
  jibunAddress: '서울 중구 을지로7가 2-1',
  buildingName: '동대문디자인플라자',
  source: 'kakao_postcode',
);

class _PendingSearch extends AddressSearchGateway {
  final requests = <Completer<AddressSearchResult?>>[];
  var cancellations = 0;

  @override
  Future<AddressSearchResult?> search() {
    final request = Completer<AddressSearchResult?>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> cancel() async => cancellations++;
}

class _GestureSearch extends _PendingSearch {
  final preparations = <Completer<void>>[];

  @override
  bool get requiresUserGesture => true;

  @override
  Future<void> prepare() {
    final preparation = Completer<void>();
    preparations.add(preparation);
    return preparation.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('agent_uncle/address_search');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    AddressSearch.debugOverride(null);
  });

  test('공식 주소 검색 결과를 우편번호와 도로명·지번 정보로 전달한다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'searchKakaoPostcode');
      return _address.toMap();
    });
    final result = await searchAddress();
    expect(result!.toMap(), _address.toMap());
    expect(result.displayAddress, _address.roadAddress);
    expect(
      AddressSearchResult.fromMap({
        ..._address.toMap(),
        'roadAddress': '',
      }).displayAddress,
      _address.jibunAddress,
    );
  });

  test('취소 결과는 오류 대신 null을 반환하고 네이티브 취소도 전달한다', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    expect(await searchAddress(), isNull);
    await AddressSearch.instance.cancel();
    expect(calls, ['searchKakaoPostcode', 'cancelSearch']);

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'cancelled');
    });
    expect(await searchAddress(), isNull);
  });

  test('불완전하거나 형식이 다른 검색 결과는 저장하지 않는다', () async {
    for (final payload in <Object>[
      '잘못된 결과',
      {..._address.toMap(), 'postcode': '123'},
      {..._address.toMap(), 'postcode': 4564},
      {..._address.toMap(), 'roadAddress': '', 'jibunAddress': ''},
      {..._address.toMap(), 'source': 'manual'},
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => payload);
      await expectLater(searchAddress(), throwsA(isA<AddressSearchFailure>()));
    }
  });

  test('플러그인이 없는 빌드와 네트워크 오류를 사용자에게 설명한다', () async {
    await expectLater(
      searchAddress(),
      throwsA(
        isA<AddressSearchFailure>().having(
          (error) => error.message,
          'message',
          contains('최신 앱'),
        ),
      ),
    );
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'network', message: '연결을 확인해 주세요.');
    });
    await expectLater(
      searchAddress(),
      throwsA(
        isA<AddressSearchFailure>().having(
          (error) => error.message,
          'message',
          '연결을 확인해 주세요.',
        ),
      ),
    );
  });

  Future<void> openSearch(
    WidgetTester tester,
    AddressSearchGateway gateway,
    void Function(AddressSearchResult?) onResult,
  ) async {
    await tester.pumpWidget(
      branded(
        Builder(
          builder: (context) => PageFrame(
            title: '배송 정보',
            back: false,
            children: [
              TdsButton(
                onPressed: () async {
                  onResult(
                    await openPage<AddressSearchResult>(
                      context,
                      AddressSearchPage(gateway: gateway),
                    ),
                  );
                },
                child: const Text('주소 고르기'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('주소 고르기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('주소 검색 실패 후 재시도한 결과만 부모 화면으로 반환한다', (tester) async {
    final gateway = _PendingSearch();
    final results = <AddressSearchResult?>[];
    await openSearch(tester, gateway, results.add);
    expect(gateway.requests, hasLength(1));
    gateway.requests.single.completeError(
      const AddressSearchFailure('인터넷 연결을 확인해 주세요.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('인터넷 연결을 확인해 주세요.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TdsButton, '다시 시도'));
    await tester.pump();
    expect(gateway.requests, hasLength(2));
    gateway.requests.last.complete(_address);
    await tester.pumpAndSettle();
    expect(results, [_address]);
    expect(find.byType(AddressSearchPage), findsNothing);
    expect(find.text('배송 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색 취소 뒤 도착한 결과는 이전 화면을 닫지 않는다', (tester) async {
    final gateway = _PendingSearch();
    final results = <AddressSearchResult?>[];
    await openSearch(tester, gateway, results.add);
    await tester.tap(find.widgetWithText(TdsButton, '취소'));
    await tester.pumpAndSettle();
    expect(gateway.cancellations, 1);
    expect(results, [null]);
    gateway.requests.single.complete(_address);
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(find.text('배송 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('화면이 먼저 제거되면 네이티브 검색을 취소하고 지연 결과를 무시한다', (tester) async {
    final gateway = _PendingSearch();
    await openSearch(tester, gateway, (_) {});
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(gateway.cancellations, 1);
    gateway.requests.single.complete(_address);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('웹 주소 검색은 준비를 마쳐도 버튼을 눌러야 열리고 실패 시 재시도한다', (tester) async {
    final gateway = _GestureSearch();
    final results = <AddressSearchResult?>[];
    await openSearch(tester, gateway, results.add);
    expect(gateway.preparations, hasLength(1));
    expect(gateway.requests, isEmpty);

    gateway.preparations.single.completeError(
      const AddressSearchFailure('주소 검색 스크립트를 불러오지 못했어요.'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TdsButton, '다시 시도'));
    await tester.pump();
    expect(gateway.preparations, hasLength(2));
    expect(gateway.requests, isEmpty);

    gateway.preparations.last.complete();
    await tester.pumpAndSettle();
    expect(gateway.requests, isEmpty);
    await tester.tap(find.widgetWithText(TdsButton, '주소 검색 열기'));
    await tester.pump();
    expect(gateway.requests, hasLength(1));
    gateway.requests.single.complete(_address);
    await tester.pumpAndSettle();
    expect(results, [_address]);
    expect(find.text('배송 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('웹 주소 검색을 준비하다 취소하면 늦은 준비 완료가 화면을 다시 열지 않는다', (tester) async {
    final gateway = _GestureSearch();
    final results = <AddressSearchResult?>[];
    await openSearch(tester, gateway, results.add);
    await tester.tap(find.widgetWithText(TdsButton, '취소'));
    await tester.pumpAndSettle();
    gateway.preparations.single.complete();
    await tester.pumpAndSettle();
    expect(results, [null]);
    expect(gateway.cancellations, 1);
    expect(gateway.requests, isEmpty);
    expect(find.text('배송 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
