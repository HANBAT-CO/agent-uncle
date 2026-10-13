import 'package:flutter/services.dart';

import 'address_models.dart';
import 'address_search_stub.dart';

const _channel = MethodChannel('agent_uncle/address_search');

AddressSearchGateway createAddressSearchGateway() =>
    const _ChannelAddressSearchGateway();

class _ChannelAddressSearchGateway extends AddressSearchGateway {
  const _ChannelAddressSearchGateway();

  @override
  Future<AddressSearchResult?> search() async {
    try {
      final payload = await _channel.invokeMethod<Object?>(
        'searchKakaoPostcode',
      );
      if (payload == null) return null;
      if (payload is! Map) {
        throw const AddressSearchFailure('주소 검색 결과를 다시 확인해 주세요.');
      }
      return AddressSearchResult.fromMap(payload);
    } on MissingPluginException {
      throw const AddressSearchFailure('주소 검색 기능이 포함된 최신 앱으로 다시 실행해 주세요.');
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return null;
      throw AddressSearchFailure(
        (error.message ?? '주소 검색을 열지 못했어요. 다시 시도해 주세요.').trim(),
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancelSearch');
    } on MissingPluginException {
      // 주소 검색을 열지 못한 환경에서는 닫을 네이티브 화면도 없다.
    }
  }
}
