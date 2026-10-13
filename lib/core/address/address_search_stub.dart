import 'address_models.dart';

abstract class AddressSearchGateway {
  const AddressSearchGateway();

  bool get requiresUserGesture => false;

  Future<void> prepare() async {}

  Future<AddressSearchResult?> search();

  Future<void> cancel() async {}
}

AddressSearchGateway createAddressSearchGateway() =>
    const _UnsupportedAddressSearchGateway();

class _UnsupportedAddressSearchGateway extends AddressSearchGateway {
  const _UnsupportedAddressSearchGateway();

  @override
  Future<AddressSearchResult?> search() async {
    throw const AddressSearchFailure(
      '현재 환경에서는 공식 주소 검색을 열 수 없어요. 모바일 앱 빌드에서 다시 시도해 주세요.',
    );
  }
}
