class AddressSearchResult {
  const AddressSearchResult({
    required this.postcode,
    required this.roadAddress,
    required this.jibunAddress,
    required this.source,
    this.buildingName = '',
  });

  final String postcode;
  final String roadAddress;
  final String jibunAddress;
  final String source;
  final String buildingName;

  String get displayAddress {
    final road = roadAddress.trim();
    if (road.isNotEmpty) return road;
    return jibunAddress.trim();
  }

  Map<String, Object?> toMap() => {
    'postcode': postcode,
    'roadAddress': roadAddress,
    'jibunAddress': jibunAddress,
    'source': source,
    'buildingName': buildingName,
  };

  factory AddressSearchResult.fromMap(Map<dynamic, dynamic> value) {
    String text(String key) {
      final field = value[key];
      if (field == null) return '';
      if (field is! String) {
        throw const AddressSearchFailure('주소 검색 결과를 다시 확인해 주세요.');
      }
      return field.trim();
    }

    final result = AddressSearchResult(
      postcode: text('postcode'),
      roadAddress: text('roadAddress'),
      jibunAddress: text('jibunAddress'),
      source: text('source'),
      buildingName: text('buildingName'),
    );
    if (!RegExp(r'^\d{5}$').hasMatch(result.postcode) ||
        result.displayAddress.isEmpty ||
        result.source != 'kakao_postcode') {
      throw const AddressSearchFailure('주소 검색 결과를 다시 확인해 주세요.');
    }
    return result;
  }
}

class AddressSearchFailure implements Exception {
  const AddressSearchFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
