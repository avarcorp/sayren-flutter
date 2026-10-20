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
  /// final page = Page.fromJson(json, storefrontCollectionSchema);
  /// ```
  factory Page.fromJson(Map<String, Object?> json, ZodType<T> item) => pageSchema(item).parse(json);

  /// 이 페이지의 항목입니다.
  List<T> get contents => (_j['contents'] as List).cast<T>();
}

/// 항목 스키마 [item]으로 페이지 응답 스키마를 만듭니다.
///
/// ```dart
/// final schema = pageSchema(storefrontCollectionSchema);
/// final page = schema.parse(json);
/// ```
ZodObject<Page<T>> pageSchema<T>(ZodType<T> item) => pageInfoSchema.extend({'contents': z.array<T>(item)}, Page<T>._);
