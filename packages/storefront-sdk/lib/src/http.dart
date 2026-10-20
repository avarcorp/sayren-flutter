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

class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message, [this.traceId, this.body, this.details, this.docs]);

  final int status;
  final String code;
  final String message;
  final String? traceId;
  final Object? body;

  /// 엔벨로프 `$.error.details` — 에러 코드별 보조 데이터. 없으면 null
  final Map<String, Object?>? details;

  /// 엔벨로프 `$.error.docs` — 이 에러 코드를 설명하는 문서 URL. 매핑이 없으면 null
  final String? docs;

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

/// `string` 또는 `string Function()` — 함수면 매 요청마다 다시 읽는다
typedef TokenSource = Object?;

String? resolveToken(TokenSource source) {
  if (source == null || source is String) return source as String?;
  if (source is String? Function()) return source();
  throw ArgumentError.value(source, 'source', 'String 또는 String? Function()이어야 합니다');
}

typedef Query = Map<String, Object?>;

/// JS `String(value)` — 정수인 double은 소수점 없이 쓴다
String _jsString(Object value) => value is double && value == value.truncateToDouble() && value.isFinite
    ? value.toInt().toString()
    : value.toString();

/// `URLSearchParams`와 같은 인코딩으로 쿼리 문자열을 만든다. null 값은 뺀다
String buildQuery([Query? query]) {
  if (query == null) return '';
  final parts = [
    for (final e in query.entries)
      if (e.value != null)
        '${_percentEncode(e.key, _formSafe, spaceAsPlus: true)}=${_percentEncode(_jsString(e.value!), _formSafe, spaceAsPlus: true)}',
  ];
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}

/// Node `fetch` 옵션의 대응 — 요청 하나를 보내고 응답을 받는다
typedef Fetch = Future<http.Response> Function(http.Request request);

Future<http.Response> _defaultFetch(http.Request request) async {
  final client = http.Client();
  try {
    return await http.Response.fromStream(await client.send(request));
  } finally {
    client.close();
  }
}

class HttpOptions {
  const HttpOptions({
    required this.baseUrl,
    this.fetch,
    this.headers,
    this.onResponse,
    this.refresh,
    this.onUnauthorized,
  });

  final String baseUrl;
  final Fetch? fetch;
  final Map<String, String> Function()? headers;
  final void Function(http.Response response)? onResponse;

  /// 401 시 호출 — true면 요청을 1회 재시도한다
  final Future<bool> Function()? refresh;

  /// 복구 불가능한 401 시 호출
  final void Function()? onUnauthorized;
}

class RequestOptions {
  const RequestOptions({this.query, this.body = absent, this.headers});

  final Query? query;

  /// 보낼 JSON 값. `absent`면 본문을 싣지 않는다
  final Object? body;
  final Map<String, String>? headers;
}

class Http {
  Http(this.options) : _fetch = options.fetch ?? _defaultFetch;

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

  Future<T> request<T>(String method, String path, ZodType<T> schema, [RequestOptions? request]) async {
    final response = await _send(method, path, request);
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return schema.parse(unwrapData(json));
  }

  Future<void> requestVoid(String method, String path, [RequestOptions? request]) async {
    await _send(method, path, request);
  }
}
