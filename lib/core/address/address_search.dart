import 'address_models.dart';
import 'address_search_stub.dart' show AddressSearchGateway;
import 'address_search_stub.dart'
    if (dart.library.io) 'address_search_io.dart'
    if (dart.library.js_interop) 'address_search_web.dart'
    as impl;

export 'address_models.dart';
export 'address_search_stub.dart' show AddressSearchGateway;

class AddressSearch {
  AddressSearch._();

  static AddressSearchGateway? _override;
  static AddressSearchGateway? _instance;

  static AddressSearchGateway get instance =>
      _override ?? (_instance ??= impl.createAddressSearchGateway());

  static void debugOverride(AddressSearchGateway? gateway) {
    _override = gateway;
  }
}

Future<AddressSearchResult?> searchAddress() => AddressSearch.instance.search();
