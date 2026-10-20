// 손으로 쓴 부분 — storefront-hosting.ts의 슬러그·도메인·경로 함수.
part of 'storefront-hosting.dart';

/// 공식 쇼케이스 슬러그(`demo-{템플릿 id}`)인지 판정합니다(대소문자 무시).
bool isShowcaseStorefrontSlug(String slug) => slug.toLowerCase().startsWith(STOREFRONT_SHOWCASE_SLUG_PREFIX);

/// 호스팅 도메인에서 플랫폼이 쓰는 이름이거나 편집 미리보기 주소 모양(`-preview`로 끝남)이라 슬러그로 쓸 수 없는지 판정합니다.
bool isReservedStorefrontSlug(String slug) {
  final lower = slug.toLowerCase();
  return RESERVED_STOREFRONT_SLUGS.contains(lower) || lower.endsWith(STOREFRONT_EDIT_PREVIEW_SUFFIX);
}

/// 편집 미리보기 호스트 이름의 라벨입니다. 사이트 id의 `_`를 `-`로 바꾸고 `-preview`를 붙입니다(`sfs_ab12cd34` → `sfs-ab12cd34-preview`).
String storefrontEditPreviewLabelOf(String siteId) => '${siteId.replaceAll('_', '-')}$STOREFRONT_EDIT_PREVIEW_SUFFIX';

/// 버전 미리보기 호스트 이름의 라벨입니다(`sfs_ab12cd34`, 3 → `sfs-ab12cd34-v3-preview`).
String storefrontVersionPreviewLabelOf(String siteId, int versionNumber) =>
    '${siteId.replaceAll('_', '-')}-v$versionNumber$STOREFRONT_EDIT_PREVIEW_SUFFIX';

/// 도메인을 정규화합니다. 앞뒤 공백·끝 점을 떼고 소문자로 바꾸며 국제화 도메인은 punycode(`xn--`)로 바꿉니다.
///
/// 스킴·경로·포트가 붙은 입력(`https://www.a.com/`)은 그대로 두어 [storefrontCustomHostnameProblem]에서 떨어집니다.
/// 변환할 수 없으면 입력을 소문자로만 바꿔 돌려줍니다.
String normalizeStorefrontHostname(String input) {
  final trimmed = input.trim().replaceFirst(RegExp(r'\.+$'), '');
  if (trimmed.isEmpty || RegExp(r'[\s/:?#@\\[\]%]').hasMatch(trimmed)) return trimmed.toLowerCase();
  if (RegExp(r'^[\x21-\x7e]+$').hasMatch(trimmed)) return trimmed.toLowerCase();
  // WHATWG URL의 IDNA(UTS #46)로 punycode를 만든다
  final url = parseHttpUrl('http://$trimmed');
  return (url?.hostname ?? trimmed).toLowerCase();
}

final _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final _punycodeTld = RegExp(r'^xn--[a-z0-9-]{1,59}$');
final _alphaTld = RegExp(r'^[a-z]{2,63}$');

/// 공개 인터넷에서 쓸 수 없는 최상위 도메인(RFC 2606·6761·6762 등)
const _nonPublicTlds = <String>[
  'example',
  'localhost',
  'local',
  'test',
  'invalid',
  'onion',
  'internal',
  'arpa',
  'home',
  'lan',
  'corp',
  'intranet',
  'alt',
];

/// 연결할 수 있는 도메인인지 판정합니다(정규화한 값 기준). 문제가 없으면 null입니다.
///
/// 문제는 [StorefrontHostnameProblem] 값입니다. `WILDCARD`·`IP_ADDRESS`·`FORMAT`·`SINGLE_LABEL`·`NON_PUBLIC_TLD`·
/// `PLATFORM_DOMAIN`·`PUBLIC_SUFFIX`입니다. [hostingDomain]은 호스팅 도메인입니다(기본 `sayren.co`).
String? storefrontCustomHostnameProblem(String hostname, [String hostingDomain = 'sayren.co']) {
  if (hostname.startsWith('*.')) return 'WILDCARD';
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(hostname) ||
      RegExp(r'^\[?[0-9a-f:.]*:[0-9a-f:.]*\]?$').hasMatch(hostname)) {
    return 'IP_ADDRESS';
  }
  if (hostname.isEmpty || hostname.length > 253) return 'FORMAT';
  final labels = hostname.split('.');
  if (labels.length < 2) return 'SINGLE_LABEL';
  if (!labels.every(_hostLabel.hasMatch)) return 'FORMAT';
  final tld = labels.last;
  if (!_alphaTld.hasMatch(tld) && !_punycodeTld.hasMatch(tld)) return 'FORMAT';
  if (_nonPublicTlds.contains(tld)) return 'NON_PUBLIC_TLD';
  final platform = {...STOREFRONT_PLATFORM_DOMAINS, hostingDomain.toLowerCase()};
  for (final domain in platform) {
    if (hostname == domain || hostname.endsWith('.$domain')) return 'PLATFORM_DOMAIN';
  }
  if (STOREFRONT_PUBLIC_SUFFIXES.contains(hostname)) return 'PUBLIC_SUFFIX';
  return null;
}

/// 소유 확인 TXT 레코드의 전체 이름입니다(`_sayren-verify.{도메인}`).
String storefrontDomainTxtNameOf(String hostname) => '$STOREFRONT_DOMAIN_TXT_LABEL.$hostname';

/// 보이지 않거나 표시 방향을 바꾸는 문자 — 제로폭과 bidi 제어
final _invisibleOrBidi = RegExp('[\u200B-\u200D\uFEFF\u202A-\u202E\u2066-\u2069]');

/// 경로를 NFC로 정규화합니다. 비교·저장은 이 값으로 합니다.
String normalizeStorefrontPath(String path) => unorm.nfc(path);

/// 작업 트리 상대 경로인지 판정합니다(정규화한 값 기준).
///
/// `/`로 구분하고 `/`로 시작하지 않습니다. `.`·`..`·빈 조각, 조각 문자 규칙([STOREFRONT_PATH_SEGMENT_PATTERN]) 밖,
/// 설치물·산출물 폴더([STOREFRONT_BLOCKED_PATH_SEGMENTS]), `.env`로 시작하는 조각은 받지 않습니다. 최대 256자·깊이 16입니다.
bool isEditableStorefrontPath(String path) {
  if (path.isEmpty || path.length > 256) return false;
  if (_invisibleOrBidi.hasMatch(path)) return false;
  if (path != normalizeStorefrontPath(path)) return false;
  if (path.startsWith('/')) return false;
  final segments = path.split('/');
  if (segments.length > 16) return false;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') return false;
    if (!STOREFRONT_PATH_SEGMENT_PATTERN.hasMatch(segment)) return false;
    if (STOREFRONT_BLOCKED_PATH_SEGMENTS.contains(segment)) return false;
    if (segment.startsWith('.env')) return false;
  }
  return true;
}
