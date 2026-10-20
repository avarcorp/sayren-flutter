import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';
import 'package:sayren_storefront_sdk/src/zod.dart' show compact;
import 'package:flutter_test/flutter_test.dart';

const _envelopeOk = {
  'meta': {'status': 200, 'code': 'OK', 'message': 'OK', 'isSuccess': true},
  'error': null
};

StorefrontClient _client(Object? data, {List<http.Request>? sent}) => createStorefrontClient(StorefrontClientOptions(
      baseUrl: 'https://api.example.test/storefront/v1',
      storeCode: 'demo',
      fetch: (request) async {
        sent?.add(request);
        return http.Response(jsonEncode({..._envelopeOk, 'data': data}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      },
    ));

final _storeJson = <String, Object?>{
  'storeCode': 'demo',
  'name': '데모',
  'logoUrl': null,
  'customerCenterPhone': null,
  'businessHours': null,
  'guestCheckout': true,
  'loginMethods': ['password'],
};

void main() {
  group('요청 검증 실패', () {
    test('Future 오류로 전달하고 요청을 보내지 않는다', () async {
      final sent = <http.Request>[];
      final future = _client(null, sent: sent).member.updateConsents(ConsentUpdateRequest());
      await expectLater(future, throwsA(isA<ZodError>().having((e) => e.issues.single.code, 'code', 'custom')));
      expect(sent, isEmpty);
    });

    test('catchError로 잡힌다', () async {
      final caught = await _client(null)
          .member
          .updateConsents(ConsentUpdateRequest(terms: false))
          .then<Object?>((_) => null)
          .catchError((Object e) => e);
      expect(caught, isA<ZodError>());
    });
  });

  group('fromJson', () {
    test('스키마로 검증하고 기본값을 채운다', () {
      final store = StorefrontStore.fromJson(_storeJson);
      expect(store.locale, 'ko');
      expect(store.markets, isEmpty);
      expect(store.checkoutAvailable, isTrue);
      expect(store.businessName, isNull);
    });

    test('계약에 맞지 않으면 ZodError를 던진다', () {
      expect(
          () => StorefrontStore.fromJson({
                ..._storeJson,
                'loginMethods': ['apple']
              }),
          throwsA(isA<ZodError>()));
      expect(() => PageInfo.fromJson({'page': 1}), throwsA(isA<ZodError>()));
    });

    test('Page.fromJson은 항목 스키마로 검증한다', () {
      final page = Page.fromJson({
        'page': 1,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
        'contents': [
          {'categoryId': 'c', 'name': '의류', 'depth': 1, 'children': []},
        ],
      }, categoryNodeSchema);
      expect(page.contents.single.name, '의류');
    });
  });

  group('생성자', () {
    test('파싱 결과와 같은 모델을 만든다', () {
      final built = StorefrontStore(
        storeCode: 'demo',
        name: '데모',
        logoUrl: null,
        customerCenterPhone: null,
        businessHours: null,
        guestCheckout: true,
        loginMethods: ['password'],
      );
      expect(built, StorefrontStore.fromJson(_storeJson));
      expect(built.toJson(), StorefrontStore.fromJson(_storeJson).toJson());
    });

    test('선택 필드를 생략하면 toJson에 키가 없다', () {
      final market = StorefrontMarket(marketId: 'm', name: '한국', currency: 'KRW', countries: ['KR']);
      expect(market.toJson().containsKey('locales'), isFalse);
      expect(market.toJson()['checkoutAvailable'], isTrue);
    });

    test('응답 모델을 가짜 응답으로 돌려줄 수 있다', () async {
      final fake = CategoryNode(categoryId: 'c', name: '의류', depth: 1, children: []);
      final result = await _client([fake.toJson()]).catalog.listCategories();
      expect(result.single, fake);
    });
  });

  group('Nullable', () {
    test('생략·null·값을 구분한다', () {
      expect(compactForTest({'a': null}), isEmpty);
      expect(compactForTest({'a': const Nullable<String>(null)}), {'a': null});
      expect(compactForTest({'a': const Nullable('x')}), {'a': 'x'});
    });
  });
}

/// `Nullable`을 받는 요청 모델이 아직 없어, 같은 규칙(src의 compact)을 직접 확인한다
Map<String, Object?> compactForTest(Map<String, Object?> fields) => compact(fields);
