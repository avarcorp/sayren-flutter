// 손으로 쓴 파일 — Node src/payments/index.ts에 대응하는 순수 로직(createPaymentsWith).
// Flutter 기본 환경(WebView 결제창)과 createPayments는 flutter.dart에 있다(이 파일은 Flutter를 import하지 않는다).
import '../client.dart';
import '../http.dart';
import '../schemas/checkout.dart';
import '../schemas/coupon.dart';
import 'launch.dart';

/// PC·모바일 판정에 쓰는 기기 정보입니다.
class PaymentDevice {
  /// 기기 정보를 만듭니다.
  const PaymentDevice({required this.userAgent, required this.coarsePointer, required this.viewportWidth});

  /// User-Agent 문자열입니다.
  final String userAgent;

  /// 터치처럼 거친 포인터인지입니다.
  final bool coarsePointer;

  /// 화면 너비(논리 픽셀)입니다.
  final num viewportWidth;
}

/// 결제 결과입니다. 형태는 [status]로 나뉩니다.
///
/// ```dart
/// switch (result) {
///   case PaymentResultCompleted(:final orderId): // 주문 완료 화면
///   case PaymentResultFailed(:final message): // 실패 안내, 다른 결제수단으로 retry
///   case PaymentResultCanceled(): // 구매자가 결제창을 닫음
///   case PaymentResultProcessing(:final paymentId): // 확인 중, getStatus로 다시 조회
///   case PaymentResultInvalid(): // 결제 정보가 없는 복귀 주소
/// }
/// ```
sealed class PaymentResult {
  const PaymentResult();

  /// 결과 구분입니다. `COMPLETED`·`CANCELED`·`FAILED`·`PROCESSING`·`INVALID`입니다.
  String get status;

  /// JSON으로 바꿉니다.
  Map<String, Object?> toJson();
}

/// 결제가 끝나 주문이 만들어졌습니다.
final class PaymentResultCompleted extends PaymentResult {
  /// 결과를 만듭니다.
  const PaymentResultCompleted({required this.paymentId, required this.orderId});

  @override
  String get status => 'COMPLETED';

  /// 결제 ID입니다.
  final String paymentId;

  /// 만들어진 주문 ID입니다. 주문 완료 화면으로 보냅니다.
  final String orderId;

  @override
  Map<String, Object?> toJson() => {'status': status, 'paymentId': paymentId, 'orderId': orderId};
}

/// 구매자가 결제창을 닫았습니다. 같은 결제를 다른 옵션으로 [Payments.retry]할 수 있습니다.
final class PaymentResultCanceled extends PaymentResult {
  /// 결과를 만듭니다.
  const PaymentResultCanceled({required this.paymentId, required this.code, required this.message});

  @override
  String get status => 'CANCELED';

  /// 결제 ID입니다.
  final String paymentId;

  /// 사유 코드입니다.
  final String code;

  /// 구매자에게 보여 줄 안내입니다.
  final String message;

  @override
  Map<String, Object?> toJson() => {'status': status, 'paymentId': paymentId, 'code': code, 'message': message};
}

/// 카드 거절·결제 오류 등으로 실패했습니다. 같은 결제를 다른 옵션으로 [Payments.retry]할 수 있습니다.
final class PaymentResultFailed extends PaymentResult {
  /// 결과를 만듭니다.
  const PaymentResultFailed(
      {required this.paymentId, required this.code, required this.message, this.optionUnavailable});

  @override
  String get status => 'FAILED';

  /// 결제 ID입니다.
  final String paymentId;

  /// 사유 코드입니다.
  final String code;

  /// 구매자에게 보여 줄 안내입니다.
  final String message;

  /// 상점의 PG 설정 문제처럼 구매자가 고칠 수 없는 실패인지입니다. true면 그 옵션을 고르지 못하게 하고 다른 결제수단으로 retry하게 하십시오.
  final bool? optionUnavailable;

  @override
  Map<String, Object?> toJson() => {
        'status': status,
        'paymentId': paymentId,
        'code': code,
        'message': message,
        if (optionUnavailable != null) 'optionUnavailable': optionUnavailable,
      };
}

/// 결과를 확인하는 중입니다. [Payments.getStatus]로 다시 조회하십시오.
final class PaymentResultProcessing extends PaymentResult {
  /// 결과를 만듭니다.
  const PaymentResultProcessing({required this.paymentId});

  @override
  String get status => 'PROCESSING';

  /// 결제 ID입니다.
  final String paymentId;

