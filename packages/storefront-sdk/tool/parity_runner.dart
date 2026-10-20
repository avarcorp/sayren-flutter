// Dart SDK로 tool/parity의 시나리오·스키마 대조 자료를 실행하고 결과를 JSON으로 쓴다(node-runner.mjs와 같은 출력 형태).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:sayren_storefront_sdk/auth.dart'
    show createStorefrontAuth, StorefrontAuth, StorefrontAuthOptions, IdpCallbackError, IdpStart;
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';
// Flutter 없이 돌도록 핵심 로직 파일만 불러온다
import 'package:sayren_storefront_sdk/src/analytics/index.dart';
import 'package:sayren_storefront_sdk/src/payments/index.dart';
import 'package:sayren_storefront_sdk/src/payments/launch.dart';

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
  final authResults = await runAuth(readJson(dir, 'auth-scenarios.json') as Map<String, Object?>);
  final analyticsResults = runAnalytics(readJson(dir, 'analytics-scenarios.json') as Map<String, Object?>);
  final paymentResults = await runPayments(readJson(dir, 'payments-scenarios.json') as Map<String, Object?>);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'scenarios': scenarioResults,
    'schemaCases': schemaResults,
    'sessions': sessionResults,
    'auth': authResults,
    'analytics': analyticsResults,
    'payments': paymentResults,
  }));
}

class _NoWindowEnv implements PaymentsEnv {
  @override
  Future<({String? returnUrl, LaunchFailure? failure})> present(
          {String? html, String? url, required String baseUrl, required String returnUrl}) =>
      throw StateError('결제창을 열지 않는 시나리오다');
  @override
  String? currentUrl() => null;
  @override
  DateTime now() => DateTime.utc(2026);
  @override
  Future<void> wait(Duration duration) async {}
}

String _cut(String s) => s.length > 120 ? s.substring(0, 120) : s;

Future<List<Object?>> runPayments(Map<String, Object?> spec) async {
  final results = <Object?>[];
  for (final url in (spec['urls'] as List).cast<String>()) {
    results.add(
        {'name': 'readPaymentReturn ${_cut(url)}', 'value': readPaymentReturn(firstParams(Uri.parse(url))).toJson()});
    results.add({'name': 'scrubReturnUrl ${_cut(url)}', 'value': scrubReturnUrl(url)});
  }
  for (final status in (spec['statuses'] as List).cast<Map<String, Object?>>()) {
    final parsed = PaymentStatus.fromJson(status);
    results.add({'name': 'paymentResultOf ${status['result']}', 'value': paymentResultOf(parsed).toJson()});
    results.add({
      'name': 'paymentResultOf ${status['result']} closed',
      'value': paymentResultOf(parsed, popupClosed: true).toJson(),
    });
  }
  for (final m in (spec['modes'] as List).cast<List<Object?>>()) {
    final d = _m(m[1]);
    results.add({
      'name': 'resolvePaymentMode ${m[0]} ${d['userAgent']}',
      'value': resolvePaymentMode(
          m[0] as String?,
          PaymentDevice(
              userAgent: d['userAgent'] as String,
              coarsePointer: d['coarsePointer'] as bool,
              viewportWidth: d['viewportWidth'] as num)),
    });
  }
  for (final f in (spec['flows'] as List).cast<Map<String, Object?>>()) {
    final queue = [...(f['responses'] as List).cast<Map<String, Object?>>()];
    final requests = <Object?>[];
    Future<http.Response> fetch(http.Request req) async {
      requests.add({
        'method': req.method,
        'url': req.url.toString(),
        'body': req.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(req.bodyBytes)),
      });
      final r = queue.isEmpty ? <String, Object?>{'status': 500, 'body': null} : queue.removeAt(0);
      return http.Response.bytes(r['status'] == 204 ? <int>[] : utf8.encode(jsonEncode(r['body'])), r['status'] as int,
          headers: {'content-type': 'application/json'});
    }

    final client = createStorefrontClient(
        StorefrontClientOptions(baseUrl: 'https://api.example.test/storefront/v1', storeCode: 'demo', fetch: fetch));
    final payments = createPaymentsWith(
        PaymentsOptions(client: client, returnUrl: spec['returnUrl'] as String, env: _NoWindowEnv()), _NoWindowEnv());
    Map<String, Object?> outcome;
    try {
      final PaymentResult value;
      if (f['op'] == 'result') {
        value = await payments.result(f['url'] as String);
      } else {
        final args = f['args'] as List;
        final o = _m(args[1]);
        value = await payments.start(
          args[0] as String,
          StartOptions(
            option: o['option'] == null ? null : PaymentOption.fromJson(_m(o['option'])),
            coupons: (o['coupons'] as List?)?.map((c) => CouponApplication.fromJson(_m(c))).toList(),
            pointAmount: o['pointAmount'] as int?,
          ),
        );
      }
      outcome = {'ok': true, 'value': value.toJson()};
    } catch (error) {
      outcome = {'ok': false, 'error': describeError(error)};
    }
    results.add({'name': 'flow ${f['name']}', 'requests': requests, 'outcome': outcome});
  }
  return results;
}

