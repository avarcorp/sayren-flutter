import '../zod.dart';

/// 페이지 정보 스키마입니다. 목록 응답의 `page`·`size`·`totalElements`·`totalPages`를 검증합니다.
final pageInfoSchema = z.object(_pageInfoShape, PageInfo.fromJson);

final Map<String, ZodType<Object?>> _pageInfoShape = {
  'page': z.number().int_(),
  'size': z.number().int_(),
  'totalElements': z.number().int_(),
  'totalPages': z.number().int_(),
};

/// 목록 응답의 페이지 정보입니다.
class PageInfo extends ParsedObject {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [pageInfoSchema]의 `parse`를 사용하십시오.
  PageInfo.fromJson(super.json) : super.fromJson();

  /// 현재 페이지 번호입니다. 1부터 셉니다.
  int get page => json['page'] as int;

  /// 페이지 크기입니다.
  int get size => json['size'] as int;

  /// 전체 항목 수입니다.
  int get totalElements => json['totalElements'] as int;

  /// 전체 페이지 수입니다.
  int get totalPages => json['totalPages'] as int;
}

/// 목록 응답 한 페이지입니다. [PageInfo]에 항목 목록 [contents]를 더합니다.
class Page<T> extends PageInfo {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [pageSchema]로 만든 스키마의 `parse`를 사용하십시오.
  Page.fromJson(super.json) : super.fromJson();

  /// 이 페이지의 항목입니다.
  List<T> get contents => (json['contents'] as List).cast<T>();
}

/// 항목 스키마 [item]으로 페이지 응답 스키마를 만듭니다.
///
/// ```dart
/// final schema = pageSchema(storefrontCollectionSchema);
/// final page = schema.parse(json);
/// ```
ZodObject<Page<T>> pageSchema<T>(ZodType<T> item) =>
    pageInfoSchema.extend({'contents': z.array(item)}, Page<T>.fromJson);

/// 목록 요청의 페이지 파라미터입니다.
class PageParams {
  /// 파라미터를 만듭니다. 생략한 값은 서버 기본값을 사용합니다.
  const PageParams({this.page, this.size});

  /// 가져올 페이지 번호입니다. 1부터 셉니다.
  final int? page;

  /// 페이지 크기입니다.
  final int? size;

  /// 쿼리 파라미터로 바꿉니다. null인 값은 뺍니다.
  Map<String, Object?> toJson() => compact({'page': page, 'size': size});
}
