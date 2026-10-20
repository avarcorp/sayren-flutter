// 손으로 쓴 부분 — stay.ts의 함수·zod 클로저 구현.
part of 'stay.dart';

/// JS `Date.parse(`${date}T00:00:00Z`)` — 읽을 수 없으면 null
int? _utcDayMs(String date) => DateTime.tryParse('${date}T00:00:00Z')?.millisecondsSinceEpoch;

/// JS `new Date(ms).toISOString().slice(0, 10)`
String _isoDate(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String().substring(0, 10);

/// 한국 날짜 refine — 실제로 있는 날짜(YYYY-MM-DD)인가
bool _isCalendarDate(String value) {
  final ms = _utcDayMs(value);
  return ms != null && _isoDate(ms) == value;
}

/// 체크인부터 체크아웃 전날까지 날짜 목록을 돌려줍니다. 형식이 틀리거나 체크아웃이 체크인 이하면 빈 목록입니다.
List<String> nightsOf(StayRange range) {
  final start = _utcDayMs(range.checkIn);
  final end = _utcDayMs(range.checkOut);
  if (start == null || end == null || end <= start) return [];
  return [for (var at = start; at < end; at += 86400000) _isoDate(at)];
}
