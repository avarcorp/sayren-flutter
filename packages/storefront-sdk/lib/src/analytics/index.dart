// 손으로 쓴 파일 — Node src/analytics/index.ts의 createAnalyticsWith(순수 로직)에 대응한다.
// Flutter 기본 환경과 createAnalytics는 flutter.dart에 있다(이 파일은 Flutter를 import하지 않는다).
import 'dart:convert';

import '../schemas/analytics.dart';

/// 분석 동의 상태입니다. `granted`(동의)·`denied`(거부)·`pending`(대기)입니다.
///
/// `pending`이면 ID를 만들지 않고 이벤트를 큐에만 쌓습니다. `denied`면 이벤트를 버립니다.
typedef AnalyticsConsent = String;

/// [createAnalytics]에 넘기는 옵션입니다.
///
/// @docImport 'flutter.dart';
class AnalyticsOptions {
  /// 옵션을 만듭니다.
  const AnalyticsOptions({
    required this.baseUrl,
    required this.storeCode,
    this.consent,
    this.autoPageViews,
    this.debug,
    this.cookieDomain,
    this.flushIntervalMs,
  });

  /// 스토어프론트 API 주소입니다. 예: `https://api.sayren.io/storefront/v1`
  final String baseUrl;

  /// 상점 코드입니다.
  final String storeCode;

  /// 동의 상태입니다. 기본은 `pending`이고, 앱의 동의 화면이 [Analytics.setConsent]로 바꿉니다.
  final AnalyticsConsent? consent;

  /// 페이지뷰를 자동으로 보내는지입니다. 기본은 true입니다(첫 화면과 화면 이동).
  final bool? autoPageViews;

  /// 개발 호스트(localhost 등)에서도 보내는지입니다. 기본은 false입니다.
  final bool? debug;

  /// 쿠키 도메인입니다. 브라우저 환경에서만 의미가 있고, Flutter 기본 환경은 사용하지 않습니다.
  final String? cookieDomain;

  /// 배치 전송 간격(밀리초)입니다. 기본은 5000입니다.
  final int? flushIntervalMs;
}

/// [Analytics.track]에 넘기는 행동 이벤트입니다. 형태는 [name]으로 나뉩니다.
sealed class AnalyticsTrackInput {
  const AnalyticsTrackInput();

  /// 이벤트 이름입니다. `product_view`·`product_list_view`·`search`입니다.
  String get name;
}

/// 상품 조회 이벤트입니다(`product_view`).
final class AnalyticsTrackInputProductView extends AnalyticsTrackInput {
  /// 이벤트를 만듭니다.
  const AnalyticsTrackInputProductView({required this.productId, this.variantId});

  @override
  String get name => 'product_view';

  /// 상품 ID입니다.
  final String productId;

  /// 옵션 조합 ID입니다. 없으면 null입니다.
  final String? variantId;
}

/// 상품 목록 노출 이벤트입니다(`product_list_view`).
final class AnalyticsTrackInputProductListView extends AnalyticsTrackInput {
  /// 이벤트를 만듭니다.
  const AnalyticsTrackInputProductListView({required this.listId, required this.productIds});

  @override
  String get name => 'product_list_view';

  /// 목록 ID입니다(예: 컬렉션 slug).
  final String listId;

  /// 노출한 상품 ID입니다. 앞에서부터 100개만 보냅니다.
  final List<String> productIds;
}

/// 검색 이벤트입니다(`search`).
final class AnalyticsTrackInputSearch extends AnalyticsTrackInput {
  /// 이벤트를 만듭니다.
  const AnalyticsTrackInputSearch({required this.query, required this.resultCount});

  @override
  String get name => 'search';

  /// 검색어입니다. 앞에서부터 200자만 보냅니다.
  final String query;

  /// 결과 수입니다.
  final int resultCount;
}

/// 방문 분석입니다. [createAnalytics]로 만듭니다.
abstract interface class Analytics {
  /// 행동 이벤트를 보냅니다. 같은 페이지뷰 안의 같은 행동은 한 번만 보냅니다.
  void track(AnalyticsTrackInput input);

  /// 페이지뷰를 직접 보냅니다. `autoPageViews: false`일 때 사용합니다.
  void page();

