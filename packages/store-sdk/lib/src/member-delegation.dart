// 손으로 쓴 파일 — Node src/member-delegation.ts에 대응한다.
// 구매자 위임: 자체 회원 시스템을 가진 셀러 서버가 로그인한 사용자를 sayren 구매자 토큰으로 바꾼다.
// 계정 토큰(개인 액세스 토큰 등)을 쓰므로 서버에서만 부른다. 응답은 구매자 액세스 토큰(30분)이고 갱신 토큰은 없다.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http.dart';

/// 위임으로 받은 구매자 토큰입니다. 만료되면 [delegateMember]를 다시 부르십시오.
class DelegatedMemberToken {
  /// 값을 만듭니다.
  const DelegatedMemberToken({required this.accessToken, required this.expiresIn, required this.memberId});

  /// 구매자 액세스 토큰입니다.
  final String accessToken;

  /// 유효 시간(초)입니다.
  final num expiresIn;

  /// 구매자 id입니다.
  final String memberId;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson() => {'accessToken': accessToken, 'expiresIn': expiresIn, 'memberId': memberId};
}

/// 위임 실패입니다. [error]는 API 오류 코드(엔벨로프 `error.code`, 없으면 `http_{status}`)입니다.
class MemberDelegationError implements Exception {
  /// 예외를 만듭니다.
  const MemberDelegationError(this.error, this.description, this.status);

  /// 오류 코드입니다.
  final String error;

  /// 오류 설명입니다. 없으면 빈 문자열입니다.
  final String description;

  /// HTTP 상태 코드입니다.
  final int status;

  /// 예외 이름입니다. 항상 `MemberDelegationError`입니다.
  String get name => 'MemberDelegationError';

  /// `{error}: {description}`, 설명이 없으면 [error]입니다.
  String get message => description.isNotEmpty ? '$error: $description' : error;

  @override
  String toString() => 'MemberDelegationError: $message';
}

/// JS `Date.prototype.toISOString()` — 밀리초 3자리, UTC
String _toIsoString(DateTime value) {
  final t = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final year = t.year >= 0 && t.year <= 9999
      ? t.year.toString().padLeft(4, '0')
      : (t.year < 0 ? '-' : '+') + t.year.abs().toString().padLeft(6, '0');
  return '$year-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}Z';
}

/// 계정 토큰으로 구매자를 위임합니다(`POST /v1/customers/delegations`). `customer:rw`가 필요합니다.
///
/// [uid](셀러 자체 인증의 사용자 id) 또는 [email]로 지목하고, 처음 보는 사용자면 구매자를 만듭니다.
/// 실패하면 [MemberDelegationError]를 던집니다.
///
/// - [baseUrl]: API 주소(예: `https://api.sayren.io`)
///
/// ```dart
/// final token = await delegateMember(baseUrl: 'https://api.sayren.io', accessToken: pat, storeId: storeId, uid: user.id);
/// ```
Future<DelegatedMemberToken> delegateMember({
  required String baseUrl,
  required String accessToken,
  required String storeId,
  String? uid,
  String? email,
  String? name,
  DateTime? authenticatedAt,
  Fetch? fetch,
}) async {
  final request =
      http.Request('POST', Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/customers/delegations'))
        ..headers.addAll({
          'content-type': 'application/json',
          'authorization': 'Bearer $accessToken',
          'x-store-id': storeId,
        })
        ..bodyBytes = utf8.encode(jsonEncode({
          if (uid != null && uid.isNotEmpty) 'uid': uid,
          if (email != null && email.isNotEmpty) 'email': email,
          if (name != null && name.isNotEmpty) 'name': name,
          if (authenticatedAt != null) 'authenticatedAt': _toIsoString(authenticatedAt),
        }));
  final response = await (fetch ?? defaultFetch())(request);
  Object? body;
  try {
    body = jsonDecode(utf8.decode(response.bodyBytes));
  } catch (_) {
    body = const <String, Object?>{};
  }
  final json = body is Map ? body : const <String, Object?>{};
  final data = json['data'] is Map ? json['data'] as Map : null;
  final ok = response.statusCode >= 200 && response.statusCode <= 299;
  if (!ok || data?['accessToken'] is! String) {
    final error = json['error'] is Map ? json['error'] as Map : null;
    final code = error?['code'] is String ? error!['code'] as String : 'http_${response.statusCode}';
    final message = error?['message'] is String ? error!['message'] as String : '';
    throw MemberDelegationError(code, message, response.statusCode);
  }
  // JS Number()·String()과 같게 읽는다
  final expiresIn = data!['expiresIn'];
  final memberId = data.containsKey('memberId') ? data['memberId'] : 'undefined';
  return DelegatedMemberToken(
    accessToken: data['accessToken'] as String,
    expiresIn: expiresIn is num
        ? expiresIn
        : expiresIn is String
            ? (num.tryParse(expiresIn.trim().isEmpty ? '0' : expiresIn.trim()) ?? double.nan)
            : expiresIn == null && data.containsKey('expiresIn')
                ? 0
                : expiresIn is bool
                    ? (expiresIn ? 1 : 0)
                    : double.nan,
    memberId: '$memberId',
  );
}
