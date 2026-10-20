// 손으로 쓴 부분 — product-options.ts의 함수.
part of 'product-options.dart';

/// 직접 입력값을 타입대로 검사하고 저장할 모양으로 바꿉니다. 맞지 않으면 null입니다.
///
/// 서버 판정(400 `CUSTOM_INPUT_INVALID`)과 같은 규칙입니다. 모르는 타입은 `text`로 봅니다.
String? parseCustomInputValue(String? type, List<String>? options, String raw) {
  final value = normalizeCustomInputValue(raw);
  switch (type) {
    case 'number':
      return RegExp(r'^-?\d{1,15}$').hasMatch(value) ? int.parse(value).toString() : null;
    case 'select':
      return (options?.contains(value) ?? false) ? value : null;
    case 'date':
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
      final date = DateTime.tryParse('${value}T00:00:00Z');
      return date != null && date.toIso8601String().substring(0, 10) == value ? value : null;
    case 'image':
      final urls = value.split(RegExp(r'\s+')).where((u) => u.isNotEmpty).toList();
      if (urls.isEmpty || !urls.every((url) => RegExp(r'^https:\/\/\S+$').hasMatch(url))) return null;
      return urls.toSet().join('\n');
    case 'datetime':
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
        return null;
      }
      final time = DateTime.tryParse(value);
      return time?.toUtc().toIso8601String();
    default:
      return value;
  }
}

/// 직접 입력값을 정규화합니다. 서버가 저장하는 값이 이것입니다. 빈 문자열이면 입력하지 않은 것으로 봅니다.
///
/// NFC로 모으고, 제어 문자(C0·C1·줄바꿈·줄·문단 구분자)는 공백으로, 제로폭·양방향 제어 문자는 지운 뒤 앞뒤 공백을 지웁니다.
String normalizeCustomInputValue(String value) => unorm
    .nfc(value)
    .replaceAll(RegExp(r'[\u0000-\u001f\u007f-\u009f\u2028\u2029]', unicode: true), ' ')
    .replaceAll(RegExp(r'[\u200b-\u200f\u202a-\u202e\u2060-\u2064\u2066-\u2069\ufeff]', unicode: true), '')
    .trim();

/// 직접 입력값의 글자 수입니다. 정규화한 값의 코드 포인트 수이고, 이모지 하나가 1자입니다.
///
/// 서버의 최대 글자 수 판정(`CUSTOM_INPUT_TOO_LONG`)과 같은 규칙입니다.
int customInputLength(String value) => normalizeCustomInputValue(value).runes.length;