  /// 동의 상태를 바꿉니다. `granted`면 쌓아 둔 이벤트를 보내고, `denied`면 버립니다.
  void setConsent(AnalyticsConsent consent);

  /// 방문자·세션 ID입니다. [StorefrontClientOptions.visitorId]·`sessionId`에 넘깁니다. 동의 전이나 거부면 null입니다.
  ///
  /// @docImport '../client.dart';
  ({String visitorId, String sessionId})? ids();

  /// 큐를 지금 보냅니다.
  void flush();

  /// 리스너·타이머를 걷습니다.
  void destroy();
}

/// [createAnalyticsWith]에 넣는 실행 환경입니다. 테스트는 가짜 환경을 넣습니다.
///
/// 멤버는 Node SDK와 같습니다. Flutter 앱은 [createAnalytics]가 Flutter 기본 환경을 사용합니다.
abstract interface class AnalyticsEnv {
  /// 현재 시각(밀리초)입니다.
  int now();

  /// 현재 화면 주소입니다.
  String href();

  /// 유입 주소입니다. 없으면 빈 문자열입니다.
  String referrer();

  /// 현재 호스트입니다. 개발 호스트면 기본으로 보내지 않습니다.
  String hostname();

  /// 저장한 ID를 읽습니다. 없거나 만료됐으면 null입니다.
  String? getCookie(String name);

  /// ID를 [maxAgeSec]초 동안 저장합니다.
  void setCookie(String name, String value, int maxAgeSec, [String? domain]);

  /// 배치를 보냅니다. 결과를 기다리지 않습니다.
  void send(String url, String body);

  /// 무작위 ID를 만듭니다.
  String randomId();

  /// 화면이 보이는지입니다.
  bool visible();

  /// 미리 그리는 중인지입니다.
  bool prerendering();

  /// 자동화 도구가 띄운 화면인지입니다.
  bool webdriver();

  /// 화면 숨김(`visibilitychange`)·떠남(`pagehide`)·미리 그리기 끝(`prerenderingchange`)을 구독합니다. 해지 함수를 돌려줍니다.
  void Function() on(String event, void Function() fn);

  /// 화면 이동을 구독합니다. 해지 함수를 돌려줍니다.
  void Function() onNavigate(void Function() fn);

  /// [ms]마다 [fn]을 부릅니다. 해지 함수를 돌려줍니다.
  void Function() setInterval(void Function() fn, int ms);
}

const _visitorMaxAgeSec = 365 * 24 * 3600;
const _sessionMaxAgeSec = 30 * 60;

/// 세션을 시작한 캠페인 — 다른 캠페인으로 들어오면 새 세션이다
const _sessionCampaignCookie = 'sy_scmp';
const _maxBatch = 50;

/// 이벤트 이름당 분당 상한 — 무한 루프 버그가 트래픽을 만들지 못하게
const _perNamePerMinute = 30;

/// 전체 분당 상한 — 서버의 방문자당 분당 한도(120)보다 낮게 둔다
const _totalPerMinute = 100;
const _maxQueue = 500;

final _devHost = RegExp(
  r'^(localhost|127\.\d+\.\d+\.\d+|\[?::1\]?|0\.0\.0\.0|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)$|\.local$',
  caseSensitive: false,
);

const _specialSchemes = {'http', 'https', 'ws', 'wss', 'ftp', 'file'};

/// JS `Math.round`
int _jsRound(num value) => (value + 0.5).floor();

/// 실행 환경을 직접 넣어 방문 분석을 만듭니다. 테스트·비표준 런타임용입니다.
Analytics createAnalyticsWith(AnalyticsOptions options, AnalyticsEnv env) => _Analytics(options, env);

class _Analytics implements Analytics {
  _Analytics(this.options, this.env)
      : endpoint = '${options.baseUrl.replaceAll(RegExp(r'/+$'), '')}/events',
        enabled = options.debug == true || !_devHost.hasMatch(env.hostname()),
        consent = options.consent ?? 'pending' {
    cleanups.addAll([
      env.on('visibilitychange', () {
        if (env.visible()) {
          if (pageViewId.isNotEmpty && visibleSince == null) visibleSince = env.now();
          return;
        }
        endPage();
        flush();
      }),
      env.on('pagehide', () {
        endPage();
        flush();
      }),
      env.setInterval(flush, options.flushIntervalMs ?? 5000),
    ]);
    if (options.autoPageViews != false) {
      startWhenVisible();
      cleanups.add(env.onNavigate(startPage));
    }
  }

