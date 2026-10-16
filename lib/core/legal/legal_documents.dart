import 'legal_documents_platform.dart'
    if (dart.library.js_interop) 'legal_documents_web.dart'
    as platform;

enum LegalDocument {
  terms('서비스 이용약관', 'https://www.the-saena.ai/terms'),
  privacy('개인정보처리방침', 'https://www.the-saena.ai/privacy');

  const LegalDocument(this.title, this.url);

  final String title;
  final String url;

  Future<bool> open() => platform.openLegalDocument(url);
}