  @override
  Map<String, Object?> toJson() => {'status': status, 'paymentId': paymentId};
}

/// 복귀 주소에 결제 정보가 없습니다(직접 연 주소 등).
final class PaymentResultInvalid extends PaymentResult {
  /// 결과를 만듭니다.
  const PaymentResultInvalid({required this.message});

  @override
  String get status => 'INVALID';

  /// 안내 문장입니다.
  final String message;

  @override
  Map<String, Object?> toJson() => {'status': status, 'message': message};
}

/// 결제창을 띄우는 실행 환경입니다. Flutter 앱은 [createPayments]가 WebView 기본 환경을 사용합니다.
///
/// 멤버는 Flutter 기준입니다(Node SDK의 브라우저 환경과 다릅니다). 테스트는 가짜 환경을 넣습니다.
///
/// @docImport 'flutter.dart';
abstract interface class PaymentsEnv {
  /// 결제창을 띄웁니다. [html]이 있으면 그 문서를 [baseUrl] 출처로 열고, 없으면 [url]을 엽니다.
  ///
  /// 결제창이 [returnUrl]로 이동하면 그 주소를, 결제창을 열지 못했다는 알림을 받으면 그 실패를, 구매자가 닫으면 둘 다 null을 돌려줍니다.
  Future<({String? returnUrl, LaunchFailure? failure})> present({
    String? html,
    String? url,
    required String baseUrl,
    required String returnUrl,
  });

  /// [Payments.result]에서 주소를 생략했을 때 읽을 주소입니다. 없으면 null이고 결과는 `INVALID`입니다.
  String? currentUrl();

  /// 현재 시각입니다. 결과가 확정될 때까지 조회하는 기한 계산에 사용합니다.
  DateTime now();

  /// [duration]만큼 기다립니다. 조회 사이 간격에 사용합니다.
  Future<void> wait(Duration duration);
}

/// [createPayments]에 넘기는 옵션입니다.
class PaymentsOptions {
  /// 옵션을 만듭니다.
  const PaymentsOptions({required this.client, this.returnUrl, this.env});

  /// 스토어프론트 API 클라이언트입니다.
  final StorefrontClient client;

  /// 결제를 마치면 돌아올 주소입니다(상점 결제 도메인 안). [Payments.start]·[Payments.retry]에서 바꿀 수 있습니다.
  ///
  /// 앱에서는 이 주소의 페이지를 실제로 열지 않습니다. 결제창이 이 주소로 이동하는 순간 SDK가 가로채 결과를 만듭니다.
  final String? returnUrl;

  /// 결제창 실행 환경입니다. 생략하면 Flutter 기본 환경(WebView)입니다.
  final PaymentsEnv? env;
}

/// [Payments.start]의 옵션입니다.
class StartOptions {
  /// 옵션을 만듭니다.
  const StartOptions({
    this.option,
    this.shippingAddress,
    this.guest,
    this.cashReceipt,
    this.coupons,
    this.pointAmount,
    this.returnUrl,
  });

  /// 결제 옵션입니다. 결제가 필요한지는 서버가 판단합니다.
  ///
  /// 금액 미리보기(`checkout.pricing`)의 `paymentRequired`가 false(적립금이 전액을 덮음)면 생략합니다.
  /// 결제가 필요한데 생략하면 서버가 400 `VALIDATION_FAILED`로 거절합니다.
  final PaymentOption? option;

  /// 배송지입니다. 주문서의 `requiresShipping`이 false면 생략합니다.
  final ShippingAddressInput? shippingAddress;

  /// 비회원 주문 정보입니다.
  final GuestInfo? guest;

  /// 현금영수증 신청입니다. 계좌이체·가상계좌 옵션에서만 보냅니다.
  final CashReceiptRequest? cashReceipt;

  /// 적용할 쿠폰입니다. 결제 시작이 예약하고 할인한 금액으로 결제합니다.
  final List<CouponApplication>? coupons;

  /// 사용할 적립금(회원만)입니다. 결제 금액 전체를 덮으면 결제창 없이 바로 완료됩니다.
  final int? pointAmount;

  /// 이 결제의 복귀 주소입니다. 생략하면 [PaymentsOptions.returnUrl]입니다.
  final String? returnUrl;
}

/// [Payments.retry]의 옵션입니다.
class RetryOptions {
  /// 옵션을 만듭니다.
  const RetryOptions({required this.option, this.returnUrl, this.cashReceipt});

