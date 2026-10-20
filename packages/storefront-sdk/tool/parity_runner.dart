// Dart SDK로 tool/parity/scenarios.json을 실행하고 요청·결과를 JSON으로 쓴다(node-runner.mjs와 같은 출력 형태).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';

typedef Call = Future<Object?> Function(StorefrontClient client, List<Object?> args);

/// 시나리오의 `call` 이름 → 타입 있는 호출. JSON 인자를 Dart 인자로 바꾼다
final Map<String, Call> calls = {
  'store.get': (c, a) => c.store.get(),
  'catalog.listCategories': (c, a) => c.catalog.listCategories(),
  'catalog.listCollections': (c, a) => c.catalog.listCollections(
      a.isEmpty ? null : PageParams(page: (a[0] as Map)['page'] as int?, size: (a[0] as Map)['size'] as int?)),
  'member.updateConsents': (c, a) {
    final body = a[0] as Map;
    return c.member.updateConsents(ConsentUpdateRequest(
        terms: body['terms'] as bool?, privacy: body['privacy'] as bool?, marketing: body['marketing'] as bool?));
  },
};

Object? toOption(Object? value) => value is Map && value.containsKey(r'$fn') ? () => value[r'$fn'] as String? : value;

Object? encode(Object? value) => switch (value) {
      null => null,
      List() => [for (final v in value) encode(v)],
      _ => jsonDecode(jsonEncode(value)),
    };

Map<String, Object?> describeError(Object error) => switch (error) {
      ApiError() => {
          'type': 'ApiError',
          'status': error.status,
          'code': error.code,
          'message': error.message,
          'traceId': error.traceId,
          'details': error.details,
          'docs': error.docs,
          'body': error.body,
        },
      ZodError() => {
          'type': 'ZodError',
          'issues': [
            for (final i in error.issues) {'code': i.code, 'path': i.path}
          ],
        },
      _ => {'type': 'Error', 'message': '$error'},
    };

Future<void> main(List<String> argv) async {
  final spec = jsonDecode(File(argv.single).readAsStringSync()) as Map<String, Object?>;
  final defaults = (spec['defaults'] as Map)['options'] as Map;
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final requests = <Object?>[];
    final cartTokens = <String>[];
    final o = {...defaults, ...?(s['options'] as Map?)}.map((k, v) => MapEntry(k as String, toOption(v)));
    final r = s['response'] as Map?;
    Future<http.Response> fetch(http.Request req) async {
      final headers = req.headers.map((k, v) => MapEntry(k.toLowerCase(), v));
      requests.add({
        'method': req.method,
        'url': req.url.toString(),
        'headers': Map.fromEntries(headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
        'body': req.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(req.bodyBytes)),
      });
      return http.Response.bytes(
        r!['status'] == 204 ? <int>[] : utf8.encode(jsonEncode(r['body'])),
        r['status'] as int,
        headers: {'content-type': 'application/json', ...?(r['headers'] as Map?)?.cast<String, String>()},
      );
    }

    final auth = o['auth'] as Map?;
    final client = createStorefrontClient(StorefrontClientOptions(
      baseUrl: o['baseUrl'] as String,
      storeCode: o['storeCode'],
      accessToken: o['accessToken'],
      auth: auth == null ? null : (accessToken: auth['accessToken'] as String?),
      cartToken: o['cartToken'],
      visitorId: o['visitorId'],
      sessionId: o['sessionId'],
      country: o['country'],
      host: o['host'],
      locale: o['locale'],
      onCartToken: cartTokens.add,
      fetch: fetch,
    ));
    Map<String, Object?> outcome;
    try {
      final value = await calls[s['call']]!(client, (s['args'] as List).cast<Object?>());
      outcome = {'ok': true, 'value': encode(value)};
    } catch (error) {
      outcome = {'ok': false, 'error': describeError(error)};
    }
    results.add({'name': s['name'], 'requests': requests, 'cartTokens': cartTokens, 'outcome': outcome});
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}
