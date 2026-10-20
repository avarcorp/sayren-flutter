// Dart SDK로 tool/parity/store의 스키마·함수 대조 자료를 실행하고 결과를 JSON으로 쓴다(store/node-runner.mjs와 같은 출력 형태).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:sayren_store_sdk/sayren_store_sdk.dart';
import 'package:sayren_store_sdk/server.dart'
    show
        MemberDelegationError,
        SignWebhookPayloadOptions,
        VerifyWebhookSignatureOptions,
        delegateMember,
        parseWebhookSignatureHeader,
        signWebhookPayload,
        verifyWebhookSignature;
import 'package:sayren_store_sdk/src/zod.dart' show ParsedObject;

import 'functions/all.dart';
import 'hand_calls.dart';
import 'parity_generated.dart';

Object? encode(Object? value) => value == null ? null : jsonDecode(jsonEncode(value, toEncodable: _toEncodable));

Object? _toEncodable(Object? value) => switch (value) {
      Set() => value.toList(),
      ParsedObject() => value.toJson(),
      _ => (value as dynamic).toJson() as Object?,
    };

Object? readJson(String path) => jsonDecode(File(path).readAsStringSync());

Future<void> main(List<String> argv) async {
  final dir = argv.single; // tool/parity
  final schemaCases = (readJson('$dir/generated/store/schema-cases.json') as List).cast<Map<String, Object?>>();
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

  final functionResults = <Object?>[];
  final files = Directory('$dir/store/functions')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    for (final c in (readJson(file.path) as List).cast<Map<String, Object?>>()) {
      final fn = functions[c['fn']];
      Object? outcome;
      if (fn == null) {
        outcome = {'missing': c['fn']};
      } else {
        try {
          outcome = {'value': encode(fn((c['args'] as List).cast<Object?>()))};
        } catch (_) {
          outcome = {'throws': true};
        }
      }
      functionResults.add({'name': '$name ${c['name']}', 'outcome': outcome});
    }
  }

  // 클라이언트 시나리오 — 생성 예시 + 손 시나리오
  final hand = readJson('$dir/store/scenarios.json') as Map<String, Object?>;
  final generated = readJson('$dir/generated/store/scenarios.json') as Map<String, Object?>;
  final defaults = ((hand['defaults'] as Map)['options'] as Map).cast<String, Object?>();
  final scenarioResults = <Object?>[];
  for (final s in [...(hand['scenarios'] as List), ...(generated['scenarios'] as List)].cast<Map<String, Object?>>()) {
    final requests = <Object?>[];
    final queue = (s['responses'] as List?)?.cast<Map<String, Object?>>().toList();
    Future<http.Response> fetch(http.Request req) async {
      requests.add(recordRequest(req));
      final r =
          queue == null ? (s['response'] as Map).cast<String, Object?>() : (queue.isEmpty ? null : queue.removeAt(0));
      return toResponse(r ?? {'status': 500, 'body': null});
    }

    final o = {...defaults, ...?(s['options'] as Map?)?.cast<String, Object?>()};
    final client = createStoreClient(StoreClientOptions(
      baseUrl: o['baseUrl'] as String,
      accessToken: o['accessToken'],
      storeId: o['storeId'],
      fetch: fetch,
    ));
    Map<String, Object?> outcome;
    try {
      final call = handCalls[s['call']] ?? calls[s['call']]!;
      outcome = {'ok': true, 'value': encode(await call(client, (s['args'] as List).cast<Object?>()))};
    } catch (error) {
      outcome = {'ok': false, 'error': describeError(error)};
    }
    scenarioResults.add({'name': s['name'], 'requests': requests, 'outcome': outcome});
  }

  final sessionResults = await runSessions(dir);

  stdout.write(jsonEncode({
    'schemaCases': schemaResults,
    'functions': functionResults,
    'scenarios': scenarioResults,
    'sessions': sessionResults,
    'server': await runServer(dir),
  }));
}

/// 요청 기록 — 폼 본문은 키·값 목록, JSON 본문은 값, 그 밖의 바이트는 `{bytes}`다
Map<String, Object?> recordRequest(http.Request req) {
  final headers = req.headers.map((k, v) => MapEntry(k.toLowerCase(), v));
  Object? body;
  if (req.bodyBytes.isNotEmpty) {
    final type = headers['content-type'];
    if (type == 'application/x-www-form-urlencoded') {
      body = [
        for (final pair in utf8.decode(req.bodyBytes).split('&'))
          if (pair.isNotEmpty)
            [
              Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(0, pair.indexOf('=')) : pair),
              Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(pair.indexOf('=') + 1) : ''),
            ],
      ];
    } else if (type == 'application/json') {
      body = jsonDecode(utf8.decode(req.bodyBytes));
    } else {
      body = {'bytes': req.bodyBytes};
    }
  }
  return {
    'method': req.method,
    'url': req.url.toString(),
    'headers': Map.fromEntries(headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
    'body': body,
  };
}