  /// 다시 시도할 결제 옵션입니다.
  final PaymentOption option;

  /// 복귀 주소입니다. 생략하면 결제 시작 때의 복귀 주소입니다.
  final String? returnUrl;

  /// 현금영수증 신청을 바꿉니다. 생략하면 결제 시작 때의 신청을 그대로 둡니다.
  final CashReceiptRequest? cashReceipt;
}

/// 결제입니다. [createPayments]로 만듭니다.
abstract interface class Payments {
  /// 결제를 시작하고 결과까지 돌려줍니다.
  ///
  /// 결제창을 띄우고, 복귀를 가로채 승인(또는 실패 보고)하고, 결과가 확인 중이면 확정될 때까지 조회합니다.
  /// 결제가 필요 없으면 결제창 없이 바로 `COMPLETED`입니다. 결제 시작 API가 실패하면 [ApiError]를 던집니다.
  Future<PaymentResult> start(String checkoutId, StartOptions options);

  /// 같은 결제를 다른 결제 옵션으로 다시 시도합니다. 동작은 [start]와 같습니다.
  Future<PaymentResult> retry(String paymentId, RetryOptions options);

  /// 이미 받은 결제 시작 값으로 결제창만 엽니다. 결제 시작(`checkout.startPayment`)을 앱이 직접 부른 경우에 사용합니다.
  Future<PaymentResult> open(PaymentStart start);

  /// 복귀 주소로 결과를 만듭니다. 결제 중 앱이 종료돼 복귀 주소를 나중에 받은 경우(딥링크 등)에 사용합니다.
  ///
  /// 승인(또는 실패 보고)을 한 번 하고 결제 상태 조회로 결과를 만듭니다. 같은 복귀를 두 번 불러도 승인은 한 번입니다.
  Future<PaymentResult> result([String? url]);

  /// 결제 상태를 조회합니다.
  Future<PaymentStatus> getStatus(String paymentId);
}

const _desktopMinWidth = 820;
final _mobileUa = RegExp(r'Android|iPhone|iPad|iPod|IEMobile|Opera Mini|Mobile', caseSensitive: false);

/// PC 결제창을 쓸지 모바일 결제창을 쓸지 정합니다. PC면 `popup`, 모바일이면 `redirect`입니다.
///
/// [mode]가 `popup`·`redirect`면 그 값을 그대로 돌려줍니다. 앱의 결제창은 늘 모바일 결제창입니다.
String resolvePaymentMode(String? mode, PaymentDevice device) {
  if (mode == 'popup' || mode == 'redirect') return mode!;
  if (_mobileUa.hasMatch(device.userAgent)) return 'redirect';
  if (device.coarsePointer && device.viewportWidth > 0 && device.viewportWidth < _desktopMinWidth) return 'redirect';
  return 'popup';
}

/// 결제 상태를 결과로 옮깁니다. 모르는 `result` 값은 확인 중으로 다룹니다.
///
/// [popupClosed]가 true면 아직 대기 중인 결제를 「구매자가 결제창을 닫음」으로 봅니다.
PaymentResult paymentResultOf(PaymentStatus status, {bool popupClosed = false}) {
  final paymentId = status.paymentId;
  final result = status.result;
  final lastFailure = status.lastFailure;
  final failure = lastFailure == null ? const <String, Object?>{} : lastFailure.toJson();
  String? field(String key) => failure[key] as String?;
  if (result == 'COMPLETED') {
    final orderId = status.orderId;
    return orderId != null && orderId.isNotEmpty
        ? PaymentResultCompleted(paymentId: paymentId, orderId: orderId)
        : PaymentResultProcessing(paymentId: paymentId);
  }
  if (result == 'CANCELED') {
    return PaymentResultCanceled(
      paymentId: paymentId,
      code: field('code') ?? 'USER_CANCELED',
      message: field('message') ?? '결제를 취소했습니다',
    );
  }
  if (result == 'FAILED' || result == 'EXPIRED') {
    return PaymentResultFailed(
      paymentId: paymentId,
      code: field('code') ?? result,
      message: field('message') ?? (result == 'EXPIRED' ? '결제 요청이 만료됐습니다' : '결제에 실패했습니다'),
      optionUnavailable: failure['optionUnavailable'] == true ? true : null,
    );
  }
  if (result == 'PENDING') {
    return popupClosed
        ? PaymentResultCanceled(paymentId: paymentId, code: 'POPUP_CLOSED', message: '결제창을 닫았습니다')
        : PaymentResultProcessing(paymentId: paymentId);
  }
  return PaymentResultProcessing(paymentId: paymentId);
}

