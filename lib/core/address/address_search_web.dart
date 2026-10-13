import 'dart:async';
import 'dart:js_interop';

import 'address_models.dart';
import 'address_search_stub.dart';

@JS('window.kakao')
external _Kakao? get _kakao;

extension type _Kakao(JSObject _) implements JSObject {
  @JS('Postcode')
  external JSFunction? get postcode;
}

@JS('document.createElement')
external _Script _createElement(String tag);

@JS('document.head')
external _Head get _head;

extension type _Head(JSObject _) implements JSObject {
  external void appendChild(_Script script);
}

extension type _Script(JSObject _) implements JSObject {
  external set src(String value);
  external set async(bool value);
  external void addEventListener(String event, JSFunction listener);
  external void removeEventListener(String event, JSFunction listener);
  external void remove();
}

@JS('window.open')
external _Popup? _openWindow(String url, String name, String features);

extension type _Popup(JSObject _) implements JSObject {
  external bool get closed;
  external void close();
}

@JS('kakao.Postcode')
extension type _Postcode._(JSObject _) implements JSObject {
  external _Postcode(_PostcodeOptions options);
  external void open(_PopupOptions options);
}

extension type _PostcodeOptions._(JSObject _) implements JSObject {
  external _PostcodeOptions({
    required JSFunction oncomplete,
    required JSFunction onclose,
  });
}

extension type _PopupOptions._(JSObject _) implements JSObject {
  external _PopupOptions({
    required String popupKey,
    required String popupTitle,
  });
}

extension type _PostcodeResult(JSObject _) implements JSObject {
  external String? get zonecode;
  external String? get roadAddress;
  external String? get jibunAddress;
  external String? get buildingName;
}

AddressSearchGateway createAddressSearchGateway() => _WebAddressSearchGateway();

class _WebAddressSearchGateway extends AddressSearchGateway {
  Future<void>? _preparing;
  Completer<AddressSearchResult?>? _pending;
  _Popup? _popup;
  Timer? _closedTimer;
  int _serial = 0;

  @override
  bool get requiresUserGesture => true;

  bool get _ready => _kakao?.postcode != null;

  @override
  Future<void> prepare() {
    if (_ready) return Future.value();
    return _preparing ??= _loadSdk().whenComplete(() => _preparing = null);
  }

  Future<void> _loadSdk() async {
    final completed = Completer<void>();
    final script = _createElement('script')
      ..src =
          'https://t1.kakaocdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js'
      ..async = true;
    final onLoad = ((JSObject _) {
      if (!completed.isCompleted) completed.complete();
    }).toJS;
    final onError = ((JSObject _) {
      if (!completed.isCompleted) {
        completed.completeError(
          const AddressSearchFailure('주소 검색을 불러오지 못했어요. 네트워크 상태를 확인해 주세요.'),
        );
      }
    }).toJS;
    script.addEventListener('load', onLoad);
    script.addEventListener('error', onError);
    try {
      _head.appendChild(script);
      await completed.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const AddressSearchFailure(
          '주소 검색 화면 응답이 지연되고 있어요. 다시 시도해 주세요.',
        ),
      );
      if (!_ready) {
        throw const AddressSearchFailure('주소 검색을 준비하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      script.removeEventListener('load', onLoad);
      script.removeEventListener('error', onError);
      script.remove();
    }
  }

  @override
  Future<AddressSearchResult?> search() {
    if (_pending != null) {
      throw const AddressSearchFailure('주소 검색이 이미 진행 중이에요.');
    }
    if (!_ready) {
      throw const AddressSearchFailure('주소 검색을 먼저 준비해 주세요.');
    }

    // 클릭 이벤트 안에서 창을 먼저 열고, 공식 SDK의 popupKey로 같은 창을 사용한다.
    final popupKey = 'agentUnclePostcode${++_serial}';
    final popup = _openWindow(
      'about:blank',
      popupKey,
      'popup,width=500,height=600',
    );
    if (popup == null) {
      throw const AddressSearchFailure('브라우저의 팝업 차단을 해제한 뒤 다시 시도해 주세요.');
    }
    final pending = Completer<AddressSearchResult?>();
    _pending = pending;
    _popup = popup;
    try {
      final postcode = _Postcode(
        _PostcodeOptions(
          oncomplete: ((_PostcodeResult value) {
            try {
              _finish(
                pending,
                result: AddressSearchResult.fromMap({
                  'postcode': value.zonecode ?? '',
                  'roadAddress': value.roadAddress ?? '',
                  'jibunAddress': value.jibunAddress ?? '',
                  'buildingName': value.buildingName ?? '',
                  'source': 'kakao_postcode',
                }),
              );
            } catch (error) {
              _finish(pending, error: error);
            }
          }).toJS,
          onclose: ((String state) {
            if (state == 'FORCE_CLOSE') _finish(pending);
          }).toJS,
        ),
      );
      postcode.open(
        _PopupOptions(popupKey: popupKey, popupTitle: '사입삼춘 주소 검색'),
      );
      if (identical(_pending, pending)) {
        _closedTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
          if (popup.closed) _finish(pending);
        });
      }
    } catch (_) {
      _finish(
        pending,
        error: const AddressSearchFailure('주소 검색 화면을 열지 못했어요. 다시 시도해 주세요.'),
      );
    }
    return pending.future;
  }

  void _finish(
    Completer<AddressSearchResult?> pending, {
    AddressSearchResult? result,
    Object? error,
  }) {
    if (!identical(_pending, pending)) return;
    _pending = null;
    _closedTimer?.cancel();
    _closedTimer = null;
    final popup = _popup;
    _popup = null;
    try {
      popup?.close();
    } finally {
      if (error == null) {
        pending.complete(result);
      } else {
        pending.completeError(error);
      }
    }
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    if (pending != null) _finish(pending);
  }
}
