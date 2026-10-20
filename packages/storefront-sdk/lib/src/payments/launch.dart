// 손으로 쓴 파일 — Node src/payments/launch.ts의 순수 함수에 대응한다(SDK 내부용).
// PG 결제창 실행(launchPayment)은 Node 코드를 그대로 묶은 launch_js.dart를 WebView에서 실행한다.
import 'dart:convert';

import '../http.dart';
import '../schemas/checkout.dart';
import 'launch_js.dart';

/// 결제창을 열지 못했다 — 실패 보고의 분류
typedef LaunchFailure = ({String category, String code, String message});

/// 포트원 V2의 구매자 취소 — code·pgCode 양쪽에서 찾는다. 판정이 안 되면 거절로 본다
const PORTONE_CANCEL_CODES = {'PAY_PROCESS_CANCELED', 'USER_CANCEL', 'CANCELED_BY_USER', 'FAILURE_TYPE_USER_CANCEL'};

/// 토스페이먼츠에서 「구매자가 결제창을 닫음」을 뜻하는 코드
const _tossCancelCodes = {'USER_CANCEL', 'PAY_PROCESS_CANCELED'};

/// 네이버페이 결제창의 구매자 취소 `resultCode`
const _naverpayCancelCodes = {'UserCancel'};

/// 이 SDK가 띄울 수 있는 결제창인가 — 모르는 `type`이면 결제 서비스(`payUrl`)로 연다
bool launchable(PaymentLaunch launch) =>
    const ['tosspayments', 'portone', 'kakaopay', 'naverpay', 'paypal', 'mock'].contains(launch.type);

/// 복귀 주소 해석 결과
sealed class ReturnDecision {
  /// 결과를 만든다.
  const ReturnDecision();

  /// 결제 id. 판정할 것이 없으면 null일 수 있다
  String? get paymentId;

  /// JSON으로 바꾼다(대조 하네스용).
  Map<String, Object?> toJson();
}

/// PG가 승인 키를 들고 돌아왔다 → 승인
final class ReturnConfirm extends ReturnDecision {
  /// 결과를 만든다.
  const ReturnConfirm(this.paymentId, this.attemptId, this.callbackToken, this.pgToken, [this.amount]);

  @override
  final String paymentId;

  /// 결제 시도 id
  final String attemptId;

  /// 복귀 콜백 토큰
  final String callbackToken;

  /// PG 승인 키
  final String pgToken;

  /// PG가 알린 금액(토스페이먼츠)
  final num? amount;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'confirm',
        'paymentId': paymentId,
        'attemptId': attemptId,
        'callbackToken': callbackToken,
        'pgToken': pgToken,
        if (amount != null) 'amount': amount,
      };
}

/// PG가 실패·취소로 돌아왔다 → 실패 보고
final class ReturnFailure extends ReturnDecision {
  /// 결과를 만든다.
  const ReturnFailure(this.paymentId, this.attemptId, this.callbackToken, this.category, this.code, this.message);

  @override
  final String paymentId;

  /// 결제 시도 id
  final String attemptId;

  /// 복귀 콜백 토큰
  final String callbackToken;

  /// 실패 분류
  final String category;

  /// 실패 코드(100자까지)
  final String code;

  /// 실패 안내(500자까지)
  final String message;

  @override
  Map<String, Object?> toJson() => {
        'kind': 'failure',
        'paymentId': paymentId,
        'attemptId': attemptId,
        'callbackToken': callbackToken,
        'category': category,
        'code': code,
        'message': message,
      };
}

/// 판정할 것이 없다 — 아무것도 보고하지 않고 상태 조회로 결과를 정한다
final class ReturnStatus extends ReturnDecision {
  /// 결과를 만든다.
  const ReturnStatus(this.paymentId);

  @override
  final String? paymentId;

  @override
  Map<String, Object?> toJson() => {'kind': 'status', 'paymentId': paymentId};
}

/// JS `String.prototype.slice(0, n)`(UTF-16 기준)
String _slice(String value, int n) => value.length > n ? value.substring(0, n) : value;