/// 서버가 PG에서 매입을 확인했다는 응답이면 그 거래 id·금액 — 그 값으로 승인한다
({String pgToken, num? amount})? _capturedOf(Object error) {
  if (error is! ApiError || error.code != 'ATTEMPT_CAPTURED') return null;
  final details = error.details ?? const {};
  final id = details['pgTransactionId'];
  if (id is! String) return null;
  final amount = details['amount'];
  return (pgToken: id, amount: amount is num ? amount : null);
}

/// 결제창 없이 결과를 정하는 동안 확인 중이면 다시 조회하는 간격과 기한(결제 만료 시각이 없을 때)
const _pollInterval = Duration(seconds: 1);
const _pollFallback = Duration(seconds: 30);

/// 실행 환경을 직접 넣어 결제를 만듭니다. 테스트·비표준 런타임용입니다.
Payments createPaymentsWith(PaymentsOptions options, PaymentsEnv env) => _Payments(options, env);

class _Payments implements Payments {
  _Payments(this.options, this.env);

  final PaymentsOptions options;
  final PaymentsEnv env;

  /// 같은 복귀의 승인·보고는 한 번만 보낸다
  final _settled = <String, Future<void>>{};

  StorefrontClient get client => options.client;

  Future<PaymentResult> _statusResult(String paymentId, {bool popupClosed = false}) async {
    try {
      return paymentResultOf(await client.payments.getStatus(paymentId), popupClosed: popupClosed);
    } catch (_) {
      return PaymentResultProcessing(paymentId: paymentId);
    }
  }

  // Node처럼 요청 본문 검증 실패(ZodError)도 이 try 안에서 일어나 삼켜지고, 결과는 상태 조회가 정한다
  Future<void> _confirm(String paymentId, Map<String, Object?> body, {bool retryCaptured = true}) async {
    try {
      await client.payments.confirm(paymentId, ConfirmPaymentRequest.fromJson(body));
    } catch (error) {
      final captured = retryCaptured ? _capturedOf(error) : null;
      if (captured != null) {
        await _confirm(
          paymentId,
          {...body, 'pgToken': captured.pgToken, if (captured.amount != null) 'amount': captured.amount},
          retryCaptured: false,
        );
      }
    }
  }

  Future<void> _reportFailure(String paymentId, String attemptId, String callbackToken, LaunchFailure failure) async {
    try {
      await client.payments.reportFailure(
        paymentId,
        ReportPaymentFailureRequest.fromJson({
          'attemptId': attemptId,
          'callbackToken': callbackToken,
          'category': failure.category,
          'code': failure.code.length > 100 ? failure.code.substring(0, 100) : failure.code,
          'message': failure.message.length > 500 ? failure.message.substring(0, 500) : failure.message,
        }),
      );
    } catch (error) {
      final captured = _capturedOf(error);
      if (captured != null) {
        await _confirm(
          paymentId,
          {
            'attemptId': attemptId,
            'callbackToken': callbackToken,
            'pgToken': captured.pgToken,
            if (captured.amount != null) 'amount': captured.amount,
          },
          retryCaptured: false,
        );
      }
    }
  }

  Future<void> _settle(ReturnDecision decision) {
    final key = switch (decision) {
      ReturnConfirm(:final paymentId, :final attemptId) => '$paymentId:$attemptId:confirm',
      ReturnFailure(:final paymentId, :final attemptId) => '$paymentId:$attemptId:failure',
      ReturnStatus() => throw StateError('status는 보고하지 않는다'),
    };
    return _settled[key] ??= switch (decision) {
      ReturnConfirm() => _confirm(decision.paymentId, {
          'attemptId': decision.attemptId,
          'callbackToken': decision.callbackToken,
          'pgToken': decision.pgToken,
          if (decision.amount != null) 'amount': decision.amount,
        }),
      ReturnFailure() => _reportFailure(decision.paymentId, decision.attemptId, decision.callbackToken,
          (category: decision.category, code: decision.code, message: decision.message)),
      ReturnStatus() => Future<void>.value(),
    };
  }

  /// 결제창을 열지 않는 결제 시작 응답의 결과
  Future<PaymentResult> _settleWithoutWindow(PaymentStart start) async {
    final orderId = start.orderId;
    if (start.status == 'completed' && orderId != null && orderId.isNotEmpty) {
      return PaymentResultCompleted(paymentId: start.paymentId, orderId: orderId);
    }
    return _statusResult(start.paymentId);
  }

