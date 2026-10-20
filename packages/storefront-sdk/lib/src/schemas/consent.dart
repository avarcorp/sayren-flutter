import '../zod.dart';

/// 동의 종류 — 이용약관(`TERMS`)·개인정보 수집이용(`PRIVACY`)은 가입 필수, 마케팅 수신(`MARKETING`)은 선택이다
final consentKindSchema = z.enum_(['TERMS', 'PRIVACY', 'MARKETING']);
typedef ConsentKind = String;

/// 동의 이력의 한 줄이 무엇인가 — 동의했거나 철회했다
final consentActionSchema = z.enum_(['AGREED', 'WITHDRAWN']);
typedef ConsentAction = String;

/// 동의가 일어난 경로. 값이 추가될 수 있어 모르는 값은 그대로 보여 준다
final consentSourceSchema = z.enum_(['SIGNUP', 'SOCIAL_SIGNUP', 'DELEGATED', 'RECONSENT', 'MEMBER_UPDATE', 'SELLER']);
typedef ConsentSource = String;

/// 종류별 현재 동의 상태
final consentStateSchema = z.object({
  'kind': consentKindSchema,
  'agreed': z.boolean(),
  'agreedVersion': z.string().nullable(),
  'currentVersion': z.string().nullable(),
  'currentDocumentUrl': z.string().nullable(),
  'updatedAt': z.string().nullable(),
  'reconsentRequired': z.boolean(),
}, ConsentState.fromJson);

class ConsentState extends ParsedObject {
  ConsentState.fromJson(super.json) : super.fromJson();

  ConsentKind get kind => json['kind'] as String;
  bool get agreed => json['agreed'] as bool;
  String? get agreedVersion => json['agreedVersion'] as String?;
  String? get currentVersion => json['currentVersion'] as String?;
  String? get currentDocumentUrl => json['currentDocumentUrl'] as String?;
  String? get updatedAt => json['updatedAt'] as String?;
  bool get reconsentRequired => json['reconsentRequired'] as bool;
}

/// `GET /storefront/v1/me/consents` 응답
final memberConsentsSchema = z.object({
  'terms': consentStateSchema,
  'privacy': consentStateSchema,
  'marketing': consentStateSchema,
  'reconsentRequired': z.boolean(),
}, MemberConsents.fromJson);

class MemberConsents extends ParsedObject {
  MemberConsents.fromJson(super.json) : super.fromJson();

  ConsentState get terms => json['terms'] as ConsentState;
  ConsentState get privacy => json['privacy'] as ConsentState;
  ConsentState get marketing => json['marketing'] as ConsentState;
  bool get reconsentRequired => json['reconsentRequired'] as bool;
}

/// `POST /storefront/v1/me/consents` 본문 — 바꿀 항목만 보낸다. 필수 동의는 동의(`true`)만 보낼 수 있다
final consentUpdateRequestSchema = z.object({
  'terms': z.literal(true).optional(),
  'privacy': z.literal(true).optional(),
  'marketing': z.boolean().optional(),
}, ConsentUpdateRequest.fromJson).refine(
  (value) => value.values.any((v) => v != null),
  message: '최소 1개 항목이 필요합니다',
);

class ConsentUpdateRequest extends ParsedObject {
  ConsentUpdateRequest({bool? terms, bool? privacy, bool? marketing})
      : super.fromJson(compact({'terms': terms, 'privacy': privacy, 'marketing': marketing}));

  ConsentUpdateRequest.fromJson(super.json) : super.fromJson();

  bool? get terms => json['terms'] as bool?;
  bool? get privacy => json['privacy'] as bool?;
  bool? get marketing => json['marketing'] as bool?;
}
