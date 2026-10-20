// 함수 대조 어댑터 — tool/parity/store/functions/*.json의 인자(JSON)를 Dart 인자로 바꿔 부르고 결과를 JSON 값으로 돌려준다.
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

Map<String, Object?> _map(Object? v) => (v as Map).cast<String, Object?>();

List<String> _strings(Object? v) => (v as List).cast<String>();

/// capability JSON → [AppCapabilities]. 없는 키는 null이다(옛 버전 행)
AppCapabilities _caps(Object? raw) {
  final j = _map(raw);
  Map<String, T>? models<T>(String key, T Function(Map<String, Object?>) of) =>
      j[key] == null ? null : _map(j[key]).map((k, v) => MapEntry(k, of(_map(v))));
  return AppCapabilities(
    scopes: _strings(j['scopes']),
    events: _strings(j['events']),
    networkHosts: _strings(j['networkHosts']),
    adminPage: j['adminPage'] as bool,
    publicHttp: j['publicHttp'] == null ? null : _strings(j['publicHttp']),
    schedules: j['schedules'] == null ? null : _map(j['schedules']).cast<String, String>(),
    flowNotifications: models('flowNotifications', AppFlowNotification.fromJson),
    flowEvents: models('flowEvents', AppFlowEvent.fromJson),
    externalHost: j['externalHost'] as String?,
    tools: models('tools', AppTool.fromJson),
    requiredSettings: _strings(j['requiredSettings']),
    secretSettings: _strings(j['secretSettings']),
  );
}

/// appCapabilitiesOf 결과 → Node JSON(모든 키를 싣는다)
Map<String, Object?> _capsJson(AppCapabilities c) => {
      'scopes': c.scopes,
      'events': c.events,
      'networkHosts': c.networkHosts,
      'adminPage': c.adminPage,
      'publicHttp': c.publicHttp,
      'flowNotifications': c.flowNotifications?.map((k, v) => MapEntry(k, v.toJson())),
      'flowEvents': c.flowEvents?.map((k, v) => MapEntry(k, v.toJson())),
      'externalHost': c.externalHost,
      'tools': c.tools?.map((k, v) => MapEntry(k, v.toJson())),
      'schedules': c.schedules,
      'requiredSettings': c.requiredSettings,
      'secretSettings': c.secretSettings,
    };

/// 함수 이름 → 어댑터
final Map<String, Object? Function(List<Object?> a)> appsFunctions = {
  // scope · scope-descriptions · ai · locale · store
  'isStoreScope': (a) => isStoreScope(a[0] as String),
  'describeScope': (a) => describeScope(a[0] as String),
  'isAiAgentNotesPath': (a) => isAiAgentNotesPath(a[0] as String),
  'isAiDesignPath': (a) => isAiDesignPath(a[0] as String),
  'normalizeLocale': (a) => normalizeLocale(a[0] as String?),
  'isWebOrigin': (a) => isWebOrigin(a[0] as String),
  'isReservedStoreCode': (a) => isReservedStoreCode(a[0] as String),
  'normalizeBusinessNumber': (a) => normalizeBusinessNumber(a[0] as String),
  // storefront-hosting
  'isShowcaseStorefrontSlug': (a) => isShowcaseStorefrontSlug(a[0] as String),
  'isReservedStorefrontSlug': (a) => isReservedStorefrontSlug(a[0] as String),
  'storefrontEditPreviewLabelOf': (a) => storefrontEditPreviewLabelOf(a[0] as String),
  'storefrontVersionPreviewLabelOf': (a) => storefrontVersionPreviewLabelOf(a[0] as String, a[1] as int),
  'normalizeStorefrontHostname': (a) => normalizeStorefrontHostname(a[0] as String),
  'storefrontCustomHostnameProblem': (a) => a.length > 1
      ? storefrontCustomHostnameProblem(a[0] as String, a[1] as String)
      : storefrontCustomHostnameProblem(a[0] as String),
  'storefrontDomainTxtNameOf': (a) => storefrontDomainTxtNameOf(a[0] as String),
  'normalizeStorefrontPath': (a) => normalizeStorefrontPath(a[0] as String),
  'isEditableStorefrontPath': (a) => isEditableStorefrontPath(a[0] as String),
  // webhook-event
  'parseWebhookEvent': (a) => parseWebhookEvent(a[0]).toJson(),
  // app-manifest
  'isInstallableScope': (a) => isInstallableScope(a[0] as String),
  'scopesCoverEvent': (a) => scopesCoverEvent(_strings(a[0]), a[1] as String),
  'appNetworkHostProblem': (a) => appNetworkHostProblem(a[0] as String),
  'appHttpKeyMatches': (a) => appHttpKeyMatches(a[0] as String, a[1] as String, a[2] as String),
  'appScheduleIntervalLabel': (a) => appScheduleIntervalLabel(a[0] as String),
  'appScheduleListOf': (a) => [
        for (final s in appScheduleListOf(_caps(a[0]))) {'name': s.name, 'every': s.every}
      ],
  'appFlowSummaryOf': (a) {
    final s = appFlowSummaryOf(_caps(a[0]));
    return {
      'flowNotifications': [
        for (final n in s.flowNotifications)
          {
            'name': n.name,
            'label': n.label,
            'params': [
              for (final p in n.params) {'name': p.name, 'type': p.type, 'label': p.label, 'required': p.required}
            ],
          }
      ],
      'flowEvents': [
        for (final e in s.flowEvents) {'name': e.name, 'label': e.label}
      ],
    };
  },
  'appToolListOf': (a) => [
        for (final t in appToolListOf(_caps(a[0]))) {'name': t.name, 'description': t.description}
      ],
  'appManifestWidens': (a) => appManifestWidens(_caps(a[0]), _caps(a[1])),
  'appManifestProblems': (a) => [for (final p in appManifestProblems(AppManifest.fromJson(_map(a[0])))) p.toJson()],
  'appCapabilitiesOf': (a) => _capsJson(appCapabilitiesOf(AppManifest.fromJson(_map(a[0])))),
};
