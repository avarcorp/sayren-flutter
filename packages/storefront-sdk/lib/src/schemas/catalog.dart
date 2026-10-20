import '../zod.dart';

/// 카테고리 트리의 노드 하나입니다.
class CategoryNode extends ParsedObject {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [categoryNodeSchema]의 `parse`를 사용하십시오.
  CategoryNode.fromJson(super.json) : super.fromJson();

  /// 카테고리 ID입니다. 상품 검색의 카테고리 조건에 사용합니다.
  String get categoryId => json['categoryId'] as String;

  /// 카테고리 이름입니다. 요청 언어로 번역한 값이고, 번역이 없으면 상점 기본 언어입니다.
  String get name => json['name'] as String;

  /// 깊이입니다. 최상위가 1이고 최대 4입니다.
  int get depth => json['depth'] as int;

  /// 하위 카테고리입니다. 없으면 빈 목록입니다.
  List<CategoryNode> get children => (json['children'] as List).cast<CategoryNode>();
}

/// [CategoryNode] 스키마입니다. 하위 카테고리까지 재귀로 검증합니다.
final ZodType<CategoryNode> categoryNodeSchema = z.lazy(() => z.object({
      'categoryId': z.string(),
      'name': z.string(),
      'depth': z.number().int_().gte(1).lte(4),
      'children': z.array(categoryNodeSchema),
    }, CategoryNode.fromJson));

/// [StorefrontCollection] 스키마입니다.
final storefrontCollectionSchema = z.object({
  'collectionId': z.string(),
  'slug': z.string(),
  'title': z.string(),
  'description': z.string(),
  'imageUrl': z.string().nullable(),
  'startsAt': z.string().nullable(),
  'endsAt': z.string().nullable(),
}, StorefrontCollection.fromJson);

/// 노출 중인 컬렉션입니다. 기획전·추천 묶음처럼 셀러가 고른 상품 모음입니다.
class StorefrontCollection extends ParsedObject {
  /// 검증을 마친 JSON으로 만듭니다. 서버 응답을 직접 읽을 때는 [storefrontCollectionSchema]의 `parse`를 사용하십시오.
  StorefrontCollection.fromJson(super.json) : super.fromJson();

  /// 컬렉션 ID입니다.
  String get collectionId => json['collectionId'] as String;

  /// 컬렉션 주소에 사용하는 이름입니다. 컬렉션 상세·상품 조회에 사용합니다.
  String get slug => json['slug'] as String;

  /// 제목입니다.
  String get title => json['title'] as String;

  /// 설명입니다. 없으면 빈 문자열입니다.
  String get description => json['description'] as String;

  /// 대표 이미지 주소입니다. 없으면 null입니다.
  String? get imageUrl => json['imageUrl'] as String?;

  /// 노출 시작 시각(ISO 8601)입니다. 없으면 null입니다.
  String? get startsAt => json['startsAt'] as String?;

  /// 노출 종료 시각(ISO 8601)입니다. 없으면 null이고 끝나지 않습니다.
  String? get endsAt => json['endsAt'] as String?;
}