  /// 확인 중이면 결제 만료 시각까지 조회해 확정된 결과를 돌려준다
  Future<PaymentResult> _untilSettled(PaymentResult result, String? expiresAt) async {
    if (result is! PaymentResultProcessing) return result;
    final deadline = DateTime.tryParse(expiresAt ?? '') ?? env.now().add(_pollFallback);
    PaymentResult current = result;
    while (current is PaymentResultProcessing && env.now().isBefore(deadline)) {
      await env.wait(_pollInterval);
      current = await _statusResult(current.paymentId);
    }
    return current;
  }

  Future<PaymentResult> _open(PaymentStart start, String? returnUrl) async {
    if (start.status != 'pending') return _settleWithoutWindow(start);
    final target = returnUrl ?? options.returnUrl;
    if (target == null) throw StateError('returnUrl이 필요합니다 — createPayments 또는 start에 넘겨 주십시오');
    final launch = start.launch;
    final String? html;
    final String? url;
    if (launch != null && launchable(launch)) {
      html = launchHtml(launch);
      url = null;
    } else if (start.payUrl != null && start.payUrl!.isNotEmpty) {
      html = null;
      url = start.payUrl;
    } else {
      return _settleWithoutWindow(start);
    }
    final origin = Uri.parse(target);
    final outcome = await env.present(
      html: html,
      url: url,
      baseUrl: Uri(scheme: origin.scheme, host: origin.host, port: origin.hasPort ? origin.port : null).toString(),
      returnUrl: target,
    );
    if (outcome.returnUrl != null) return _untilSettled(await result(outcome.returnUrl), start.expiresAt);
    if (html != null) {
      // SDK가 띄운 결제창을 열지 못했거나 구매자가 닫았다 — 시도를 닫고 결과를 조회한다.
      // payUrl 결제창은 결제 서비스가 시도를 다루므로 보고하지 않는다(Node와 같다)
      await _reportFailure(
        start.paymentId,
        launch!.attemptId,
        launch.callbackToken,
        outcome.failure ?? (category: 'USER_CANCELED', code: 'USER_CANCEL', message: '결제를 취소했습니다'),
      );
    }
    return _untilSettled(
      await _statusResult(start.paymentId, popupClosed: outcome.failure == null),
      start.expiresAt,
    );
  }

  @override
  Future<PaymentResult> open(PaymentStart start) => _open(start, null);

  @override
  Future<PaymentResult> start(String checkoutId, StartOptions startOptions) async {
    final returnUrl = startOptions.returnUrl ?? options.returnUrl;
    if (returnUrl == null) throw StateError('returnUrl이 필요합니다 — createPayments 또는 start에 넘겨 주십시오');
    final start = await client.checkout.startPayment(
      checkoutId,
      StartPaymentRequest(
        option: startOptions.option,
        shippingAddress: startOptions.shippingAddress,
        guest: startOptions.guest,
        cashReceipt: startOptions.cashReceipt,
        coupons: startOptions.coupons,
        pointAmount: (startOptions.pointAmount ?? 0) == 0 ? null : startOptions.pointAmount,
        returnUrl: returnUrl,
      ),
    );
    return _open(start, returnUrl);
  }

  @override
  Future<PaymentResult> retry(String paymentId, RetryOptions retryOptions) async {
    final returnUrl = retryOptions.returnUrl ?? options.returnUrl;
    final start = await client.payments.retry(
      paymentId,
      RetryPaymentRequest(option: retryOptions.option, returnUrl: returnUrl, cashReceipt: retryOptions.cashReceipt),
    );
    return _open(start, returnUrl);
  }

  @override
  Future<PaymentStatus> getStatus(String paymentId) => client.payments.getStatus(paymentId);

  @override
  Future<PaymentResult> result([String? url]) async {
    final current = url ?? env.currentUrl();
    final uri = current == null ? null : Uri.tryParse(current);
    if (uri == null || !uri.hasScheme) return const PaymentResultInvalid(message: '결제 정보가 없는 주소입니다');
    final decision = readPaymentReturn(firstParams(uri));
    final paymentId = decision.paymentId;
    if (paymentId == null) return const PaymentResultInvalid(message: '결제 정보가 없는 주소입니다');
    if (decision is! ReturnStatus) await _settle(decision);
    return _statusResult(paymentId);
  }
}
