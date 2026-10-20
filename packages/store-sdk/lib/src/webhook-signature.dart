// 손으로 쓴 파일 — Node src/webhook-signature.ts에 대응한다.
// 형식: `t=<unix초>,v1=<hex>[,v1=<hex>]`. v1 = HMAC-SHA256(secret, `${t}.${rawBody}`)의 소문자 hex.
// 시크릿 교체 유예 중에는 현재·이전 시크릿 서명을 모두 싣는다(현재 먼저). 시크릿을 다루므로 server.dart로만 공개한다.
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'webhook-headers.dart';

List<int> _signedContent(int timestamp, String payload) => utf8.encode('$timestamp.$payload');

List<int> _hmac(String secret, List<int> content) =>
    crypto.Hmac(crypto.sha256, utf8.encode(secret)).convert(content).bytes;

String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// 64자 hex → 32바이트. 형식이 아니면 null
List<int>? _fromHex(String hex) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) return null;
  return [for (var i = 0; i < 32; i++) int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)];
}

/// 길이가 같은 두 바이트 열을 상수 시간으로 비교한다
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// 시크릿 하나(`String`) 또는 여러 개(`List<String>`) → 빈 값을 뺀 목록
List<String> _toSecretList(Object secret) => [
      for (final s in secret is String ? [secret] : (secret as List).cast<String>())
        if (s.isNotEmpty) s,
    ];

/// [signWebhookPayload]의 옵션입니다.
class SignWebhookPayloadOptions {
  /// 옵션을 만듭니다.
  const SignWebhookPayloadOptions({required this.payload, required this.secret, this.timestamp});

  /// 요청 본문 원문입니다. 전송하는 바이트와 정확히 같아야 합니다.
  final String payload;

  /// 서명 시크릿입니다. `String` 또는 `List<String>`이고, 여러 개면 순서대로 v1을 싣습니다(현재 시크릿 먼저).
  final Object secret;

  /// 서명 시각(unix 초)입니다. 생략하면 현재 시각입니다.
  final int? timestamp;
}

/// `Sayren-Signature` 헤더 값을 만듭니다.
///
/// ```dart
/// final header = await signWebhookPayload(SignWebhookPayloadOptions(payload: body, secret: secret));
/// ```
Future<String> signWebhookPayload(SignWebhookPayloadOptions options) async {
  final secrets = _toSecretList(options.secret);
  if (secrets.isEmpty) throw ArgumentError('서명 시크릿이 비어 있습니다');
  final timestamp = options.timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (timestamp < 0 || timestamp > 9007199254740991) {
    throw ArgumentError('timestamp는 0 이상의 정수(unix 초)여야 합니다');
  }
  final content = _signedContent(timestamp, options.payload);
  return ['t=$timestamp', for (final secret in secrets) 'v1=${_toHex(_hmac(secret, content))}'].join(',');
}

/// 파싱한 `Sayren-Signature` 헤더입니다.
class ParsedWebhookSignature {
  /// 값을 만듭니다.
  const ParsedWebhookSignature({required this.timestamp, required this.signatures});

  /// 서명 시각(unix 초)입니다.
  final int timestamp;

  /// v1 서명(hex) 목록입니다. 헤더에 실린 순서 그대로입니다.
  final List<String> signatures;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson() => {'timestamp': timestamp, 'signatures': signatures};
}

/// `Sayren-Signature` 헤더를 파싱합니다. `t`가 정확히 1개, `v1`이 1개 이상이어야 하고 아니면 null입니다.
///
/// 알 수 없는 스킴(예: 앞으로 생길 `v2`)은 무시합니다.
ParsedWebhookSignature? parseWebhookSignatureHeader(String? header) {
  if (header == null || header.isEmpty) return null;
  int? timestamp;
  final signatures = <String>[];
  for (final raw in header.split(',')) {
    final part = raw.trim();
    final eq = part.indexOf('=');
    if (eq <= 0) return null;
    final scheme = part.substring(0, eq);
    final value = part.substring(eq + 1);
    if (scheme == 't') {
      if (timestamp != null || !RegExp(r'^\d{1,15}$').hasMatch(value)) return null;
      timestamp = int.parse(value);
    } else if (scheme == 'v1') {
      if (value.isEmpty) return null;
      signatures.add(value);
    }
  }
  if (timestamp == null || signatures.isEmpty) return null;
  return ParsedWebhookSignature(timestamp: timestamp, signatures: signatures);
}

