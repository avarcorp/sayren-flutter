import '../zod.dart';

/// 동의 종류 스키마입니다. 값은 [ConsentKind]를 보십시오.
final consentKindSchema = z.enum_(['TERMS', 'PRIVACY', 'MARKETING']);

/// 동의 종류입니다.
///
/// - `TERMS`: 이용약관. 가입 필수입니다.
/// - `PRIVACY`: 개인정보 수집이용. 가입 필수입니다.
/// - `MARKETING`: 마케팅 수신. 선택입니다.
///
/// 필수 동의는 철회할 수 없습니다(철회하려면 탈퇴합니다).
typedef ConsentKind = String;

/// 동의 이력 동작 스키마입니다. 값은 [ConsentAction]을 보십시오.
final consentActionSchema = z.enum_(['AGREED', 'WITHDRAWN']);

/// 동의 이력의 한 줄이 무엇인지입니다. `AGREED`(동의)·`WITHDRAWN`(철회)입니다.
typedef ConsentAction = String;

/// 동의 경로 스키마입니다. 값은 [ConsentSource]를 보십시오.
final consentSourceSchema = z.enum_(['SIGNUP', 'SOCIAL_SIGNUP', 'DELEGATED', 'RECONSENT', 'MEMBER_UPDATE', 'SELLER']);

/// 동의가 일어난 경로입니다. 값이 추가될 수 있으므로 모르는 값은 그대로 보여 주십시오.
///
/// - `SIGNUP`: 비밀번호 가입
/// - `SOCIAL_SIGNUP`: 소셜 가입
/// - `DELEGATED`: 셀러 자체 회원 연동
/// - `RECONSENT`: 약관 개정 재동의
/// - `MEMBER_UPDATE`: 구매자가 직접 변경
/// - `SELLER`: 셀러가 처리
typedef ConsentSource = String;

/// [ConsentState] 스키마입니다.
final consentStateSchema = z.object({
  'kind': consentKindSchema,
  'agreed': z.boolean(),
  'agreedVersion': z.string().nullable(),
  'currentVersion': z.string().nullable(),
  'currentDocumentUrl': z.string().nullable(),
  'updatedAt': z.string().nullable(),
  'reconsentRequired': z.boolean(),
}, ConsentState._);

/// 종류별 현재 동의 상태입니다.
class ConsentState extends ParsedObject {
  /// 동의 상태를 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.
  ConsentState({
    required ConsentKind kind,
    required bool agreed,
    required String? agreedVersion,
    required String? currentVersion,
    required String? currentDocumentUrl,
    required String? updatedAt,
    required bool reconsentRequired,
  }) : super({
          'kind': kind,
          'agreed': agreed,
          'agreedVersion': agreedVersion,
          'currentVersion': currentVersion,
          'currentDocumentUrl': currentDocumentUrl,
          'updatedAt': updatedAt,
          'reconsentRequired': reconsentRequired,
        });

  ConsentState._(super.json);

  /// JSON을 [consentStateSchema]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  factory ConsentState.fromJson(Map<String, Object?> json) => consentStateSchema.parse(json);

  Map<String, Object?> get _j => jsonOf(this);

  /// 동의 종류입니다. 값은 [ConsentKind]를 보십시오.
  ConsentKind get kind => _j['kind'] as String;

  /// 지금 동의한 상태인지입니다.
  bool get agreed => _j['agreed'] as bool;

  /// 동의한 약관 버전입니다. 마케팅은 버전이 없어 null이고, 동의 이력이 없어도 null입니다.
  String? get agreedVersion => _j['agreedVersion'] as String?;

  /// 상점의 현재 약관 버전입니다. 마케팅은 null입니다.
  String? get currentVersion => _j['currentVersion'] as String?;

  /// 상점이 정한 현재 약관 문서 주소입니다. 재동의 화면에서 이 주소를 보여 주십시오.
  ///
  /// 상점이 정하지 않았거나 마케팅이면 null입니다.
  String? get currentDocumentUrl => _j['currentDocumentUrl'] as String?;

