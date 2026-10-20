/// @docImport 'client.dart';
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'zod.dart';

/// 표준 엔벨로프의 $.error 상세
final errorDetailSchema = z.plainObject({
  'code': z.string(),
  'message': z.string(),
  'traceId': z.string().optional(),
  'docs': z.url().optional().catchValue(absent),
  'details': z.record().optional().catchValue(absent),
});

/// 표준 응답 엔벨로프 — $.meta / $.data / $.error
final envelopeSchema = z.plainObject({
  'meta': z.plainObject({
    'status': z.number(),
    'code': z.string(),
    'message': z.string(),
    'isSuccess': z.boolean(),
  }),
  'data': z.unknown().optional(),
  'content': z.unknown().optional(),
  'error': errorDetailSchema.nullable(),
});

/// 표준 엔벨로프면 $.data(구형 $.content)를, 아니면(평면 응답) 본문 전체를 반환
Object? unwrapData(Object? json) {
  final envelope = envelopeSchema.safeParse(json);
  if (!envelope.success) return json;
  return envelope.data!['data'] ?? envelope.data!['content'];
}

/// 서버가 2xx가 아닌 응답을 돌려줬을 때 던지는 예외입니다.
///
/// [code]는 `ORDER_NOT_FOUND`처럼 대문자 오류 코드입니다. 화면 분기는 [status]보다 [code]로 하십시오.
///
/// ```dart
/// try {
///   await client.store.get();
/// } on ApiError catch (e) {
///   if (e.code == 'STORE_NOT_FOUND') showNotFound();
/// }
/// ```
class ApiError implements Exception {
  /// 예외를 만듭니다. SDK가 응답에서 만들므로 직접 만들 일은 보통 없습니다.
  const ApiError(this.status, this.code, this.message, [this.traceId, this.body, this.details, this.docs]);

  /// HTTP 상태 코드입니다.
  final int status;

  /// 오류 코드입니다(예: `ORDER_NOT_FOUND`). 응답에 오류 정보가 없으면 `UNKNOWN`입니다.
  final String code;

  /// 사람이 읽는 오류 설명입니다. 응답에 오류 정보가 없으면 `HTTP {status}`입니다.
  final String message;

  /// 서버 요청 추적 ID입니다. 문의할 때 함께 알려 주십시오.
  final String? traceId;

  /// 응답 본문(JSON)입니다. 본문이 JSON이 아니면 null입니다.
  final Object? body;

  /// 오류 코드별 보조 데이터입니다. 형태는 오류 코드마다 다릅니다. 없으면 null입니다.
  final Map<String, Object?>? details;

  /// 이 오류 코드를 설명하는 문서 주소입니다. 없으면 null입니다.
  final String? docs;

  /// 예외 이름입니다. 항상 `ApiError`입니다.
  String get name => 'ApiError';

  @override
  String toString() => 'ApiError($status $code): $message';
}

/// 비-2xx 응답 본문(raw JSON)을 표준 ApiError로 변환한다. 표준 엔벨로프($.error) 우선, 구형 평면 에러는 폴백
ApiError toApiError(int status, Object? raw) {
  final envelope = envelopeSchema.safeParse(raw);
  final detail =
      envelope.success ? envelope.data!['error'] as Map<String, Object?>? : errorDetailSchema.safeParse(raw).data;
  if (detail != null) {
    return ApiError(
      status,
      detail['code'] as String,
      detail['message'] as String,
      detail['traceId'] as String?,
      raw,
      detail['details'] as Map<String, Object?>?,
      detail['docs'] as String?,
    );
  }
  return ApiError(status, 'UNKNOWN', 'HTTP $status', null, raw);
}

/// 경로 조각마다 `encodeURIComponent`를 적용한다 — Node `path` 태그와 같다
String path(List<String> strings, [List<Object> params = const []]) {
  final out = StringBuffer(strings.first);
  for (var i = 0; i < params.length; i++) {
    out
      ..write(encodeURIComponent('${params[i]}'))
      ..write(strings[i + 1]);
  }
  return out.toString();
}

const _uriComponentSafe = r"-_.!~*'()";
const _formSafe = '*-._';

