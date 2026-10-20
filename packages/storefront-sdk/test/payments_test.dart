// 결제창 흐름(Dart 설계) — 가짜 PaymentsEnv로 start·retry·open의 복귀·실패·닫기·확정 조회를 확인한다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sayren_storefront_sdk/sayren_storefront_sdk.dart';
import 'package:sayren_storefront_sdk/src/payments/index.dart';
import 'package:sayren_storefront_sdk/src/payments/launch.dart';

const _returnUrl = 'https://shop.example.com/payments/return';

Map<String, Object?> _ok(Object? data) => {
      'meta': {'status': 200, 'code': 'OK', 'message': 'OK', 'isSuccess': true},
      'data': data,
      'error': null,
    };

Map<String, Object?> _start({Map<String, Object?>? launch, String? payUrl, String status = 'pending'}) => {
      'paymentId': 'pay_1',
      'status': status,
      'orderId': null,
      'attemptId': 'att_1',
      'option': {'pg': 'tosspayments', 'method': 'CARD'},
      'payUrl': payUrl,
      'launch': launch,
      'expiresAt': '2026-01-01T00:30:00.000Z',
      'testPayment': true,
      'amounts': {
        'productAmount': 1000,
        'deliveryFee': 0,
        'totalAmount': 1000,
        'couponDiscountAmount': 0,
        'deliveryDiscountAmount': 0,
        'pointAmount': 0,
      },
      'delivery': {
        'baseFee': 0,
        'remoteSurcharge': 0,
        'remoteArea': 'NONE',
        'remoteAreaLabel': '',
        'bundleCount': 1,
        'freeByThreshold': true,
        'zipCode': null,
      },
    };

Map<String, Object?> _status(String result, {String? orderId}) => {
      'paymentId': 'pay_1',
      'status': 'pending',
      'result': result,
      'orderId': orderId,
      'lastFailure': null,
      'testPayment': true,
      'expiresAt': '2026-01-01T00:30:00.000Z',
    };

const _toss = {
  'type': 'tosspayments',
  'attemptId': 'att_1',
  'callbackToken': 'tok_1',
  'clientKey': 'ck',
  'request': {'amount': 1000},
};

class _FakeEnv implements PaymentsEnv {
  _FakeEnv(this.outcome);

  final ({String? returnUrl, LaunchFailure? failure}) outcome;
  final presented = <Map<String, Object?>>[];
  var clock = DateTime.utc(2026);
  var waits = 0;

  @override
  Future<({String? returnUrl, LaunchFailure? failure})> present(
      {String? html, String? url, required String baseUrl, required String returnUrl}) async {
    presented.add({'html': html, 'url': url, 'baseUrl': baseUrl, 'returnUrl': returnUrl});
    return outcome;
  }

  @override
  String? currentUrl() => null;

  @override
  DateTime now() => clock;

  @override
  Future<void> wait(Duration duration) async {
    waits++;
    clock = clock.add(duration);
  }
}

/// 요청 순서대로 응답을 돌려주는 클라이언트
({StorefrontClient client, List<http.Request> sent}) _client(List<Map<String, Object?>> bodies) {
  final sent = <http.Request>[];
  final queue = [...bodies];
  return (
    client: createStorefrontClient(StorefrontClientOptions(
      baseUrl: 'https://api.example.test/storefront/v1',
      storeCode: 'demo',
      fetch: (request) async {
        sent.add(request);
        return http.Response(jsonEncode(queue.removeAt(0)), 200, headers: {'content-type': 'application/json'});
      },
    )),
    sent: sent,
  );
}

String _path(http.Request r) => r.url.path.replaceFirst('/storefront/v1', '');

Map<String, Object?> _body(http.Request r) => jsonDecode(r.body) as Map<String, Object?>;

