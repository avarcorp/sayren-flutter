// 손으로 쓴 부분 — app-manifest.ts의 함수와 capability 레지스트리.
part of 'app-manifest.dart';

/// 앱이 요청할 수 있는 스코프인지 판정합니다. 카탈로그에 있고 [NON_INSTALLABLE_SCOPES]가 아니어야 합니다.
bool isInstallableScope(String scope) => isStoreScope(scope) && !NON_INSTALLABLE_SCOPES.contains(scope);

/// 이벤트 타입 하나의 `data`입니다(Node `AppEventDataOf<"APP.INSTALLED">`).
///
/// Dart에는 문자열 리터럴 타입이 없어 타입별로 좁히지 않습니다. 생명주기 이벤트는 [AppLifecycleEventDataMap]의 같은 이름 필드,
/// 웹훅 이벤트는 [WebhookEvent] 하위 클래스의 `data`를 보십시오.
typedef AppEventDataOf<T extends String> = Object?;

/// 동의 스코프가 이벤트를 받을 수 있는지 판정합니다. `rw`는 `r`을 함의합니다. 생명주기 이벤트는 스코프가 필요 없습니다.
bool scopesCoverEvent(List<String> scopes, String event) {
  final required = APP_EVENT_SCOPES[event];
  if (required == null) return true;
  final resource = required.split(':')[0];
  return scopes.contains(required) || scopes.contains('$resource:rw');
}

final _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
final _tld = RegExp(r'^(?:[a-z]{2,63}|xn--[a-z0-9-]{1,59})$');

/// 외부 호출 호스트의 형식 문제를 돌려줍니다. 문제가 없으면 null입니다.
///
/// https·443·소문자 호스트명만 받습니다. 와일드카드는 한 단계(`*.example.com`)만이고 IP·`localhost`·sayren 플랫폼 호스트는 받지 않습니다.
/// 253자 이하, 라벨 2개 이상이어야 합니다.
String? appNetworkHostProblem(String raw) {
  final host = raw.trim();
  if (host != raw || host != host.toLowerCase()) return '호스트는 소문자이고 앞뒤 공백이 없어야 합니다';
  if (host.length > 253) return '호스트가 너무 깁니다';
  if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) || host.contains(':')) return 'IP 주소는 쓸 수 없습니다';
  final labels = host.split('.');
  final wildcard = labels[0] == '*';
  final named = wildcard ? labels.sublist(1) : labels;
  if (named.length < 2) return '호스트는 라벨이 둘 이상이어야 합니다';
  if (!named.every(_hostLabel.hasMatch)) return '호스트 형식이 맞지 않습니다';
  if (!_tld.hasMatch(named.last)) return '최상위 도메인 형식이 맞지 않습니다';
  final apex = named.join('.');
  for (final suffix in APP_NETWORK_DENIED_SUFFIXES) {
    if (apex == suffix || apex.endsWith('.$suffix')) return 'sayren 플랫폼·내부 호스트는 쓸 수 없습니다';
  }
  return null;
}

/// appNetworkHostSchema superRefine
void _appNetworkHostCheck(String value, ZodCheckContext ctx) {
  final problem = appNetworkHostProblem(value);
  if (problem != null && problem.isNotEmpty) ctx.addIssue(problem);
}

/// JS 숫자 문자열(`256`, `1.5`)
String _jsNum(num value) => value == value.truncate() ? '${value.truncate()}' : '$value';

/// 아이콘 파일의 문제를 돌려줍니다. 문제가 없으면 null입니다.
///
/// [bytes]는 파일 바이트, [contentType]은 [AppIconContentType](`image/png`·`image/svg+xml`)입니다. PNG는 정사각형
/// [APP_ICON_MIN_PX]px 이상, 파일은 [APP_ICON_MAX_BYTES] 이하여야 합니다.
String? appIconProblem(List<int> bytes, String contentType) {
  if (bytes.isEmpty) return '아이콘 파일이 비어 있습니다';
  if (bytes.length > APP_ICON_MAX_BYTES) {
    return '아이콘이 ${(bytes.length / 1024).ceil()}KB입니다. 상한은 ${_jsNum(APP_ICON_MAX_BYTES / 1024)}KB입니다';
  }
  if (contentType == 'image/svg+xml') {
    final head = utf8.decode(bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024), allowMalformed: true);
    return RegExp(r'<svg[\s>]', caseSensitive: false).hasMatch(head) ? null : 'SVG 파일이 아닙니다';
  }
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 24) return 'PNG 파일이 아닙니다';
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return 'PNG 파일이 아닙니다';
  }
  int uint32(int at) => ((bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]) & 0xffffffff;
  final width = uint32(16);
  final height = uint32(20);
  if (width != height) return '아이콘은 정사각형이어야 합니다(지금 $width×$height)';
  if (width < APP_ICON_MIN_PX) {
    return '아이콘은 $APP_ICON_MIN_PX×$APP_ICON_MIN_PX 이상이어야 합니다(지금 $width×$height)';
  }
  return null;
}

