// 손으로 쓴 파일 — Node src/analytics/index.ts의 createAnalytics(기본 환경)에 대응한다. Flutter 기본 환경이다.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter/navigator.dart';
import 'index.dart';

/// 방문 분석을 만듭니다. Flutter 앱의 기본 환경을 사용합니다.
///
/// - 방문자·세션 ID는 쿠키 대신 앱 저장소(`shared_preferences`)에 둡니다. 만료(방문자 1년, 세션 30분 비활동)는 같습니다.
/// - 페이지뷰는 루트 Navigator의 화면 이름(`RouteSettings.name`)이 바뀔 때 보냅니다. 주소는 `app://{storeCode}{화면 이름}`입니다.
///   이름 없는 화면만 쓰거나 다른 방식으로 이동하면 `autoPageViews: false`로 두고 화면마다 [Analytics.page]를 부르십시오.
/// - 앱이 백그라운드로 가면 체류를 마감하고 큐를 보냅니다.
///
/// ```dart
/// final analytics = createAnalytics(AnalyticsOptions(baseUrl: baseUrl, storeCode: storeCode));
/// analytics.setConsent('granted'); // 동의 화면에서
/// analytics.track(const AnalyticsTrackInputProductView(productId: 'prod_1'));
/// ```
Analytics createAnalytics(AnalyticsOptions options) => createAnalyticsWith(options, _FlutterAnalyticsEnv(options));

final _random = Random.secure();

class _FlutterAnalyticsEnv with WidgetsBindingObserver implements AnalyticsEnv {
  _FlutterAnalyticsEnv(this.options) {
    WidgetsFlutterBinding.ensureInitialized().addObserver(this);
    unawaited(_load());
  }

  final AnalyticsOptions options;
  final _client = http.Client();

  /// 이름 → (값, 만료 시각 ms). 저장소를 다 읽기 전에도 동기로 읽고 쓴다
  final _values = <String, (String, int)>{};
  SharedPreferences? _prefs;
  static const _prefix = 'sayren.analytics.';
  final _listeners = <String, Set<void Function()>>{};
  AppLifecycleState? _state = WidgetsBinding.instance.lifecycleState;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      final raw = prefs.getString(key);
      final cut = raw?.lastIndexOf('|') ?? -1;
      if (raw == null || cut < 0) continue;
      final name = key.substring(_prefix.length);
      // 읽기 전에 이미 새로 만든 값이 있으면 그 값을 둔다
      _values.putIfAbsent(name, () => (raw.substring(0, cut), int.tryParse(raw.substring(cut + 1)) ?? 0));
    }
  }

  @override
  int now() => DateTime.now().millisecondsSinceEpoch;

  @override
  String href() {
    final name = currentRouteName() ?? '/';
    return 'app://${options.storeCode}${name.startsWith('/') ? name : '/$name'}';
  }

  @override
  String referrer() => '';

  @override
  String hostname() => options.storeCode;

  @override
  String? getCookie(String name) {
    final entry = _values[name];
    if (entry == null || entry.$2 <= now()) return null;
    return entry.$1;
  }

  @override
  void setCookie(String name, String value, int maxAgeSec, [String? domain]) {
    final expires = now() + maxAgeSec * 1000;
    _values[name] = (value, expires);
    unawaited(_prefs?.setString('$_prefix$name', '$value|$expires'));
  }

  @override
  void send(String url, String body) {
    unawaited(_client
        .post(Uri.parse(url), headers: {'content-type': 'text/plain;charset=UTF-8'}, body: body)
        .then<void>((_) {}, onError: (_) {}));
  }

  @override
  String randomId() => base64Url.encode([for (var i = 0; i < 16; i++) _random.nextInt(256)]).replaceAll('=', '');

  @override
  bool visible() => _state == null || _state == AppLifecycleState.resumed;

  @override
  bool prerendering() => false;

  @override
  bool webdriver() => false;

  @override
  void Function() on(String event, void Function() fn) {
    (_listeners[event] ??= {}).add(fn);
    return () => _listeners[event]?.remove(fn);
  }

  void _emit(String event) {
    for (final fn in List.of(_listeners[event] ?? const <void Function()>{})) {
      fn();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = visible();
    _state = state;
    if (wasVisible != visible()) _emit('visibilitychange');
    if (state == AppLifecycleState.detached) _emit('pagehide');
  }

  @override
  void Function() onNavigate(void Function() fn) {
    // 루트 Navigator 맨 위 화면 이름을 살펴 바뀌면 알린다(Navigator에 관찰자를 붙이지 않아도 되게)
    var last = currentRouteName();
    final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final name = currentRouteName();
      if (name != last) {
        last = name;
        fn();
      }
    });
    return timer.cancel;
  }

  @override
  void Function() setInterval(void Function() fn, int ms) {
    final timer = Timer.periodic(Duration(milliseconds: ms), (_) => fn());
    return timer.cancel;
  }
}
