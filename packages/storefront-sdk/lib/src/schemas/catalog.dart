import '../zod.dart';

class CategoryNode extends ParsedObject {
  CategoryNode.fromJson(super.json) : super.fromJson();

  String get categoryId => json['categoryId'] as String;
  String get name => json['name'] as String;
  int get depth => json['depth'] as int;
  List<CategoryNode> get children => (json['children'] as List).cast<CategoryNode>();
}

final ZodType<CategoryNode> categoryNodeSchema = z.lazy(() => z.object({
      'categoryId': z.string(),
      'name': z.string(),
      'depth': z.number().int_().gte(1).lte(4),
      'children': z.array(categoryNodeSchema),
    }, CategoryNode.fromJson));

final storefrontCollectionSchema = z.object({
  'collectionId': z.string(),
  'slug': z.string(),
  'title': z.string(),
  'description': z.string(),
  'imageUrl': z.string().nullable(),
  'startsAt': z.string().nullable(),
  'endsAt': z.string().nullable(),
}, StorefrontCollection.fromJson);

class StorefrontCollection extends ParsedObject {
  StorefrontCollection.fromJson(super.json) : super.fromJson();

  String get collectionId => json['collectionId'] as String;
  String get slug => json['slug'] as String;
  String get title => json['title'] as String;
  String get description => json['description'] as String;
  String? get imageUrl => json['imageUrl'] as String?;
  String? get startsAt => json['startsAt'] as String?;
  String? get endsAt => json['endsAt'] as String?;
}
