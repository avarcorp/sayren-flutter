// Dart SDK로 tool/parity의 시나리오·스키마 대조 자료를 실행하고 결과를 JSON으로 쓴다(node-runner.mjs와 같은 출력 형태).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';

import 'parity_generated.dart';

Object? toOption(Object? value) => value is Map && value.containsKey(r'$fn') ? () => value[r'$fn'] as String? : value;

Object? encode(Object? value) => value == null ? null : jsonDecode(jsonEncode(value));

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
      _ => {'type': 'Error'},
    };

Object? readJson(String dir, String file) => jsonDecode(File('$dir/$file').readAsStringSync());

Future<void> main(List<String> argv) async {
  final dir = argv.single;
  final hand = readJson(dir, 'scenarios.json') as Map<String, Object?>;
  final generated = readJson(dir, 'generated/scenarios.json') as Map<String, Object?>;
  final schemaCases = (readJson(dir, 'generated/schema-cases.json') as List).cast<Map<String, Object?>>();
  final defaults = (hand['defaults'] as Map)['options'] as Map;
  final scenarios = [...(hand['scenarios'] as List), ...(generated['scenarios'] as List)].cast<Map<String, Object?>>();

  final scenarioResults = <Object?>[];
  for (final s in scenarios) {
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
    scenarioResults.add({'name': s['name'], 'requests': requests, 'cartTokens': cartTokens, 'outcome': outcome});
  }

  final schemaResults = [
    for (final c in schemaCases)
      () {
        final r = schemas[c['schema']]!.safeParse(c['input']);
        return {
          'name': '${c['schema']} ${c['label']}',
          'outcome': r.success
              ? {'ok': true, 'value': encode(r.data)}
              : {
                  'ok': false,
                  'issues': [
                    for (final i in r.error!.issues) {'code': i.code, 'path': i.path}
                  ],
                },
        };
      }(),
  ];
  final sessionResults = await runSessions(readJson(dir, 'session-scenarios.json') as Map<String, Object?>);
  stdout.writeln(const JsonEncoder.withIndent('  ')
      .convert({'scenarios': scenarioResults, 'schemaCases': schemaResults, 'sessions': sessionResults}));
}

class _MapStorage implements SessionStorage {
  _MapStorage(this.values);

  final Map<String, String> values;

  @override
  String? get(String key) => values[key];

  @override
  void set(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}

Future<List<Object?>> runSessions(Map<String, Object?> spec) async {
  final defaults = spec['defaults'] as Map;
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final store = (s['storage'] as Map).cast<String, String>();
    final storage = _MapStorage({...store});
    final queue = [...(s['responses'] as List).cast<Map<String, Object?>>()];
    final requests = <Object?>[];
    Future<http.Response> fetch(http.Request req) async {
      final headers = req.headers.map((k, v) => MapEntry(k.toLowerCase(), v));
      requests.add({
        'method': req.method,
        'url': req.url.toString(),
        'headers': Map.fromEntries(headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
        'body': req.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(req.bodyBytes)),
      });
      final r = queue.isEmpty ? <String, Object?>{'status': 500, 'body': null} : queue.removeAt(0);
      return http.Response.bytes(r['status'] == 204 ? <int>[] : utf8.encode(jsonEncode(r['body'])), r['status'] as int,
          headers: {'content-type': 'application/json'});
    }

    final session = createStorefrontSession(StorefrontSessionOptions(
        baseUrl: defaults['baseUrl'] as String,
        storeCode: defaults['storeCode'] as String?,
        storage: storage,
        fetch: fetch));
    var notified = 0;
    session.subscribe(() => notified++);
    final client = createStorefrontClient(StorefrontClientOptions(
        baseUrl: defaults['baseUrl'] as String,
        storeCode: defaults['storeCode'],
        fetch: fetch,
        session: s['noSession'] == true ? null : session));
    final steps = <Object?>[];
    for (final step in (s['steps'] as List).cast<Map<String, Object?>>()) {
      Map<String, Object?> outcome;
      try {
        final args = (step['args'] as List?)?.cast<Object?>() ?? const [];
        final Object? value = switch (step['op']) {
          'login' =>
            await session.login(LoginRequest.fromJson((args[0] as Map).cast<String, Object?>())).then((_) => null),
          'signup' =>
            await session.signup(SignupRequest.fromJson((args[0] as Map).cast<String, Object?>())).then((_) => null),
          'refresh' => await session.refresh(),
          'refreshTwice' => await Future.wait([session.refresh(), session.refresh()]),
          'userinfo' => await session.userinfo(),
          'clientUserinfo' => await client.userinfo(),
          'clear' => () {
              session.clear();
              return null;
            }(),
          'tokens' => {
              'accessToken': session.accessToken,
              'refreshToken': session.refreshToken,
              'clientAccessToken': client.accessToken,
            },
          'call' => await calls[step['call']]!(client, args),
          _ => throw StateError('알 수 없는 단계 ${step['op']}'),
        };
        outcome = {'ok': true, 'value': encode(value)};
      } catch (error) {
        outcome = {'ok': false, 'error': describeError(error)};
      }
      await Future<void>.delayed(Duration.zero);
      steps.add({
        'op': step['op'],
        'outcome': outcome,
        'notified': notified,
        'storage': Map.fromEntries(storage.values.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      });
    }
    results.add({'name': s['name'], 'requests': requests, 'steps': steps});
  }
  return results;
}
