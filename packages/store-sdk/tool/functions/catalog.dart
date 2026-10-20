// 함수 대조 어댑터 — tool/parity/store/functions/*.json의 인자(JSON)를 Dart 인자로 바꿔 부르고 결과를 JSON 값으로 돌려준다.
import 'package:sayren_store_sdk/sayren_store_sdk.dart';

Map<String, Object?> _m(Object? v) => (v as Map).cast<String, Object?>();

List<Object?> _l(Object? v) => (v as List).cast<Object?>();

/// `{ "$date": ISO }` → DateTime
DateTime _date(Object? v) => DateTime.parse(_m(v)[r'$date'] as String);

/// `{ "$map": [[k, v], …] }` → Map
Map<String, num> _numMap(Object? v) => {
      for (final e in _l(_m(v)[r'$map'])) (_l(e)[0] as String): _l(e)[1] as num,
    };

List<({String categoryId, String? parentId})> _categories(Object? v) => [
      for (final c in _l(v)) (categoryId: _m(c)['categoryId'] as String, parentId: _m(c)['parentId'] as String?),
    ];

List<CollectionRuleView> _rules(Object? v) => [for (final r in _l(v)) CollectionRuleView.fromJson(_m(r))];

CollectionRuleContext _context(Object? v) =>
    CollectionRuleContext(now: _date(_m(v)['now']), categories: _categories(_m(v)['categories']));

CollectionRuleProduct _product(Object? v) {
  final p = _m(v);
  return CollectionRuleProduct(
    createdAt: p['createdAt'] as String,
    categoryId: p['categoryId'] as String?,
    salePrice: p['salePrice'] as int,
    discountedPrice: p['discountedPrice'] as int?,
  );
}

Object? _arg(List<Object?> a, int i) => i < a.length ? a[i] : null;

/// 함수 이름 → 어댑터
final Map<String, Object? Function(List<Object?> a)> catalogFunctions = {
  // collection
  'collectionStateOf': (a) {
    final c = _m(a[0]);
    return collectionStateOf(
      (visible: c['visible'] as bool, startsAt: c['startsAt'] as String?, endsAt: c['endsAt'] as String?),
      _date(a[1]),
    );
  },
  'descendantCategoryIdsOf': (a) => descendantCategoryIdsOf(_l(a[0]).cast<String>(), _categories(a[1])),
  'matchesCollectionRules': (a) => matchesCollectionRules(_product(a[0]), _rules(a[1]), _context(a[2])),
  'bestSellingRuleOf': (a) {
    final r = bestSellingRuleOf(_rules(a[0]));
    return r == null ? null : {'days': r.days, 'top': r.top};
  },
  'rankBestSelling': (a) => rankBestSelling<Map<String, Object?>>(
        [for (final p in _l(a[0])) _m(p)],
        _numMap(a[1]),
        a[2] as int,
      ),
  'collectionRuleCategoryIds': (a) => collectionRuleCategoryIds(_rules(a[0])),
  // fulfillment
  'fulfillmentTypeOf': (a) => fulfillmentTypeOf(_arg(a, 0) as String?),
  'fulfillmentRuleOf': (a) => fulfillmentRuleOf(_arg(a, 0) as String?).toJson(),
  'defaultFulfillmentMethodOf': (a) => defaultFulfillmentMethodOf(_arg(a, 0) as String?),
  'fulfillmentMethodsOf': (a) => fulfillmentMethodsOf(
        type: _m(a[0])['type'] as String,
        methods: (_m(a[0])['methods'] as List?)?.cast<String>(),
      ),
  'fulfillmentMethodOf': (a) => fulfillmentMethodOf(_arg(a, 0) as String?, _arg(a, 1) as String?),
  'requiresShipping': (a) => requiresShipping(_arg(a, 0) as String?, _arg(a, 1) as String?),
  'requiresCollection': (a) => requiresCollection(_arg(a, 0) as String?),
  // product
  'customInputLabelForbiddenWord': (a) => customInputLabelForbiddenWord(a[0] as String),
  'productImageRejection': (a) => productImageRejection(a[0] as String)?.toJson(),
  'productLocalizationNeedsTranslation': (a) => productLocalizationNeedsTranslation(
        ProductLocalization.fromJson(_m(a[0])),
        description: _m(a[1])['description'] as String?,
      ),
  // upload
  'uploadExtensionOf': (a) => uploadExtensionOf(a[0] as String),
  'uploadRejection': (a) => uploadRejection(a[0] as String, a[1] as String, _arg(a, 2) as num?)?.toJson(),
  // stay
  'nightsOf': (a) =>
      nightsOf(StayRange(checkIn: _m(a[0])['checkIn'] as String, checkOut: _m(a[0])['checkOut'] as String)),
  // coupon
  'normalizeCouponCode': (a) => normalizeCouponCode(a[0] as String),
};