/// 서명 검증 실패 이유입니다.
///
/// 값은 `MISSING_HEADER`(헤더가 없거나 비어 있음)·`MALFORMED_HEADER`(`t` 누락·중복·비정수, `v1` 없음)·
/// `TIMESTAMP_OUT_OF_TOLERANCE`(서명 시각이 허용 오차를 벗어남, 재전송 공격 방지)·
/// `SIGNATURE_MISMATCH`(어떤 시크릿으로도 일치하는 v1이 없음, 본문 변조·시크릿 불일치)입니다.
typedef WebhookSignatureFailureReason = String;

/// 서명 검증 결과입니다. [ok]로 분기하고, 통과면 [WebhookSignatureVerificationOk], 실패면 [WebhookSignatureVerificationFailed]입니다.
sealed class WebhookSignatureVerification {
  const WebhookSignatureVerification();

  /// 통과했는지입니다.
  bool get ok;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson();
}

/// 서명 검증 통과입니다.
final class WebhookSignatureVerificationOk extends WebhookSignatureVerification {
  /// 결과를 만듭니다.
  const WebhookSignatureVerificationOk(this.timestamp);

  @override
  bool get ok => true;

  /// 서명 시각(unix 초)입니다.
  final int timestamp;

  @override
  Map<String, Object?> toJson() => {'ok': true, 'timestamp': timestamp};
}

/// 서명 검증 실패입니다.
final class WebhookSignatureVerificationFailed extends WebhookSignatureVerification {
  /// 결과를 만듭니다.
  const WebhookSignatureVerificationFailed(this.reason);

  @override
  bool get ok => false;

  /// 실패 이유입니다.
  final WebhookSignatureFailureReason reason;

  @override
  Map<String, Object?> toJson() => {'ok': false, 'reason': reason};
}

/// [verifyWebhookSignature]의 옵션입니다.
class VerifyWebhookSignatureOptions {
  /// 옵션을 만듭니다.
  const VerifyWebhookSignatureOptions({
    required this.payload,
    required this.header,
    required this.secret,
    this.toleranceSec,
    this.now,
  });

  /// 요청 본문 원문입니다. JSON 파싱 전 바이트 그대로의 문자열이어야 합니다.
  final String payload;

  /// `Sayren-Signature` 헤더 값입니다.
  final String? header;

  /// 서명 시크릿입니다. `String` 또는 `List<String>`입니다. 교체 유예 중이면 새·이전 시크릿을 모두 넘기고, 하나라도 일치하면 통과합니다.
  final Object secret;

  /// 타임스탬프 허용 오차(초)입니다. 기본은 [WEBHOOK_DEFAULT_TOLERANCE_SEC](300)입니다.
  final int? toleranceSec;

  /// 기준 시각입니다. 생략하면 현재 시각입니다.
  final DateTime? now;
}

/// `Sayren-Signature`를 검증합니다. 헤더의 v1 중 하나가 시크릿 중 하나와 일치하면 통과합니다(상수 시간 비교).
///
/// 실패해도 예외를 던지지 않고 [WebhookSignatureVerificationFailed]를 돌려줍니다. 시크릿이 비어 있으면 [ArgumentError]입니다.
///
/// ```dart
/// final result = await verifyWebhookSignature(VerifyWebhookSignatureOptions(
///   payload: rawBody,
///   header: request.headers[WEBHOOK_SIGNATURE_HEADER.toLowerCase()],
///   secret: webhookSecret,
/// ));
/// if (!result.ok) return Response(400);
/// ```
Future<WebhookSignatureVerification> verifyWebhookSignature(VerifyWebhookSignatureOptions options) async {
  final secrets = _toSecretList(options.secret);
  if (secrets.isEmpty) throw ArgumentError('서명 시크릿이 비어 있습니다');
  final header = options.header;
  if (header == null || header.isEmpty) return const WebhookSignatureVerificationFailed('MISSING_HEADER');
  final parsed = parseWebhookSignatureHeader(header);
  if (parsed == null) return const WebhookSignatureVerificationFailed('MALFORMED_HEADER');

  final tolerance = options.toleranceSec ?? WEBHOOK_DEFAULT_TOLERANCE_SEC;
  final nowSec = (options.now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  if ((nowSec - parsed.timestamp).abs() > tolerance) {
    return const WebhookSignatureVerificationFailed('TIMESTAMP_OUT_OF_TOLERANCE');
  }

  final candidates = [for (final s in parsed.signatures) _fromHex(s)].whereType<List<int>>().toList();
  if (candidates.isNotEmpty) {
    final content = _signedContent(parsed.timestamp, options.payload);
    for (final secret in secrets) {
      final expected = _hmac(secret, content);
      for (final signature in candidates) {
        if (_constantTimeEquals(expected, signature)) return WebhookSignatureVerificationOk(parsed.timestamp);
      }
    }
  }
  return const WebhookSignatureVerificationFailed('SIGNATURE_MISMATCH');
}