/// 스키마가 보지 못하는 필드 사이 규칙을 검사합니다. 비어 있으면 통과입니다.
///
/// 중복 값, 외부 런타임 주소·호스트, 이벤트에 필요한 스코프, 설정 필드(select 선택지·비밀 필드 형식·기본값 형식)를 봅니다.
List<AppManifestProblem> appManifestProblems(AppManifest manifest) {
  final problems = <AppManifestProblem>[];
  void unique(List<String> values, String path, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (seen.contains(value)) {
        problems.add(AppManifestProblem(path: path, code: 'DUPLICATE', message: '$label이 중복됐습니다: $value'));
      }
      seen.add(value);
    }
  }

  unique(manifest.scopes, 'scopes', '스코프');
  unique(manifest.events, 'events', '이벤트');
  unique(manifest.network.hosts, 'network.hosts', '호스트');
  unique(manifest.secrets, 'secrets', '비밀 값 이름');
  unique(manifest.http?.public ?? const [], 'http.public', '공개 HTTP 핸들러');
  // 외부 런타임 — 주소가 있어야 하고, 내보내는 곳을 sayren이 막을 수 없어 network.hosts를 받지 않는다
  if ((manifest.runtime == 'external') != (manifest.external != null)) {
    problems.add(AppManifestProblem(
      path: 'external',
      code: 'EXTERNAL_URL_REQUIRED',
      message: 'runtime이 external이면 external.url이 필요하고, code면 external을 적지 않습니다',
    ));
  }
  if (manifest.runtime == 'external' && manifest.network.hosts.isNotEmpty) {
    problems.add(const AppManifestProblem(
      path: 'network.hosts',
      code: 'EXTERNAL_NETWORK_HOSTS',
      message: '외부 런타임 앱은 network.hosts를 적지 않습니다',
    ));
  }
  final external = manifest.external;
  if (external != null) {
    final hostProblem = appNetworkHostProblem(_hostnameOf(external.url));
    if (hostProblem != null && hostProblem.isNotEmpty) {
      problems.add(AppManifestProblem(path: 'external.url', code: 'EXTERNAL_URL_INVALID', message: hostProblem));
    }
  }
  for (final event in manifest.events) {
    if (!scopesCoverEvent(manifest.scopes, event)) {
      problems.add(AppManifestProblem(
        path: 'events.$event',
        code: 'EVENT_SCOPE_MISSING',
        message: '$event 이벤트를 받으려면 ${APP_EVENT_SCOPES[event]} 스코프가 필요합니다',
      ));
    }
  }
  for (final MapEntry(:key, value: field) in manifest.settings.entries) {
    if (field.type == 'select' && field.options == null) {
      problems.add(AppManifestProblem(
          path: 'settings.$key', code: 'SELECT_OPTIONS_REQUIRED', message: 'select 필드에는 options가 필요합니다'));
    }
    if (field.secret == true && field.type != 'string') {
      problems.add(AppManifestProblem(path: 'settings.$key', code: 'SECRET_FIELD_TYPE', message: '비밀 필드는 string만 됩니다'));
    }
    if (jsonOf(field).containsKey('default')) {
      final value = field.default_;
      final expected = field.type == 'select' ? 'string' : field.type;
      final matchesOption = field.type != 'select' || (field.options?.any((o) => o.value == value) ?? false);
      if (_typeOf(value) != expected || !matchesOption) {
        problems.add(AppManifestProblem(
            path: 'settings.$key', code: 'DEFAULT_TYPE_MISMATCH', message: 'default가 필드 형식과 맞지 않습니다'));
      }
    }
  }
  return problems;
}

/// JS `typeof`(설정 기본값이 받는 세 형식)
String _typeOf(Object? value) => switch (value) {
      String() => 'string',
      num() => 'number',
      bool() => 'boolean',
      null => 'object',
      _ => 'object',
    };

