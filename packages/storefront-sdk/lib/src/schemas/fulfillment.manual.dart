// 손으로 쓴 부분 — fulfillment.ts의 zod 클로저 구현.
part of 'fulfillment.dart';

const _knownTypes = ['SHIPPING', 'MANUAL'];

/// 모르는 이행 유형 transform — SDK가 모르는 유형을 `OTHER`로 읽는다
Object? _unknownFulfillmentView(Object? value) {
  final j = value as Map<String, Object?>;
  return UnknownFulfillmentView(
    type: 'OTHER',
    rawType: j['type'] as String,
    requiresShipping: j['requiresShipping'] as bool,
  );
}
