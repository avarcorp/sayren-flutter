// 손으로 쓴 부분 — product.ts의 함수 구현.
part of 'product.dart';

/// 금지어 비교용 정규화 — NFKC·소문자 뒤 문자·숫자만 남긴다(공백·기호·제로폭 문자로 쪼갠 우회를 막는다)
String _forbiddenWordKeyOf(String text) =>
    unorm.nfkc(text).toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// 직접 입력 항목명·입력 안내에 든 개인정보성 금지어를 돌려줍니다. 없으면 null입니다.
///
/// 공백·기호·대소문자·전각을 무시합니다. 서버는 항목명과 입력 안내 둘 다 이 함수로 검사합니다.
String? customInputLabelForbiddenWord(String label) {
  final normalized = _forbiddenWordKeyOf(label);
  for (final word in CUSTOM_INPUT_FORBIDDEN_WORDS) {
    if (normalized.contains(_forbiddenWordKeyOf(word))) return word;
  }
  return null;
}

/// JS `new URL(value)` — 절대 주소만 읽는다. 읽을 수 없으면 null
Uri? _parseUrl(String value) {
  // WHATWG URL처럼 앞뒤 제어 문자·공백을 지우고 탭·줄바꿈을 뺀다
  final input = value.replaceAll(RegExp(r'^[\u0000- ]+|[\u0000- ]+$'), '').replaceAll(RegExp('[\t\n\r]'), '');
  final uri = Uri.tryParse(input);
  if (uri == null || !uri.hasScheme) return null;
  const special = {'http', 'https', 'ws', 'wss', 'ftp'};
  if (special.contains(uri.scheme) && uri.host.isEmpty) return null;
  return uri;
}

/// 상품에 새로 붙이는 이미지 주소의 규칙을 검사합니다. 통과하면 null입니다.
///
/// - https만 받습니다. http는 혼합 콘텐츠로 차단되고 `data:`·`javascript:`는 주입 경로가 됩니다.
/// - 호스트는 제한하지 않습니다.
/// - 경로에 확장자가 있으면 상품 이미지 형식이어야 합니다(svg·동영상 거부). 확장자가 없으면 통과시킵니다.
ProductImageRejection? productImageRejection(String url) {
  if (url.length > 2048) {
    return const ProductImageRejection(code: 'INVALID_IMAGE_URL', message: '이미지 주소가 너무 깁니다');
  }
  final parsed = _parseUrl(url);
  if (parsed == null) {
    return const ProductImageRejection(code: 'INVALID_IMAGE_URL', message: '이미지 주소 형식이 아닙니다');
  }
  if (parsed.scheme != 'https') {
    return const ProductImageRejection(code: 'INVALID_IMAGE_URL', message: '이미지 주소는 https로 시작해야 합니다');
  }
  final extension = uploadExtensionOf(parsed.path.isEmpty ? '/' : parsed.path);
  final allowed = UPLOAD_PURPOSE_LIMITS['product-image']!['extensions']! as List<String>;
  if (extension.isNotEmpty && !allowed.contains(extension)) {
    return ProductImageRejection(
      code: 'UNSUPPORTED_FILE_TYPE',
      message: '상품 이미지는 ${allowed.join(', ')}만 쓸 수 있습니다',
    );
  }
  return null;
}