  final AnalyticsOptions options;
  final AnalyticsEnv env;
  final String endpoint;
  final bool enabled;
  AnalyticsConsent consent;
  List<Map<String, Object?>> queue = [];
  String pageViewId = '';
  String pageKey = '';
  String pageHref = '';
  int? visibleSince;
  num visibleMs = 0;
  bool engagementSent = false;
  bool firstPage = true;
  bool pageAccepted = false;
  final seen = <String>{};
  int rateMinute = -1;
  final perName = <String, int>{};
  int totalThisMinute = 0;
  final cleanups = <void Function()>[];

  String? campaignOf(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) return null;
    final source = uri.queryParameters['utm_source'];
    return source != null && source.isNotEmpty ? '$source|${uri.queryParameters['utm_campaign'] ?? ''}' : null;
  }

  /// 동의가 있을 때만 ID를 읽고 만든다. 세션은 이벤트마다 30분 연장한다
  ({String visitorId, String sessionId})? ensureIds() {
    if (consent != 'granted') return null;
    var visitorId = env.getCookie(ANALYTICS_VISITOR_COOKIE);
    if (visitorId == null || visitorId.isEmpty) visitorId = env.randomId();
    var sessionId = env.getCookie(ANALYTICS_SESSION_COOKIE);
    final campaign = campaignOf(env.href());
    if (campaign != null && campaign != env.getCookie(_sessionCampaignCookie)) {
      sessionId = null; // 새 캠페인으로 들어왔다 — 새 세션
      env.setCookie(_sessionCampaignCookie, campaign, _sessionMaxAgeSec, options.cookieDomain);
    }
    if (sessionId == null || sessionId.isEmpty) sessionId = env.randomId();
    env.setCookie(ANALYTICS_VISITOR_COOKIE, visitorId, _visitorMaxAgeSec, options.cookieDomain);
    env.setCookie(ANALYTICS_SESSION_COOKIE, sessionId, _sessionMaxAgeSec, options.cookieDomain);
    return (visitorId: visitorId, sessionId: sessionId);
  }

  bool allowRate(String name) {
    final minute = env.now() ~/ 60000;
    if (minute != rateMinute) {
      rateMinute = minute;
      perName.clear();
      totalThisMinute = 0;
    }
    final used = perName[name] ?? 0;
    if (used >= _perNamePerMinute || totalThisMinute >= _totalPerMinute) return false;
    perName[name] = used + 1;
    totalThisMinute += 1;
    return true;
  }

  /// 큐에 넣었으면 true — 중복·상한·거부로 버리면 false
  bool push(Map<String, Object?> event, String dedupeKey) {
    if (!enabled || consent == 'denied') return false;
    if (seen.contains(dedupeKey) || !allowRate(event['name'] as String)) return false;
    seen.add(dedupeKey);
    if (queue.length >= _maxQueue) queue.removeAt(0);
    queue.add(event);
    if (queue.length >= _maxBatch) flush();
    return true;
  }

  @override
  void flush() {
    if (!enabled || queue.isEmpty) return;
    final ids = ensureIds();
    if (ids == null) return; // 동의 전 — 큐에 둔다
    while (queue.isNotEmpty) {
      final events = queue.take(_maxBatch).toList();
      queue = queue.skip(_maxBatch).toList();
      final batch = {
        'storeCode': options.storeCode,
        'visitorId': ids.visitorId,
        'sessionId': ids.sessionId,
        'events': events,
        if (env.webdriver()) 'context': {'webdriver': true},
      };
      env.send(endpoint, jsonEncode(batch));
    }
  }

  String occurredAt() => DateTime.fromMillisecondsSinceEpoch(env.now(), isUtc: true).toIso8601String();

  /// 지금 페이지의 체류를 한 번 보낸다(이동·숨김·닫힘 중 먼저 오는 때)
  void endPage() {
    if (pageViewId.isEmpty || engagementSent || !pageAccepted) return;
    if (visibleSince != null) {
      visibleMs += env.now() - visibleSince!;
      visibleSince = env.visible() ? env.now() : null;
    }
    engagementSent = true;
    push({
      'name': 'page_engagement',
      'occurredAt': occurredAt(),
      'url': pageHref,
      'pageViewId': pageViewId,
      'visibleMs': visibleMs < 0 ? 0 : _jsRound(visibleMs),
    }, 'engagement:$pageViewId');
  }

  void startPage() {
    final href = env.href();
    var key = href;
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      // WHATWG URL처럼 특수 스킴(http 등)의 빈 경로는 `/`다. 해시만 바뀐 이동은 새 페이지가 아니다
      final path = uri.path.isEmpty && _specialSchemes.contains(uri.scheme) ? '/' : uri.path;
      key = '$path${uri.hasQuery ? '?${uri.query}' : ''}';
    }
    if (key == pageKey) return;
    endPage();
    pageKey = key;
    pageHref = href;
    pageViewId = env.randomId();
    visibleMs = 0;
    visibleSince = env.visible() ? env.now() : null;
    engagementSent = false;
    final referrer = firstPage ? env.referrer() : '';
    pageAccepted = push({
      'name': 'page_view',
      'occurredAt': occurredAt(),
      'url': href,
      'pageViewId': pageViewId,
      if (referrer.isNotEmpty) 'referrer': referrer,
    }, 'page:$pageViewId');
    // 외부 유입(리퍼러)은 실제로 보낸 첫 페이지뷰에만 싣는다
    if (pageAccepted) firstPage = false;
  }

  /// 미리 그리는 중이거나 숨은 화면은 보이는 순간 첫 페이지뷰를 보낸다
  void startWhenVisible() {
    if (!env.prerendering() && env.visible()) {
      startPage();
      return;
    }
    void tryStart() {
      if (pageViewId.isEmpty && !env.prerendering() && env.visible()) startPage();
    }

    cleanups.addAll([env.on('prerenderingchange', tryStart), env.on('visibilitychange', tryStart)]);
  }

  @override
  void track(AnalyticsTrackInput input) {
    if (pageViewId.isEmpty) startPage();
    if (!pageAccepted) return; // 페이지뷰가 버려진 페이지의 행동은 보내지 않는다
    final common = {'occurredAt': occurredAt(), 'url': env.href(), 'pageViewId': pageViewId};
    switch (input) {
      case AnalyticsTrackInputProductView(:final productId, :final variantId):
        push({
          ...common,
          'name': 'product_view',
          'productId': productId,
          if (variantId != null && variantId.isNotEmpty) 'variantId': variantId,
        }, 'product:$pageViewId:$productId');
      case AnalyticsTrackInputProductListView(:final listId, :final productIds):
        push({
          ...common,
          'name': 'product_list_view',
          'listId': listId,
          'productIds': productIds.take(100).toList(),
        }, 'list:$pageViewId:$listId');
      case AnalyticsTrackInputSearch(:final query, :final resultCount):
        push({
          ...common,
          'name': 'search',
          'query': query.length > 200 ? query.substring(0, 200) : query,
          'resultCount': resultCount,
        }, 'search:$pageViewId:${query.trim().toLowerCase()}');
    }
  }

  @override
  void page() => startPage();

  @override
  void setConsent(AnalyticsConsent next) {
    consent = next;
    if (next == 'denied') queue = [];
    if (next == 'granted') {
      // 거부 중에 연 페이지는 페이지뷰가 없다 — 동의한 지금 그 페이지를 새로 센다
      if (pageViewId.isNotEmpty && !pageAccepted && options.autoPageViews != false) {
        pageKey = '';
        startPage();
      }
      flush();
    }
  }

  @override
  ({String visitorId, String sessionId})? ids() => enabled ? ensureIds() : null;

  @override
  void destroy() {
    final all = List.of(cleanups);
    cleanups.clear();
    for (final cleanup in all) {
      cleanup();
    }
  }
}