/// PG 복귀 쿼리 → 할 일. 순수 함수다. 콜백 토큰(`sayrenToken`)이 없으면 아무것도 보고하지 않는다
ReturnDecision readPaymentReturn(Map<String, String> params) {
  String? get(String key) => params[key];
  final paymentId = get('sayrenPaymentId');
  final callbackToken = get('sayrenToken');
  final attemptId = get('sayrenAttemptId');
  if (paymentId == null ||
      paymentId.isEmpty ||
      callbackToken == null ||
      callbackToken.isEmpty ||
      attemptId == null ||
      attemptId.isEmpty) {
    return ReturnStatus(paymentId == null || paymentId.isEmpty ? null : paymentId);
  }
  final result = get('sayrenResult');
  ReturnDecision failure(String category, String code, String message) =>
      ReturnFailure(paymentId, attemptId, callbackToken, category, _slice(code, 100), _slice(message, 500));
  bool present(String? v) => v != null && v.isNotEmpty;

  switch (get('sayrenPg')) {
    case 'portone':
      final code = get('code');
      if (present(code)) {
        final pgCode = get('pgCode');
        final canceled =
            PORTONE_CANCEL_CODES.contains(code) || (pgCode != null && PORTONE_CANCEL_CODES.contains(pgCode));
        return failure(canceled ? 'USER_CANCELED' : 'DECLINED', pgCode ?? code!,
            get('pgMessage') ?? get('message') ?? '결제에 실패했습니다');
      }
      final txId = get('txId');
      return present(txId) ? ReturnConfirm(paymentId, attemptId, callbackToken, txId!) : ReturnStatus(paymentId);
    case 'kakaopay':
      if (result == 'cancel') return failure('USER_CANCELED', 'USER_CANCEL', '결제를 취소했습니다');
      if (result == 'fail') return failure('DECLINED', 'KAKAOPAY_FAIL', '결제에 실패했습니다');
      final token = get('pg_token');
      return result == 'success' && present(token)
          ? ReturnConfirm(paymentId, attemptId, callbackToken, token!)
          : ReturnStatus(paymentId);
    case 'naverpay':
      final code = get('resultCode');
      if (!present(code)) return ReturnStatus(paymentId);
      if (code != 'Success') {
        return failure(_naverpayCancelCodes.contains(code) ? 'USER_CANCELED' : 'DECLINED', code!,
            get('resultMessage') ?? '결제에 실패했습니다');
      }
      final naverPaymentId = get('paymentId');
      return present(naverPaymentId)
          ? ReturnConfirm(paymentId, attemptId, callbackToken, naverPaymentId!)
          : ReturnStatus(paymentId);
    case 'tosspayments':
      if (result == 'fail') {
        final code = get('code');
        if (!present(code)) return ReturnStatus(paymentId);
        return failure(
            _tossCancelCodes.contains(code) ? 'USER_CANCELED' : 'DECLINED', code!, get('message') ?? '결제에 실패했습니다');
      }
      final paymentKey = get('paymentKey');
      final amount = _jsNumber(get('amount'));
      if (result != 'success' || !present(paymentKey) || amount == null || !amount.isFinite) {
        return ReturnStatus(paymentId);
      }
      return ReturnConfirm(paymentId, attemptId, callbackToken, paymentKey!, amount);
    default:
      return ReturnStatus(paymentId);
  }
}

/// JS `Number(value)` — undefined는 NaN(null로 돌려준다), 빈 문자열·공백은 0
num? _jsNumber(String? value) {
  if (value == null) return null;
  final t = value.trim();
  if (t.isEmpty) return 0;
  final n = num.tryParse(t);
  if (n != null) return n;
  if (RegExp(r'^[+-]?Infinity$').hasMatch(t)) return t.startsWith('-') ? double.negativeInfinity : double.infinity;
  return null;
}

/// 복귀 주소에서 지울 쿼리 — PG 승인 키·콜백 토큰. `sayrenPaymentId`는 남긴다
const RETURN_SECRET_PARAMS = [
  'sayrenToken',
  'sayrenAttemptId',
  'sayrenPg',
  'sayrenResult',
  'paymentKey',
  'orderId',
  'amount',
  'paymentId',
  'txId',
  'code',
  'message',
  'pgCode',
  'pgMessage',
  'pg_token',
  'resultCode',
  'resultMessage',
  'reserveId',
];

/// 쿼리를 `URLSearchParams`처럼 순서대로 읽는다(키·값 쌍, `+`는 공백)
List<(String, String)> searchParams(Uri uri) => [
      for (final pair in uri.query.isEmpty ? const <String>[] : uri.query.split('&'))
        if (pair.isNotEmpty)
          (
            Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(0, pair.indexOf('=')) : pair),
            Uri.decodeQueryComponent(pair.contains('=') ? pair.substring(pair.indexOf('=') + 1) : ''),
          ),
    ];

/// 키마다 첫 값 — `URLSearchParams.get`과 같다
Map<String, String> firstParams(Uri uri) {
  final out = <String, String>{};
  for (final (k, v) in searchParams(uri)) {
    out.putIfAbsent(k, () => v);
  }
  return out;
}

/// 복귀 주소에서 승인 키·토큰을 지운 주소. 남은 쿼리는 `URLSearchParams`처럼 다시 쓴다
String scrubReturnUrl(String url) {
  final uri = Uri.parse(url);
  final kept = [
    for (final (k, v) in searchParams(uri))
      if (!RETURN_SECRET_PARAMS.contains(k)) '${formEncode(k)}=${formEncode(v)}',
  ];
  // WHATWG URL처럼 특수 스킴(http 등)의 빈 경로는 `/`다
  final special = const {'http', 'https', 'ws', 'wss', 'ftp', 'file'}.contains(uri.scheme);
  final head = Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path.isEmpty && special ? '/' : uri.path,
  ).toString();
  return '$head${kept.isEmpty ? '' : '?${kept.join('&')}'}${uri.hasFragment ? '#${uri.fragment}' : ''}';
}

/// WebView 결제창 HTML — Node launchPayment를 그대로 실행하고, 결제창을 열지 못하면 `SayrenPayments` 채널로 실패를 알린다
String launchHtml(PaymentLaunch launch) {
  final launchJson = jsonEncode(launch.toJson()).replaceAll('</', r'<\/');
  return '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body><script>
$launchScript
(function () {
  var loads = {};
  function loadScript(src, global) {
    if (window[global]) return Promise.resolve(window[global]);
    if (loads[src]) return loads[src];
    loads[src] = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.onload = function () { window[global] ? resolve(window[global]) : reject(new Error(global + '을 찾지 못했습니다')); };
      s.onerror = function () { delete loads[src]; reject(new Error(src + '를 불러오지 못했습니다')); };
      document.head.appendChild(s);
    });
    return loads[src];
  }
  function report(failure) { SayrenPayments.postMessage(JSON.stringify(failure)); }
  var env = { loadScript: loadScript, navigate: function (url) { location.assign(url); }, desktop: function () { return false; } };
  sayrenLaunch.launchPayment($launchJson, env).then(function (failure) { if (failure) report(failure); }, function (error) {
    report({ category: 'PREPARE_FAILURE', code: 'LAUNCH_FAILED', message: (error && error.message) || '결제창을 열지 못했습니다' });
  });
})();
</script></body></html>''';
}
