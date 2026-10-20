import 'apps.dart';
import 'catalog.dart';
import 'money.dart';

/// 대조하는 손으로 쓴 함수 — 이름 → 어댑터
final Map<String, Object? Function(List<Object?> a)> functions = {
  ...appsFunctions,
  ...catalogFunctions,
  ...moneyFunctions
};