http.Response toResponse(Map<String, Object?> r) => http.Response.bytes(
      r['status'] == 204 ? <int>[] : utf8.encode(jsonEncode(r['body'])),
      r['status'] as int,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> describeError(Object error) => switch (error) {
      ApprovalPendingError() => {
          'type': 'ApprovalPendingError',
          'code': error.code,
          'httpStatus': error.httpStatus,
          'approvalId': error.approvalId,
          'status': error.status,
          'message': error.message,
        },
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
      StateError() => {'type': 'Error', 'message': error.message},
      _ => {'type': 'Error', 'message': error.toString().replaceFirst('Exception: ', '')},
    };

String _s256(String verifier) =>
    base64Url.encode(crypto.sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');

/// 세션·OAuth 시나리오 — 무작위 값(state·verifier·challenge)은 자리표시로 바꾼다
Future<List<Object?>> runSessions(String dir) async {
  final spec = readJson('$dir/store/session-scenarios.json') as Map<String, Object?>;
  final defaults = (spec['defaults'] as Map).cast<String, Object?>();
  final server = (defaults['authServer'] as Map).cast<String, Object?>();
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final store = <String, String>{...(s['storage'] as Map).cast<String, String>()};
    final storage = _MapStorage(store);
    final secrets = <String, String>{};
    Object? mask(Object? v) {
      var text = jsonEncode(v);
      secrets.forEach((name, value) {
        if (value.isNotEmpty) text = text.split(value).join('<$name>');
      });
      return jsonDecode(text);
    }

    void readPkce() {
      final raw = store['sayren.store.pkce'];
      if (raw == null) return;
      final blob = jsonDecode(raw) as Map<String, Object?>;
      secrets['verifier'] = blob['verifier'] as String;
      secrets['state'] = blob['state'] as String;
      secrets['challenge'] = _s256(blob['verifier'] as String);
    }

    final queue = (s['responses'] as List).cast<Map<String, Object?>>().toList();
    final requests = <Object?>[];
    Future<http.Response> fetch(http.Request req) async {
      requests.add(recordRequest(req));
      return toResponse(queue.isEmpty ? {'status': 500, 'body': null} : queue.removeAt(0));
    }

    final session = createStoreSession(StoreSessionOptions(
      baseUrl: defaults['baseUrl'] as String,
      authServer: StoreAuthServer(
        authorizeUrl: server['authorizeUrl'] as String,
        tokenUrl: server['tokenUrl'] as String,
        revokeUrl: server['revokeUrl'] as String,
        resource: server['resource'] as String?,
      ),
      clientId: defaults['clientId'] as String,
      storage: storage,
      fetch: fetch,
    ));
    var notified = 0;
    session.subscribe(() => notified++);
    final client = createStoreClient(StoreClientOptions(
      baseUrl: defaults['baseUrl'] as String,
      fetch: fetch,
      session: s['noSession'] == true ? null : session,
    ));
    AuthorizeOptions authorizeOptions(Object? v) {
      final m = (v as Map).cast<String, Object?>();
      return AuthorizeOptions(
          redirectUri: m['redirectUri'] as String, scope: m['scope'] as String?, prompt: m['prompt'] as String?);
    }

    final steps = <Object?>[];
    for (final step in (s['steps'] as List).cast<Map<String, Object?>>()) {
      Map<String, Object?> outcome;
      try {
        final args = [for (final a in (step['args'] as List?) ?? const []) a == r'$state' ? secrets['state'] : a];
        Map<String, Object?> m(int i) => (args[i] as Map).cast<String, Object?>();
        Object? value;
        switch (step['op']) {
          case 'authorize':
            value = await session.authorize(authorizeOptions(args[0]));
            readPkce();
          case 'handleCallback':
            await session.handleCallback(args[0] as String, args[1] as String);
          case 'refresh':
            value = await session.refresh();
          case 'refreshTwice':
            value = await Future.wait([session.refresh(), session.refresh()]);
          case 'logout':
            await session.logout();
          case 'clear':
            session.clear();
          case 'setTokens':
            session.setTokens(
                access_token: m(0)['access_token'] as String, refresh_token: m(0)['refresh_token'] as String?);
          case 'getToken':
            value = session.getToken();
          case 'userinfo':
            value = await session.userinfo();
          case 'clientUserinfo':
            value = await client.userinfo();
          case 'clientAuthorize':
            value = await client.authorize(authorizeOptions(args[0]));
            readPkce();
          case 'tokens':
            value = {
              'accessToken': session.accessToken,
              'refreshToken': session.refreshToken,
              'clientAccessToken': client.accessToken,
              'clientRefreshToken': client.refreshToken,
            };
          case 'call':
            value = await calls[step['call']]!(client, args);
          case 'buildAuthorizeUrl':
            final o = m(0);
            value = buildAuthorizeUrl(
              authorizeUrl: o['authorizeUrl'] as String,
              clientId: o['clientId'] as String,
              redirectUri: o['redirectUri'] as String,
              state: o['state'] as String,
              codeChallenge: o['codeChallenge'] as String,
              scope: o['scope'] as String?,
              resource: o['resource'] as String?,
              prompt: o['prompt'] as String?,
            );
          case 'exchangeAuthorizationCode':
            final o = m(0);
            value = await exchangeAuthorizationCode(
              tokenUrl: o['tokenUrl'] as String,
              clientId: o['clientId'] as String,
              redirectUri: o['redirectUri'] as String,
              code: o['code'] as String,
              codeVerifier: o['codeVerifier'] as String,
              resource: o['resource'] as String?,
              fetch: fetch,
            );
          case 'refreshUserToken':
            final o = m(0);
            value = await refreshUserToken(
              tokenUrl: o['tokenUrl'] as String,
              clientId: o['clientId'] as String,
              refreshToken: o['refreshToken'] as String,
              resource: o['resource'] as String?,
              fetch: fetch,
            );
          case 'createPkcePair':
            final pair = await createPkcePair();
            value = {'verifierLength': pair.verifier.length, 'challengeOk': _s256(pair.verifier) == pair.challenge};
        }
        outcome = {'ok': true, 'value': encode(value)};
      } catch (error) {
        outcome = {'ok': false, 'error': describeError(error)};
      }
      await Future<void>.delayed(Duration.zero);
      steps.add(mask({
        'op': step['op'],
        'outcome': outcome,
        'notified': notified,
        'storage': Map.fromEntries(store.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      }));
    }
    results.add({'name': s['name'], 'requests': mask(requests), 'steps': steps});
  }
  return results;
}

class _MapStorage implements SessionStorage {
  _MapStorage(this._values);

  final Map<String, String> _values;

  @override
  String? get(String key) => _values[key];

  @override
  void set(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

/// 서버 엔트리포인트 — 웹훅 서명·파싱·검증, 구매자 위임
Future<List<Object?>> runServer(String dir) async {
  final spec = readJson('$dir/store/server-scenarios.json') as Map<String, Object?>;
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final a = (s['args'] as Map).cast<String, Object?>();
    final queue = ((s['responses'] as List?) ?? const []).cast<Map<String, Object?>>().toList();
    final requests = <Object?>[];
    Future<http.Response> fetch(http.Request req) async {
      requests.add(recordRequest(req));
      final r = queue.isEmpty ? <String, Object?>{'status': 500, 'body': null} : queue.removeAt(0);
      return r.containsKey('raw') ? http.Response(r['raw'] as String, r['status'] as int) : toResponse(r);
    }

    Object secret(Object? v) => v is List ? v.cast<String>() : v as String;
    Map<String, Object?> outcome;
    try {
      Object? value;
      switch (s['op']) {
        case 'sign':
          value = await signWebhookPayload(SignWebhookPayloadOptions(
              payload: a['payload'] as String, secret: secret(a['secret']), timestamp: a['timestamp'] as int?));
        case 'parse':
          value = parseWebhookSignatureHeader(a['header'] as String?);
        case 'verify':
          value = await verifyWebhookSignature(VerifyWebhookSignatureOptions(
            payload: a['payload'] as String,
            header: a['header'] as String?,
            secret: secret(a['secret']),
            toleranceSec: a['toleranceSec'] as int?,
            now: DateTime.parse(a['now'] as String),
          ));
        case 'roundtrip':
          final header = await signWebhookPayload(SignWebhookPayloadOptions(
              payload: a['payload'] as String, secret: secret(a['signSecret']), timestamp: a['timestamp'] as int?));
          value = await verifyWebhookSignature(VerifyWebhookSignatureOptions(
            payload: (a['verifyPayload'] ?? a['payload']) as String,
            header: header,
            secret: secret(a['verifySecret']),
            toleranceSec: a['toleranceSec'] as int?,
            now: DateTime.parse(a['now'] as String),
          ));
        case 'delegate':
          value = await delegateMember(
            baseUrl: a['baseUrl'] as String,
            accessToken: a['accessToken'] as String,
            storeId: a['storeId'] as String,
            uid: a['uid'] as String?,
            email: a['email'] as String?,
            name: a['name'] as String?,
            authenticatedAt: a['authenticatedAt'] == null ? null : DateTime.parse(a['authenticatedAt'] as String),
            fetch: fetch,
          );
      }
      outcome = {'ok': true, 'value': encode(value)};
    } on MemberDelegationError catch (e) {
      outcome = {
        'ok': false,
        'error': {
          'type': 'MemberDelegationError',
          'error': e.error,
          'description': e.description,
          'status': e.status,
          'message': e.message,
        },
      };
    } on ArgumentError catch (e) {
      outcome = {
        'ok': false,
        'error': {'type': 'Error', 'message': e.message}
      };
    }
    results.add({'name': s['name'], 'requests': requests, 'outcome': outcome});
  }
  return results;
}
