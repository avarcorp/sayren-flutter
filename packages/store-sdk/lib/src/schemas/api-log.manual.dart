// 손으로 쓴 부분 — api-log.ts의 클라이언트 인자 타입과 쉼표 목록 변환.
part of 'api-log.dart';

/// 클라이언트 `apiLogs.list` 인자입니다. [ApiLogListParams]와 같고 [principalType]은 값 하나 또는 목록을 받습니다.
///
/// ```dart
/// await client.apiLogs.list(ApiLogListOptions(principalType: ['PAT', 'CLIENT'], limit: 20));
/// ```
class ApiLogListOptions {
  /// [ApiLogListOptions]를 만듭니다.
  const ApiLogListOptions({
    this.from,
    this.to,
    this.principalType,
    this.principalId,
    this.status,
    this.q,
    this.traceId,
    this.cursor,
    this.limit,
  });

  /// 조회 시작 일시(ISO 8601, 포함)입니다. 보관 기간은 7일입니다.
  final String? from;

  /// 조회 종료 일시(ISO 8601, 미포함)입니다.
  final String? to;

  /// 호출 주체 유형 필터입니다. [ApiLogPrincipalType] 하나(`String`) 또는 목록(`List<String>`)을 받습니다.
  final Object? principalType;

  /// 호출 주체 ID 필터입니다.
  final String? principalId;

  /// 상태 필터입니다([ApiLogStatusFilter]).
  final String? status;

  /// 경로 부분 일치 검색어입니다.
  final String? q;

  /// 추적 ID 필터입니다.
  final String? traceId;

  /// 다음 페이지 커서입니다.
  final String? cursor;

  /// 최대 건수(1~100, 기본 50)입니다.
  final int? limit;

  /// 쿼리 파라미터로 바꿉니다. 목록인 [principalType]은 쉼표로 잇고(Node 클라이언트와 같다), null인 값은 뺍니다.
  Map<String, Object?> toJson() => compact({
        'from': from,
        'to': to,
        'principalType': _joinCsv(principalType),
        'principalId': principalId,
        'status': status,
        'q': q,
        'traceId': traceId,
        'cursor': cursor,
        'limit': limit,
      });
}

/// 목록이면 쉼표로 잇는다(Node 클라이언트의 `Array.isArray(v) ? v.join(",") : v`)
Object? _joinCsv(Object? value) => value is List ? value.join(',') : value;

/// 쉼표 목록 변환 — 값 하나·목록을 쉼표로 나눠 앞뒤 공백을 떼고 빈 값을 뺀다
Object? _splitCsv(Object? value) => (value is List ? value : [value])
    .expand((part) => (part as String).split(','))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();
