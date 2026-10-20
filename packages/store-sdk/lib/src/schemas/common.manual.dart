// 손으로 쓴 부분 — common.ts의 pageSchema와 그 출력 Page<T>.
part of 'common.dart';

/// 목록 응답 한 페이지입니다. [PageInfo]에 항목 목록 [contents]를 더합니다.
///
/// Node의 `pageSchema(item)` 출력(`PageInfo` + `contents`인 익명 객체 타입)에 대응합니다.
class Page<T> extends PageInfo {
  /// [Page]를 만듭니다. 검증하지 않으므로 테스트·미리보기 데이터에 사용하십시오.
  Page({
    required int page,
    required int size,
    required int totalElements,
    required int totalPages,
    required List<T> contents,
  }) : super._({
          'page': page,
          'size': size,
          'totalElements': totalElements,
          'totalPages': totalPages,
          'contents': contents,
        });

  Page._(super.json) : super._();

  /// JSON을 항목 스키마 [item]으로 검증해 만듭니다. 맞지 않으면 [ZodError]를 던집니다.
  ///
  /// ```dart
  /// final page = Page.fromJson(json, productSummarySchema);
  /// ```
  factory Page.fromJson(Map<String, Object?> json, ZodType<T> item) => pageSchema(item).parse(json);

  /// 이 페이지의 항목입니다.
  List<T> get contents => (_j['contents'] as List).cast<T>();
}

/// 항목 스키마 [item]으로 페이지 응답 스키마를 만듭니다.
///
/// ```dart
/// final schema = pageSchema(productSummarySchema);
/// final page = schema.parse(json);
/// ```
ZodObject<Page<T>> pageSchema<T>(ZodType<T> item) => pageInfoSchema.extend({'contents': z.array<T>(item)}, Page<T>._);

/// 목록 쿼리의 `page`·`size` 스키마 모양입니다. OpenAPI 문서용이고 값은 쿼리 문자열입니다.
///
/// 서버는 숫자가 아니거나 범위를 벗어난 값을 기본값·상한으로 보정합니다.
Map<String, ZodType<Object?>> pageQueryShape({int defaultSize = 20, int maxSize = 100}) => {
      // 페이지 번호(1부터, 기본 1)
      'page': z.string().optional(),
      // 페이지 크기(기본 [defaultSize], 최대 [maxSize])
      'size': z.string().optional(),
    };
