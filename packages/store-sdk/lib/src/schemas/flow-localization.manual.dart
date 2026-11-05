// 손으로 쓴 부분 — flow-localization.ts의 판정 함수.
part of 'flow-localization.dart';

/// 흐름의 구매자 문구 가운데 이 언어 번역이 비어 있는 칸이 하나라도 있는지 판정합니다(「번역 필요」 배지).
///
/// 입력 안내·판매자 문구·플랫폼 행동 이름은 번역 칸이 아닙니다(문구 목록에 없습니다).
bool flowLocalizationNeedsTranslation(List<FlowText> texts, Map<String, String>? translation) =>
    texts.any((text) => (translation?[text.key] ?? '').trim().isEmpty);
