// 손으로 쓴 부분 — audit.ts의 클라이언트 인자 타입과 쉼표 목록 변환.
part of 'audit.dart';

/// 클라이언트 `auditLogs.list` 인자입니다. [AuditLogListParams]와 같고 [actorType]은 값 하나 또는 목록을 받습니다.
///
/// ```dart
/// await client.auditLogs.list(AuditLogListOptions(actorType: ['AGENT', 'APP']));
/// ```
class AuditLogListOptions {
  /// [AuditLogListOptions]를 만듭니다.
  const AuditLogListOptions({
    this.from,
    this.to,
    this.actorType,
    this.actorId,
    this.action,
    this.targetType,
    this.targetId,
    this.source,
    this.outcome,
    this.requestId,
    this.approvalId,
    this.cursor,
    this.limit,
  });

  /// 조회 시작 일시(ISO 8601, 포함)입니다.
  final String? from;

  /// 조회 종료 일시(ISO 8601, 미포함)입니다.
  final String? to;

  /// 행위자 유형 필터입니다. [AuditActorType] 하나(`String`) 또는 목록(`List<String>`)을 받습니다.
  final Object? actorType;

  /// 행위자 ID 필터(정확히 일치)입니다.
  final String? actorId;

  /// 동작 필터(정확히 일치)입니다.
  final String? action;

  /// 대상 유형 필터(정확히 일치)입니다.
  final String? targetType;

  /// 대상 ID 필터(정확히 일치)입니다.
  final String? targetId;

  /// 기록 출처 필터입니다([AuditLogSource]).
  final String? source;

  /// 결과 필터입니다([AuditLogOutcome]).
  final String? outcome;

  /// 요청 ID 필터입니다. 한 요청의 요청·도메인 기록을 함께 봅니다.
  final String? requestId;

  /// 승인 요청 ID 필터입니다.
  final String? approvalId;

  /// 이전 응답의 `nextCursor`입니다. 생략하면 가장 최신부터입니다.
  final String? cursor;

  /// 최대 건수(1~100, 기본 50)입니다.
  final int? limit;

  /// 쿼리 파라미터로 바꿉니다. 목록인 [actorType]은 쉼표로 잇고(Node 클라이언트와 같다), null인 값은 뺍니다.
  Map<String, Object?> toJson() => compact({
        'from': from,
        'to': to,
        'actorType': _joinCsv(actorType),
        'actorId': actorId,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'source': source,
        'outcome': outcome,
        'requestId': requestId,
        'approvalId': approvalId,
        'cursor': cursor,
        'limit': limit,
      });
}

/// 클라이언트 `approvalRequests.list` 인자입니다. [ApprovalListParams]와 같고 [status]는 값 하나 또는 목록을 받습니다.
///
/// ```dart
/// await client.approvalRequests.list(ApprovalListOptions(status: 'PENDING'));
/// ```
class ApprovalListOptions {
  /// [ApprovalListOptions]를 만듭니다.
  const ApprovalListOptions({this.status, this.cursor, this.limit});

  /// 상태 필터입니다. [ApprovalStatus] 하나(`String`) 또는 목록(`List<String>`)을 받습니다.
  final Object? status;

  /// 이전 응답의 `nextCursor`입니다. 생략하면 가장 최신부터입니다.
  final String? cursor;

  /// 최대 건수(1~100, 기본 50)입니다.
  final int? limit;

  /// 쿼리 파라미터로 바꿉니다. 목록인 [status]는 쉼표로 잇고(Node 클라이언트와 같다), null인 값은 뺍니다.
  Map<String, Object?> toJson() => compact({'status': _joinCsv(status), 'cursor': cursor, 'limit': limit});
}

/// 목록이면 쉼표로 잇는다(Node 클라이언트의 `Array.isArray(v) ? v.join(",") : v`)
Object? _joinCsv(Object? value) => value is List ? value.join(',') : value;

/// 쉼표 목록 변환 — 값 하나·목록을 쉼표로 나눠 앞뒤 공백을 떼고 빈 값을 뺀다
Object? _splitCsv(Object? value) => (value is List ? value : [value])
    .expand((part) => (part as String).split(','))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();
