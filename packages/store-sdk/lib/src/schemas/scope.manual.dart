// 손으로 쓴 부분 — scope.ts의 함수.
part of 'scope.dart';

/// 카탈로그에 있는 스코프 문자열인지 판정합니다(예: `settlement:rw`는 false).
bool isStoreScope(String scope) {
  final parts = scope.split(':');
  if (parts.length != 2) return false;
  final resource = parts[0];
  final access = parts[1];
  if (resource.isEmpty || access.isEmpty) return false;
  return STORE_SCOPE_RESOURCES[resource]?.contains(access) ?? false;
}
