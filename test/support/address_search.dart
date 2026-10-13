import 'package:agent_uncle/core/address/address_search.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class FixedAddressSearchGateway extends AddressSearchGateway {
  const FixedAddressSearchGateway(this.result);

  final AddressSearchResult? result;

  @override
  Future<AddressSearchResult?> search() async => result;
}

Future<void> selectAddress(
  WidgetTester tester, {
  String address = '서울 중구',
  String postcode = '04564',
  Key selectorKey = const ValueKey('address-selector'),
}) async {
  AddressSearch.debugOverride(
    FixedAddressSearchGateway(
      AddressSearchResult(
        postcode: postcode,
        roadAddress: address,
        jibunAddress: '',
        source: 'kakao_postcode',
      ),
    ),
  );
  try {
    final selector = find.byKey(selectorKey);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
  } finally {
    AddressSearch.debugOverride(null);
  }
}
