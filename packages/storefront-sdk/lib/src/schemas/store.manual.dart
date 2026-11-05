// 손으로 쓴 부분 — store.ts의 사업자 정보 표시 함수.
part of 'store.dart';

/// 사업자등록번호 10자리를 `123-45-67890`으로 끊습니다. 10자리 숫자가 아니면 적힌 그대로(앞뒤 공백 제외)입니다.
String formatBusinessNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length == 10
      ? '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}'
      : value.trim();
}

const _sellerInfoFields = <SellerInfoField>[
  'businessName',
  'representativeName',
  'businessNumber',
  'mailOrderSalesNumber',
  'businessAddress',
  'customerCenterPhone',
  'customerCenterEmail',
  'privacyOfficerName',
  'privacyOfficerEmail',
];

/// 푸터·판매자 정보에 보일 사업자 정보 줄을 만듭니다.
///
/// 셀러가 정한 항목만 이 순서로 냅니다(비었으면 그 줄이 없습니다). 사업자등록번호는 끊어 보입니다.
/// 라벨(「상호」 등)은 화면이 정합니다. 값을 화면 코드에 적지 않고 이 결과만 그리십시오.
List<({SellerInfoField field, String value})> sellerInfoOf(StorefrontStore store) {
  final j = jsonOf(store);
  return [
    for (final field in _sellerInfoFields)
      if ((j[field] as String?)?.trim() case final value? when value.isNotEmpty)
        (field: field, value: field == 'businessNumber' ? formatBusinessNumber(value) : value),
  ];
}