class _FakeAnalyticsEnv implements AnalyticsEnv {
  _FakeAnalyticsEnv(this.c, Map<String, String> initial)
      : href_ = c['href'] as String,
        visible_ = c['visible'] as bool,
        prerendering_ = (c['prerendering'] as bool?) ?? false {
    initial.forEach((k, v) => cookies[k] = (v, 1 << 53));
  }

  final Map<String, Object?> c;
  int now_ = DateTime.utc(2026).millisecondsSinceEpoch;
  String href_;
  bool visible_;
  bool prerendering_;
  int ids = 0;
  final cookies = <String, (String, int)>{};
  final sent = <Object?>[];
  final listeners = <String, Set<void Function()>>{
    for (final k in ['visibilitychange', 'pagehide', 'prerenderingchange', 'navigate', 'interval']) k: {},
  };

  void Function() sub(String key, void Function() fn) {
    listeners[key]!.add(fn);
    return () => listeners[key]!.remove(fn);
  }

  void emit(String key) {
    for (final fn in List.of(listeners[key]!)) {
      fn();
    }
  }

  @override
  int now() => now_;
  @override
  String href() => href_;
  @override
  String referrer() => c['referrer'] as String;
  @override
  String hostname() => c['hostname'] as String;
  @override
  String? getCookie(String name) {
    final e = cookies[name];
    return e != null && e.$2 > now_ ? e.$1 : null;
  }

  @override
  void setCookie(String name, String value, int maxAgeSec, [String? domain]) =>
      cookies[name] = (value, now_ + maxAgeSec * 1000);
  @override
  void send(String url, String body) => sent.add({'url': url, 'body': jsonDecode(body)});
  @override
  String randomId() => 'rid${(++ids).toString().padLeft(13, '0')}';
  @override
  bool visible() => visible_;
  @override
  bool prerendering() => prerendering_;
  @override
  bool webdriver() => (c['webdriver'] as bool?) ?? false;
  @override
  void Function() on(String event, void Function() fn) => sub(event, fn);
  @override
  void Function() onNavigate(void Function() fn) => sub('navigate', fn);
  @override
  void Function() setInterval(void Function() fn, int ms) => sub('interval', fn);
}

AnalyticsTrackInput _trackInput(Map<String, Object?> j) => switch (j['name']) {
      'product_view' =>
        AnalyticsTrackInputProductView(productId: j['productId'] as String, variantId: j['variantId'] as String?),
      'product_list_view' => AnalyticsTrackInputProductListView(
          listId: j['listId'] as String, productIds: (j['productIds'] as List).cast<String>()),
      'search' => AnalyticsTrackInputSearch(query: j['query'] as String, resultCount: j['resultCount'] as int),
      _ => throw StateError('알 수 없는 이벤트 ${j['name']}'),
    };

List<Object?> runAnalytics(Map<String, Object?> spec) {
  final defaults = (spec['defaults'] as Map).cast<String, Object?>();
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final c = {...defaults, ...s};
    final env = _FakeAnalyticsEnv(c, ((s['cookies'] as Map?) ?? const {}).cast<String, String>());
    final o = (s['options'] as Map).cast<String, Object?>();
    final analytics = createAnalyticsWith(
      AnalyticsOptions(
        baseUrl: c['baseUrl'] as String,
        storeCode: c['storeCode'] as String,
        consent: o['consent'] as String?,
        autoPageViews: o['autoPageViews'] as bool?,
        debug: o['debug'] as bool?,
        flushIntervalMs: o['flushIntervalMs'] as int?,
      ),
      env,
    );
    final steps = <Object?>[];
    for (final step in (s['steps'] as List).cast<Map<String, Object?>>()) {
      Object? value;
      switch (step['op']) {
        case 'track':
          analytics.track(_trackInput((step['input'] as Map).cast<String, Object?>()));
        case 'page':
          analytics.page();
        case 'setConsent':
          analytics.setConsent(step['value'] as String);
        case 'ids':
          final ids = analytics.ids();
          value = ids == null ? null : {'visitorId': ids.visitorId, 'sessionId': ids.sessionId};
        case 'flush':
          analytics.flush();
        case 'destroy':
          analytics.destroy();
        case 'advance':
          env.now_ += step['ms'] as int;
        case 'navigate':
          env.href_ = step['href'] as String;
          env.emit('navigate');
        case 'visibility':
          env.visible_ = step['visible'] as bool;
          env.emit('visibilitychange');
        case 'pagehide':
          env.emit('pagehide');
        case 'prerenderDone':
          env.prerendering_ = false;
          env.emit('prerenderingchange');
        case 'interval':
          env.emit('interval');
      }
      steps.add({'op': step['op'], 'value': value, 'sent': env.sent.length});
    }
    final cookieKeys = env.cookies.keys.toList()..sort();
    results.add({
      'name': s['name'],
      'steps': steps,
      'sent': env.sent,
      'cookies': {for (final k in cookieKeys) k: env.cookies[k]!.$1},
      'listeners': {for (final e in env.listeners.entries) e.key: e.value.length},
    });
  }
  return results;
}

