// 손으로 쓴 부분 — locale.ts의 언어 코드 정규화와 localeCodeSchema 변환.
part of 'locale.dart';

final _localePattern = RegExp(r'^([a-z]{2,3})(?:-([a-z]{4}))?(?:-([a-z]{2}))?$');

/// 언어 코드(BCP 47의 언어[-문자][-지역])를 표준 표기로 맞춥니다. 맞지 않으면 null입니다.
///
/// 언어는 소문자, 문자는 첫 글자 대문자, 지역은 대문자입니다(`EN_us` → `en-US`, `zh-hant-tw` → `zh-Hant-TW`).
String? normalizeLocale(String? value) {
  if (value == null) return null;
  final match = _localePattern.firstMatch(value.trim().replaceAll('_', '-').toLowerCase());
  if (match == null) return null;
  final language = match.group(1)!;
  final script = match.group(2);
  final region = match.group(3);
  return [
    language,
    if (script != null && script.isNotEmpty) '${script[0].toUpperCase()}${script.substring(1)}',
    if (region != null && region.isNotEmpty) region.toUpperCase(),
  ].join('-');
}

/// localeCodeSchema 변환 — 정규화하지 못하면 검증을 멈추는 이슈를 더한다
Object? _localeCode(Object? value, List<Object> path, List<ZodIssue> issues) {
  final normalized = normalizeLocale(value as String);
  if (normalized == null) {
    issues.add(ZodIssue(code: 'custom', path: List.unmodifiable(path), message: '언어는 BCP 47 언어 코드입니다(예: ko·en·en-US)'));
    return null;
  }
  return normalized;
}