String _percentEncode(String value, String safe, {bool spaceAsPlus = false}) {
  final out = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final c = String.fromCharCode(byte);
    final alnum = (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) || (byte >= 0x61 && byte <= 0x7a);
    if (alnum || (byte < 0x80 && safe.contains(c))) {
      out.write(c);
    } else if (spaceAsPlus && byte == 0x20) {
      out.write('+');
    } else {
      out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// JS `encodeURIComponent`
String encodeURIComponent(String value) => _percentEncode(value, _uriComponentSafe);

/// 문자열 또는 문자열을 돌려주는 함수(`String? Function()`)입니다.
///
/// 함수를 넘기면 요청마다 호출해 최신 값을 읽습니다. null이나 빈 문자열이면 그 헤더를 보내지 않습니다.
/// 다른 타입을 넘기면 요청할 때 [ArgumentError]를 던집니다.
typedef TokenSource = Object?;

/// [source]의 현재 값을 읽습니다. 함수면 호출합니다.
String? resolveToken(TokenSource source) {
  if (source == null || source is String) return source as String?;
  if (source is String? Function()) return source();
  throw ArgumentError.value(source, 'source', 'String 또는 String? Function()이어야 합니다');
}

/// 쿼리 파라미터입니다. 값이 null인 항목은 보내지 않습니다.
typedef Query = Map<String, Object?>;

/// JS `String(value)` — 정수인 double은 소수점 없이 쓴다
String _jsString(Object value) => value is double && value == value.truncateToDouble() && value.isFinite
    ? value.toInt().toString()
    : value.toString();

/// [query]로 `?page=1&size=20` 형태의 쿼리 문자열을 만듭니다.
///
/// 브라우저 `URLSearchParams`와 같은 규칙으로 인코딩합니다. 값이 null인 항목은 빼고, 남은 항목이 없으면 빈 문자열입니다.
String buildQuery([Query? query]) {
  if (query == null) return '';
  final parts = [
    for (final e in query.entries)
      if (e.value != null)
        '${_percentEncode(e.key, _formSafe, spaceAsPlus: true)}=${_percentEncode(_jsString(e.value!), _formSafe, spaceAsPlus: true)}',
  ];
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

/// HTTP 요청 하나를 보내고 응답을 돌려주는 함수입니다. [StorefrontClientOptions.fetch]에 넘깁니다.
///
/// ```dart
/// final client = http.Client();
/// Future<http.Response> fetch(http.Request request) async =>
///     http.Response.fromStream(await client.send(request));
/// ```
typedef Fetch = Future<http.Response> Function(http.Request request);

/// 기본 [Fetch] — `package:http` 클라이언트 하나를 만들어 두고 계속 쓴다(연결 재사용)
Fetch _defaultFetch() {
  final client = http.Client();
  return (request) async => http.Response.fromStream(await client.send(request));
}

/// [Http]의 옵션입니다.
class HttpOptions {
  /// 옵션을 만듭니다.
  const HttpOptions({
    required this.baseUrl,
    this.fetch,
    this.headers,
    this.onResponse,
    this.refresh,
    this.onUnauthorized,
  });

  /// API 주소입니다. 경로를 이 뒤에 붙입니다.
  final String baseUrl;

  /// 요청을 보내는 함수입니다. 생략하면 `package:http`로 보냅니다.
  final Fetch? fetch;

  /// 요청마다 호출해 공통 헤더를 만듭니다.
  final Map<String, String> Function()? headers;

  /// 응답을 받을 때마다 호출합니다.
  final void Function(http.Response response)? onResponse;

  /// 401 시 호출 — true면 요청을 1회 재시도한다
  final Future<bool> Function()? refresh;

  /// 복구 불가능한 401 시 호출
  final void Function()? onUnauthorized;
}

/// 요청 하나의 쿼리·본문·헤더입니다.
class RequestOptions {
  /// 요청 옵션을 만듭니다.
  const RequestOptions({this.query, this.body = absent, this.headers});

  /// 쿼리 파라미터입니다.
  final Query? query;

  /// 보낼 JSON 값. `absent`면 본문을 싣지 않는다
  final Object? body;

  /// 이 요청에만 더할 헤더입니다.
  final Map<String, String>? headers;
}

/// 엔벨로프를 풀고 스키마로 검증하는 HTTP 코어입니다.
class Http {
  /// HTTP 코어를 만듭니다.
  Http(this.options) : _fetch = options.fetch ?? _defaultFetch();

  /// 옵션입니다.
  final HttpOptions options;
  final Fetch _fetch;

  Future<http.Response> _send(String method, String path, RequestOptions? request, {bool retried = false}) async {
    final url = '${options.baseUrl}$path${buildQuery(request?.query)}';
    final hasBody = request != null && request.body != absent;
    final req = http.Request(method, Uri.parse(url));
    req.headers.addAll({
      if (hasBody) 'content-type': 'application/json',
      ...?options.headers?.call(),
      ...?request?.headers,
    });
    if (hasBody) req.bodyBytes = utf8.encode(jsonEncode(request.body));
    final response = await _fetch(req);
    options.onResponse?.call(response);
    if (response.statusCode == 401 && !retried && options.refresh != null) {
      if (await options.refresh!()) return _send(method, path, request, retried: true);
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      if (response.statusCode == 401) options.onUnauthorized?.call();
      Object? raw;
      try {
        raw = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        raw = null;
      }
      throw toApiError(response.statusCode, raw);
    }
    return response;
  }

  /// 요청을 보내고 응답 `data`를 [schema]로 검증해 돌려줍니다.
  Future<T> request<T>(String method, String path, ZodType<T> schema, [RequestOptions? request]) async {
    final response = await _send(method, path, request);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return schema.parse(unwrapData(json));
  }

  /// 요청을 보내고 응답 본문은 읽지 않습니다.
  Future<void> requestVoid(String method, String path, [RequestOptions? request]) async {
    await _send(method, path, request);
  }
}