/// `new URL(url).hostname` — 읽을 수 없으면 Node처럼 던진다
String _hostnameOf(String url) {
  final parsed = parseHttpUrl(url);
  if (parsed == null) throw FormatException('Invalid URL', url);
  return parsed.hostname;
}

int _compareKeys(String a, String b) => a.compareTo(b);

/// 매니페스트에서 판정용 요약([AppCapabilities])을 만듭니다. 목록은 중복을 빼고 정렬합니다.
AppCapabilities appCapabilitiesOf(AppManifest manifest) {
  List<String> sorted(List<String> values) => values.toSet().toList()..sort();
  final schedules = manifest.schedules.entries.toList()..sort((a, b) => _compareKeys(a.key, b.key));
  final settings = manifest.settings.entries;
  return AppCapabilities(
    scopes: sorted(manifest.scopes),
    events: sorted(manifest.events),
    networkHosts: sorted(manifest.network.hosts),
    adminPage: manifest.ui != null,
    publicHttp: sorted(manifest.http?.public ?? const []),
    flowNotifications: manifest.flow?.notifications ?? const {},
    flowEvents: manifest.flow?.events ?? const {},
    externalHost: manifest.external == null ? null : _hostnameOf(manifest.external!.url),
    tools: manifest.mcp?.tools ?? const {},
    schedules: {for (final e in schedules) e.key: e.value.every},
    requiredSettings: [
      for (final e in settings)
        if (e.value.required == true) e.key
    ]..sort(),
    secretSettings: [
      for (final e in settings)
        if (e.value.secret == true) e.key
    ]..sort(),
  );
}

bool _grew(List<String> previous, List<String> next) => next.any((value) => !previous.contains(value));

/// 스코프 집합이 넓어졌는가 — `r`→`rw`는 넓어짐, `rw`→`r`은 아님
bool _scopesWiden(List<String> previous, List<String> next) => next.any((scope) {
      if (previous.contains(scope)) return false;
      final parts = scope.split(':');
      final access = parts.length > 1 ? parts[1] : null;
      return !(access == 'r' && previous.contains('${parts[0]}:rw'));
    });

/// capability 레지스트리입니다. 키마다 동의 문단 제목과 판정([AppCapabilityDefinition.describe]·
/// [AppCapabilityDefinition.widens])을 둡니다. 「넓어졌다」는 기존 설치가 재동의해야 새 버전으로 옮길 수 있다는 뜻입니다.
final APP_CAPABILITIES = <AppCapabilityDefinition>[
  AppCapabilityDefinition(
    key: 'scopes',
    title: '이 앱이 할 수 있는 일',
    describe: (c) => [for (final scope in c.scopes) describeScope(scope) ?? scope],
    widens: (p, n) => _scopesWiden(p.scopes, n.scopes),
  ),
  AppCapabilityDefinition(
    key: 'network',
    title: '이 앱이 데이터를 보내는 곳',
    describe: (c) => c.networkHosts,
    widens: (p, n) => _grew(p.networkHosts, n.networkHosts),
  ),
  AppCapabilityDefinition(
    key: 'events',
    title: '이 앱이 받는 알림',
    describe: (c) => c.events,
    widens: (p, n) => _grew(p.events, n.events),
  ),
  AppCapabilityDefinition(
    key: 'ui',
    title: '상점 플랫폼 화면',
    describe: (c) => c.adminPage ? const ['상점 플랫폼에 이 앱의 화면을 더합니다'] : const [],
    widens: (p, n) => !p.adminPage && n.adminPage,
  ),
  AppCapabilityDefinition(
    key: 'publicHttp',
    title: '외부에서 이 앱을 부르는 주소',
    describe: (c) => c.publicHttp ?? const [],
    widens: (p, n) => _grew(p.publicHttp ?? const [], n.publicHttp ?? const []),
  ),
  AppCapabilityDefinition(
    key: 'schedules',
    title: '주기적으로 실행되는 작업',
    describe: (c) => [
      for (final MapEntry(key: name, value: every) in (c.schedules ?? const {}).entries)
        '$name · ${appScheduleIntervalLabel(every)}마다'
    ],
    widens: (p, n) {
      final before = p.schedules ?? const {};
      return (n.schedules ?? const {}).entries.any((e) {
        final prior = before[e.key];
        if (prior == null || prior.isEmpty) return true;
        final now = APP_SCHEDULE_INTERVALS[e.value];
        final then = APP_SCHEDULE_INTERVALS[prior];
        return now != null && then != null && now < then;
      });
    },
  ),
  AppCapabilityDefinition(
    key: 'runtime',
    title: '이 앱이 실행되는 곳',
    describe: (c) => c.externalHost != null && c.externalHost!.isNotEmpty ? ['개발자 서버 ${c.externalHost}'] : const [],
    widens: (p, n) {
      final host = n.externalHost;
      return host != null && host.isNotEmpty && host != p.externalHost;
    },
  ),
  AppCapabilityDefinition(
    key: 'tools',
    title: 'AI 에이전트 도구',
    describe: (c) =>
        [for (final MapEntry(key: name, value: tool) in (c.tools ?? const {}).entries) '$name · ${tool.description}'],
    widens: (p, n) => _grew((p.tools ?? const {}).keys.toList(), (n.tools ?? const {}).keys.toList()),
  ),
];

