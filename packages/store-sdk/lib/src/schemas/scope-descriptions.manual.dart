// 손으로 쓴 부분 — scope-descriptions.ts의 함수.
part of 'scope-descriptions.dart';

/// 스코프(`{resource}:{r|rw}`)를 사람이 읽는 문장으로 바꿉니다. 카탈로그에 없는 스코프는 null입니다.
String? describeScope(String scope) {
  final parts = scope.split(':');
  final resource = parts[0];
  final access = parts.length > 1 ? parts[1] : null;
  if (resource.isEmpty || !STORE_SCOPE_RESOURCES.containsKey(resource)) return null;
  final allowed = STORE_SCOPE_RESOURCES[resource]!;
  if (access != 'r' && access != 'rw') return null;
  if (!allowed.contains(access)) return null;
  return SCOPE_DESCRIPTIONS[resource]![access];
}