String _s256(String v) => base64Url.encode(crypto.sha256.convert(utf8.encode(v)).bytes).replaceAll('=', '');

Map<String, Object?> _m(Object? v) => (v as Map).cast<String, Object?>();

/// createStorefrontAuth 시나리오의 메서드 → 타입 있는 호출
final Map<String, Future<Object?> Function(StorefrontAuth auth, List<Object?> a)> authCalls = {
  'anonymous': (x, a) => x.anonymous(),
  'session': (x, a) => x.session(LoginRequest.fromJson(_m(a[0]))),
  'signUp': (x, a) => x.signUp(SignupRequest.fromJson(_m(a[0]))),
  'idp': (x, a) {
    final o = _m(a[1]);
    final agreements = o['agreements'] as Map?;
    return x.idp(a[0] as String,
        redirectUri: o['redirectUri'] as String,
        agreements: agreements == null
            ? null
            : (
                terms: agreements['terms'] as bool,
                privacy: agreements['privacy'] as bool,
                marketing: agreements['marketing'] as bool?
              ));
  },
  'idpCallback': (x, a) {
    final o = _m(a[0]);
    return x.idpCallback(
        code: o['code'] as String?,
        state: o['state'] as String?,
        expectedState: o['expectedState'] as String,
        codeVerifier: o['codeVerifier'] as String,
        cartToken: o['cartToken'] as String?,
        error: o['error'] as String?);
  },
  'identities': (x, a) => x.identities(a[0] as String),
  'linkIdp': (x, a) => x.linkIdp(a[0] as String, a[1] as String, redirectUri: _m(a[2])['redirectUri'] as String),
  'linkIdpCallback': (x, a) {
    final o = _m(a[2]);
    return x.linkIdpCallback(a[0] as String, a[1] as String,
        code: o['code'] as String?,
        state: o['state'] as String?,
        expectedState: o['expectedState'] as String,
        codeVerifier: o['codeVerifier'] as String,
        error: o['error'] as String?);
  },
  'unlinkIdp': (x, a) => x.unlinkIdp(a[0] as String, a[1] as String),
  'refresh': (x, a) => x.refresh(a[0] as String),
  'signOut': (x, a) => x.signOut(a[0] as String).then((_) => null),
  'withdraw': (x, a) => x.withdraw(a[0] as String, WithdrawRequest.fromJson(_m(a[1]))).then((_) => null),
};

Future<List<Object?>> runAuth(Map<String, Object?> spec) async {
  final defaults = spec['defaults'] as Map;
  final results = <Object?>[];
  for (final s in (spec['scenarios'] as List).cast<Map<String, Object?>>()) {
    final queue = [...(s['responses'] as List).cast<Map<String, Object?>>()];
    final requests = <Map<String, Object?>>[];
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

    final auth = createStorefrontAuth(StorefrontAuthOptions(
        baseUrl: defaults['baseUrl'] as String, storeCode: defaults['storeCode'] as String, fetch: fetch));
    Map<String, Object?> outcome;
    Object? value;
    try {
      value = await authCalls[s['method']]!(auth, (s['args'] as List).cast<Object?>());
      outcome = {'ok': true, 'value': value is IdpStart ? null : encode(value)};
    } on IdpCallbackError catch (error) {
      outcome = {
        'ok': false,
        'error': {'type': 'IdpCallbackError', 'reason': error.reason, 'message': error.message},
      };
    } catch (error) {
      outcome = {'ok': false, 'error': describeError(error)};
    }
    var shownRequests = requests;
    if (value is IdpStart) {
      final body = (requests.first['body'] as Map?) ?? const {};
      outcome = {
        'ok': true,
        'value': {
          'url': value.url,
          'pkce': {
            'stateLength': value.state.length,
            'verifierLength': value.codeVerifier.length,
            'stateSent': body['state'] == value.state,
            'challengeIsS256': body['codeChallenge'] == _s256(value.codeVerifier),
          },
        },
      };
      shownRequests = [
        for (final r in requests)
          {
            ...r,
            'body':
                r['body'] == null ? null : {...(r['body'] as Map), 'state': '<state>', 'codeChallenge': '<challenge>'},
          },
      ];
    }
    results.add({'name': s['name'], 'requests': shownRequests, 'outcome': outcome});
  }
  return results;
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