void main() {
  test('복귀 주소로 돌아오면 승인하고 결과를 돌려준다', () async {
    final env = _FakeEnv((
      returnUrl: '$_returnUrl?sayrenPaymentId=pay_1&sayrenAttemptId=att_1&sayrenToken=tok_1&sayrenPg=tosspayments'
          '&sayrenResult=success&paymentKey=pk_1&amount=1000',
      failure: null,
    ));
    final c = _client([
      _ok(_start(launch: _toss)),
      _ok({'orderId': 'ord_1', 'status': 'PAID', 'totalAmount': 1000, 'paidAt': '2026-01-01T00:00:00.000Z'}),
      _ok(_status('COMPLETED', orderId: 'ord_1')),
    ]);
    final payments = createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env);
    final result = await payments.start('chk_1', const StartOptions());
    expect(result, isA<PaymentResultCompleted>().having((r) => r.orderId, 'orderId', 'ord_1'));
    expect(c.sent.map(_path), ['/checkout/chk_1/payment', '/payments/pay_1/confirm', '/payments/pay_1']);
    expect(_body(c.sent[1]), {'attemptId': 'att_1', 'callbackToken': 'tok_1', 'pgToken': 'pk_1', 'amount': 1000});
    expect(env.presented.single['baseUrl'], 'https://shop.example.com');
    expect(env.presented.single['url'], isNull);
    expect(env.presented.single['html'], contains('"clientKey":"ck"'));
  });

  test('결제창을 열지 못하면 그 실패를 보고한다', () async {
    final env = _FakeEnv((returnUrl: null, failure: (category: 'PREPARE_FAILURE', code: 'PG_SCRIPT_UNAVAILABLE', message: 'm')));
    final c = _client([
      _ok(_start(launch: _toss)),
      _ok({'paymentId': 'pay_1', 'attemptId': 'att_1', 'category': 'PREPARE_FAILURE'}),
      _ok(_status('FAILED')),
    ]);
    final result = await createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env)
        .start('chk_1', const StartOptions());
    expect(result, isA<PaymentResultFailed>());
    expect(_path(c.sent[1]), '/payments/pay_1/failure');
    expect(_body(c.sent[1]), {
      'attemptId': 'att_1',
      'callbackToken': 'tok_1',
      'category': 'PREPARE_FAILURE',
      'code': 'PG_SCRIPT_UNAVAILABLE',
      'message': 'm',
    });
  });

  test('구매자가 닫으면 취소로 보고하고, 대기 중이면 CANCELED다', () async {
    final env = _FakeEnv((returnUrl: null, failure: null));
    final c = _client([
      _ok(_start(launch: _toss)),
      _ok({'paymentId': 'pay_1', 'attemptId': 'att_1', 'category': 'USER_CANCELED'}),
      _ok(_status('PENDING')),
    ]);
    final result = await createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env)
        .start('chk_1', const StartOptions());
    expect(result, isA<PaymentResultCanceled>().having((r) => r.code, 'code', 'POPUP_CLOSED'));
    expect(_body(c.sent[1])['category'], 'USER_CANCELED');
    expect(_body(c.sent[1])['code'], 'USER_CANCEL');
  });

  test('모르는 결제창은 payUrl을 열고, 닫으면 보고 없이 상태로 정한다', () async {
    final env = _FakeEnv((returnUrl: null, failure: null));
    final c = _client([
      _ok(_start(launch: {'type': 'newpg', 'attemptId': 'att_1', 'callbackToken': 'tok_1'}, payUrl: 'https://pay.example.test/p')),
      _ok(_status('PENDING')),
    ]);
    final result = await createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env)
        .start('chk_1', const StartOptions());
    expect(env.presented.single['url'], 'https://pay.example.test/p');
    expect(env.presented.single['html'], isNull);
    expect(c.sent.map(_path), ['/checkout/chk_1/payment', '/payments/pay_1']);
    expect(result, isA<PaymentResultCanceled>());
  });

  test('확인 중이면 만료 시각까지 조회해 확정된 결과를 돌려준다', () async {
    final env = _FakeEnv((
      returnUrl: '$_returnUrl?sayrenPaymentId=pay_1',
      failure: null,
    ));
    final c = _client([
      _ok(_start(launch: _toss)),
      _ok(_status('PROCESSING')),
      _ok(_status('PROCESSING')),
      _ok(_status('COMPLETED', orderId: 'ord_1')),
    ]);
    final result = await createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env)
        .start('chk_1', const StartOptions());
    expect(result, isA<PaymentResultCompleted>());
    expect(env.waits, 2);
  });

  test('만료 시각이 지나도 확인 중이면 PROCESSING이다', () async {
    final env = _FakeEnv((returnUrl: '$_returnUrl?sayrenPaymentId=pay_1', failure: null))
      ..clock = DateTime.utc(2026, 1, 1, 0, 30);
    final c = _client([_ok(_start(launch: _toss)), _ok(_status('PROCESSING'))]);
    final result = await createPaymentsWith(PaymentsOptions(client: c.client, returnUrl: _returnUrl), env)
        .start('chk_1', const StartOptions());
    expect(result, isA<PaymentResultProcessing>());
    expect(env.waits, 0);
  });

  test('복귀 주소가 없으면 결제 시작 전에 실패한다', () async {
    final c = _client([]);
    final payments = createPaymentsWith(PaymentsOptions(client: c.client), _FakeEnv((returnUrl: null, failure: null)));
    await expectLater(payments.start('chk_1', const StartOptions()), throwsStateError);
    expect(c.sent, isEmpty);
  });

  test('결제창 HTML은 launch 값을 그대로 넘기고 </script>를 끊지 않는다', () {
    final html = launchHtml(PaymentLaunch.fromJson({..._toss, 'request': {'orderName': '</script><b>'}}));
    expect(html, contains('sayrenLaunch.launchPayment('));
    expect(html, contains(r'<\/script>'));
    expect('</script>'.allMatches(html).length, 1); // 묶음과 실행 코드를 담은 스크립트 태그 하나뿐이다
  });
}