  /// 마지막으로 동의·철회한 시각(ISO 8601)입니다. 이력이 없으면 null입니다.
  String? get updatedAt => _j['updatedAt'] as String?;

  /// 약관이 개정돼 다시 동의받아야 하는지입니다. 마케팅은 항상 false입니다.
  bool get reconsentRequired => _j['reconsentRequired'] as bool;
}

/// [MemberConsents] 스키마입니다.
final memberConsentsSchema = z.object({
  'terms': consentStateSchema,
  'privacy': consentStateSchema,
  'marketing': consentStateSchema,
  'reconsentRequired': z.boolean(),
}, MemberConsents._);

/// 회원의 약관·개인정보·마케팅 동의 상태입니다.
class MemberConsents extends ParsedObject {
  /// 동의 상태 묶음를 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.
  MemberConsents({
    required ConsentState terms,
    required ConsentState privacy,
    required ConsentState marketing,
    required bool reconsentRequired,
  }) : super({'terms': terms, 'privacy': privacy, 'marketing': marketing, 'reconsentRequired': reconsentRequired});

  MemberConsents._(super.json);

  /// JSON을 [memberConsentsSchema]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  factory MemberConsents.fromJson(Map<String, Object?> json) => memberConsentsSchema.parse(json);

  Map<String, Object?> get _j => jsonOf(this);

  /// 이용약관 동의 상태입니다.
  ConsentState get terms => _j['terms'] as ConsentState;

  /// 개인정보 수집이용 동의 상태입니다.
  ConsentState get privacy => _j['privacy'] as ConsentState;

  /// 마케팅 수신 동의 상태입니다.
  ConsentState get marketing => _j['marketing'] as ConsentState;

  /// 필수 동의 중 하나라도 다시 받아야 하는지입니다. true면 재동의 화면을 띄우고
  /// `client.member.updateConsents`로 받으십시오.
  bool get reconsentRequired => _j['reconsentRequired'] as bool;
}

/// [ConsentUpdateRequest] 스키마입니다. 항목이 하나도 없으면 실패합니다.
final consentUpdateRequestSchema = z.object({
  'terms': z.literal(true).optional(),
  'privacy': z.literal(true).optional(),
  'marketing': z.boolean().optional(),
}, ConsentUpdateRequest._).refine(
  (value) => value.values.any((v) => v != null),
  message: '최소 1개 항목이 필요합니다',
);

/// 동의 변경 요청 본문입니다. 바꿀 항목만 넣습니다.
///
/// 이미 현재 버전에 동의한 항목은 이력을 더 남기지 않습니다.
///
/// ```dart
/// ConsentUpdateRequest(marketing: true);             // 마케팅 수신 동의
/// ConsentUpdateRequest(terms: true, privacy: true);  // 개정 약관 재동의
/// ```
class ConsentUpdateRequest extends ParsedObject {
  /// 요청 본문을 만듭니다. null인 항목은 보내지 않습니다.
  ///
  /// 검증은 요청을 보낼 때 [consentUpdateRequestSchema]로 합니다.
  ConsentUpdateRequest({bool? terms, bool? privacy, bool? marketing})
      : super(compact({'terms': terms, 'privacy': privacy, 'marketing': marketing}));

  ConsentUpdateRequest._(super.json);

  /// JSON을 [consentUpdateRequestSchema]로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  factory ConsentUpdateRequest.fromJson(Map<String, Object?> json) => consentUpdateRequestSchema.parse(json);

  Map<String, Object?> get _j => jsonOf(this);

  /// 이용약관 재동의입니다. 필수 동의라 `true`만 보낼 수 있습니다.
  bool? get terms => _j['terms'] as bool?;

  /// 개인정보 수집이용 재동의입니다. 필수 동의라 `true`만 보낼 수 있습니다.
  bool? get privacy => _j['privacy'] as bool?;

  /// 마케팅 수신 동의입니다. `false`면 철회합니다.
  bool? get marketing => _j['marketing'] as bool?;
}