/// 요청(메서드·경로)이 HTTP 핸들러 키(`"GET /track/:id"`)에 맞는지 판정합니다. `:이름`은 경로 한 마디에 맞습니다.
bool appHttpKeyMatches(String key, String method, String path) {
  final match = APP_HTTP_KEY_PATTERN.firstMatch(key.trim().replaceAll(RegExp(r'\s+'), ' '));
  if (match == null || match.group(1) != method.toUpperCase()) return false;
  final pattern = match.group(2)!.split('/');
  final actual = path.split('?')[0].split('/');
  if (pattern.length != actual.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    final part = pattern[i];
    if (part.startsWith(':') ? actual[i] == '' : part != actual[i]) return false;
  }
  return true;
}

/// 응답용 예약 작업 목록(이름순)입니다. 옛 버전 행(`schedules` 없음)은 빈 목록입니다.
List<({String name, String every})> appScheduleListOf(AppCapabilities capabilities) {
  final entries = (capabilities.schedules ?? const {}).entries.toList()..sort((a, b) => _compareKeys(a.key, b.key));
  return [for (final e in entries) (name: e.key, every: e.value)];
}

/// 응답용 흐름 알림·사건 목록(이름순)입니다. 옛 버전 행은 빈 목록입니다.
({
  List<
      ({
        String name,
        String label,
        List<({String name, String type, String label, bool required})> params,
      })> flowNotifications,
  List<({String name, String label})> flowEvents,
}) appFlowSummaryOf(AppCapabilities capabilities) {
  List<MapEntry<String, T>> byName<T>(Map<String, T> map) =>
      map.entries.toList()..sort((a, b) => _compareKeys(a.key, b.key));
  return (
    flowNotifications: [
      for (final MapEntry(key: name, value: notice) in byName(capabilities.flowNotifications ?? const {}))
        (
          name: name,
          label: notice.label,
          params: [
            for (final MapEntry(key: param, value: field) in byName(notice.params))
              (name: param, type: field.type, label: field.label, required: field.required ?? false),
          ],
        ),
    ],
    flowEvents: [
      for (final MapEntry(key: name, value: event) in byName(capabilities.flowEvents ?? const {}))
        (name: name, label: event.label),
    ],
  );
}

/// 응답용 도구 목록(이름순)입니다. 옛 버전 행은 빈 목록입니다.
List<({String name, String description})> appToolListOf(AppCapabilities capabilities) {
  final entries = (capabilities.tools ?? const {}).entries.toList()..sort((a, b) => _compareKeys(a.key, b.key));
  return [for (final e in entries) (name: e.key, description: e.value.description)];
}

/// 예약 간격([AppScheduleInterval])의 표시 이름입니다(`15m` → `15분`, `3h` → `3시간`, `1d` → `하루`).
String appScheduleIntervalLabel(String every) {
  final minutes = APP_SCHEDULE_INTERVALS[every];
  if (minutes != null && minutes < 60) return '$minutes분';
  if (minutes != null && minutes < 1440) return '${_jsNum(minutes / 60)}시간';
  return '하루';
}

/// 재동의가 필요한 capability 키 목록입니다. 비어 있으면 새 버전이 모든 설치에 곧바로 반영됩니다.
List<String> appManifestWidens(AppCapabilities previous, AppCapabilities next) => [
      for (final c in APP_CAPABILITIES)
        if (c.widens(previous, next)) c.key
    ];
