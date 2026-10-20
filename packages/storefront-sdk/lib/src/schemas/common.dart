import '../zod.dart';

final pageInfoSchema = z.object(_pageInfoShape, PageInfo.fromJson);

final Map<String, ZodType<Object?>> _pageInfoShape = {
  'page': z.number().int_(),
  'size': z.number().int_(),
  'totalElements': z.number().int_(),
  'totalPages': z.number().int_(),
};

class PageInfo extends ParsedObject {
  PageInfo.fromJson(super.json) : super.fromJson();

  int get page => json['page'] as int;
  int get size => json['size'] as int;
  int get totalElements => json['totalElements'] as int;
  int get totalPages => json['totalPages'] as int;
}

/// `pageSchema(item)`의 출력 — Node는 `PageInfo` + `contents`인 익명 객체 타입이다
class Page<T> extends PageInfo {
  Page.fromJson(super.json) : super.fromJson();

  List<T> get contents => (json['contents'] as List).cast<T>();
}

ZodObject<Page<T>> pageSchema<T>(ZodType<T> item) =>
    pageInfoSchema.extend({'contents': z.array(item)}, Page<T>.fromJson);

class PageParams {
  const PageParams({this.page, this.size});

  final int? page;
  final int? size;

  Map<String, Object?> toJson() => compact({'page': page, 'size': size});
}
