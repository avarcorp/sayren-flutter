// 손 시나리오(tool/parity/store/scenarios.json)의 호출 — client-overrides.mjs로 만든 메서드는 Node 인자 모양(JSON)을 Dart 인자로 바꾼다.
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

Map<String, Object?>? _m(Object? v) => (v as Map?)?.cast<String, Object?>();

Object? _at(List<Object?> a, int i) => i < a.length ? a[i] : null;

/// 업로드 파일 `{ "$file": { name, type, bytes } }` → XFile
XFile _file(Object? v) {
  final f = _m(_m(v)![r'$file'])!;
  // io의 XFile.name은 경로에서 읽으므로 경로도 준다
  return XFile.fromData(Uint8List.fromList((f['bytes'] as List).cast<int>()),
      name: f['name'] as String, path: f['name'] as String, mimeType: f['type'] as String);
}

/// 이름 → 호출
final Map<String, Future<Object?> Function(StoreClient c, List<Object?> a)> handCalls = {
  'uploads.upload': (c, a) {
    final o = _m(_at(a, 1));
    return c.uploads
        .upload(_file(a[0]), o == null ? null : (purpose: o['purpose'] as String?, filename: o['filename'] as String?));
  },
  'products.setCalendar': (c, a) async {
    final r = await c.products.setCalendar(a[0] as String, SetCalendarRequest.fromJson(_m(a[1])!));
    return {'updated': r.updated};
  },
  'categories.remove': (c, a) => c.categories.remove(a[0] as String, strategy: _m(_at(a, 1))?['strategy'] as String?),
  'orderItems.cancelPreview': (c, a) => c.orderItems.cancelPreview(a[0] as String, _at(a, 1) as int?),
  'orderItems.dispatchBulk': (c, a) => c.orderItems.dispatchBulk([
        for (final d in (a[0] as List).cast<Map<Object?, Object?>>())
          (
            orderItemId: d['orderItemId'] as String,
            dispatch: DispatchRequest.fromJson({...d.cast<String, Object?>()}..remove('orderItemId')),
          ),
      ], _at(a, 1) as String?),
  'orderItems.fulfillBulk': (c, a) => c.orderItems.fulfillBulk((a[0] as List).cast<String>(),
      _at(a, 1) == null ? null : FulfillRequest.fromJson(_m(a[1])!), _at(a, 2) as String?),
  'commerceFlows.saveDraft': (c, a) =>
      c.commerceFlows.saveDraft(a[0] as String, SaveFlowDraftRequest.fromJson(_m(a[1])!), _at(a, 2) as int?),
  'claims.list': (c, a) {
    final p = _m(_at(a, 0));
    return c.claims.list(p == null
        ? null
        : ClaimListParams(
            page: p['page'] as int?,
            size: p['size'] as int?,
            type: p['type'] as String?,
            status: p['status'],
            orderItemId: p['orderItemId'] as String?,
            requestedFrom: p['requestedFrom'] as String?,
            requestedTo: p['requestedTo'] as String?,
          ));
  },
  'claims.approve': (c, a) {
    final o = _m(_at(a, 3));
    return c.claims.approve(a[0] as String, _at(a, 1) as int?, _at(a, 2) as String?,
        o == null ? null : (holdRefund: o['holdRefund'] as bool?));
  },
  'claims.completeCollect': (c, a) => c.claims
      .completeCollect(a[0] as String, _at(a, 1) == null ? null : ClaimCollectCompleteRequest.fromJson(_m(a[1])!)),
  'claims.registerRedelivery': (c, a) {
    final o = _m(_at(a, 3));
    return c.claims.registerRedelivery(a[0] as String, a[1] as String, a[2] as String,
        o == null ? null : (inventoryLocationId: o['inventoryLocationId'] as String?));
  },
  'customers.listPointHistory': (c, a) =>
      c.customers.listPointHistory(a[0] as String, _at(a, 1) == null ? null : PointHistoryQuery.fromJson(_m(a[1])!)),
  'customers.list': (c, a) {
    final p = _m(_at(a, 0)) ?? const {};
    return c.customers.list(
      page: p['page'] as int?,
      size: p['size'] as int?,
      q: p['q'] as String?,
      joinedFrom: p['joinedFrom'] as String?,
      joinedTo: p['joinedTo'] as String?,
      marketing: p['marketing'] as String?,
      sort: p['sort'] as String?,
    );
  },
  'coupons.list': (c, a) {
    final p = _m(_at(a, 0)) ?? const {};
    return c.coupons.list(
      page: p['page'] as int?,
      size: p['size'] as int?,
      status: p['status'] as String?,
      kind: p['kind'] as String?,
      issueMethod: p['issueMethod'] as String?,
      q: p['q'] as String?,
    );
  },
  'paymentSettings.setSandboxMode': (c, a) => c.paymentSettings.setSandboxMode(a[0] as String, a[1] as bool),
  'paymentSettings.verify': (c, a) => c.paymentSettings
      .verify(a[0] as String, _at(a, 1) == null ? null : VerifyPaymentProviderRequest.fromJson(_m(a[1])!)),
  'apps.installations.install': (c, a) {
    final input = a[0];
    return c.apps.installations.install(input is Map
        ? (appId: input['appId'] as String, settings: (input['settings'] as Map?)?.cast<String, Object?>())
        : input!);
  },
  'store.listInvitations': (c, a) => c.store.listInvitations(status: _m(_at(a, 0))?['status'] as String?),
};
