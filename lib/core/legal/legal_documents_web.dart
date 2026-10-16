import 'dart:js_interop';

@JS('window.open')
external void _openWindow(String url, String target, String features);

Future<bool> openLegalDocument(String url) async {
  // 사용자 클릭 안에서 바로 열어 팝업 차단을 피하고 가입 화면을 유지한다.
  _openWindow(url, '_blank', 'noopener,noreferrer');
  return true;
}
