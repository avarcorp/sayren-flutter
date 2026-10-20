// 손으로 쓴 파일 — createPayments와 Flutter 기본 결제창 환경(WebView).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../flutter/navigator.dart';
import 'index.dart';
import 'launch.dart';

/// 결제를 만듭니다. 결제창은 [PaymentsOptions.env]가 없으면 Flutter 기본 환경(WebView)으로 띄웁니다.
///
/// 결제는 [Payments.start] 한 번의 `await`로 끝납니다. 결제창 표시, 복귀 처리, 승인, 결과 확정은 SDK가 합니다.
///
/// ```dart
/// final payments = createPayments(PaymentsOptions(client: client, returnUrl: 'https://shop.example.com/payments/return'));
/// final result = await payments.start(checkoutId, StartOptions(option: option, shippingAddress: address));
/// switch (result) {
///   case PaymentResultCompleted(:final orderId): // 주문 완료 화면
///   case PaymentResultFailed(:final message): // 실패 안내, 다른 결제수단으로 payments.retry
///   case PaymentResultCanceled(): // 구매자가 결제창을 닫음
///   case PaymentResultProcessing(:final paymentId): // 확인 중, payments.getStatus로 다시 조회
///   case PaymentResultInvalid(): // start에서는 나오지 않습니다
/// }
/// ```
///
/// 기본 환경은 앱의 루트 Navigator에 전체 화면 WebView를 띄웁니다. 루트 Navigator가 없는 라우팅이면 [PaymentsOptions.env]를 넘기십시오.
/// 카드사·은행·간편결제 앱 호출(`intent://`, 앱 스킴)은 OS로 넘기고, 앱에서 돌아오면 WebView 결제를 이어 갑니다.
Payments createPayments(PaymentsOptions options) => createPaymentsWith(options, options.env ?? _WebViewPaymentsEnv());

/// WebView가 그대로 여는 스킴 — 그 밖은 앱 호출이다
const _webSchemes = {'http', 'https', 'about', 'data', 'javascript', 'blob'};

class _WebViewPaymentsEnv implements PaymentsEnv {
  @override
  Future<({String? returnUrl, LaunchFailure? failure})> present({
    String? html,
    String? url,
    required String baseUrl,
    required String returnUrl,
  }) async {
    final navigator = rootNavigator();
    if (navigator == null) {
      throw StateError('루트 Navigator를 찾지 못했습니다 — PaymentsOptions.env로 결제창 환경을 넘겨 주십시오');
    }
    final completer = Completer<({String? returnUrl, LaunchFailure? failure})>();
    var routeOpen = true;
    void finish(({String? returnUrl, LaunchFailure? failure}) value) {
      if (completer.isCompleted) return;
      completer.complete(value);
      if (routeOpen) unawaited(navigator.maybePop());
    }

    final target = Uri.parse(returnUrl);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SayrenPayments', onMessageReceived: (message) {
        final j = jsonDecode(message.message) as Map<String, Object?>;
        finish((
          returnUrl: null,
          failure: (
            category: j['category'] as String? ?? 'PREPARE_FAILURE',
            code: j['code'] as String? ?? 'LAUNCH_FAILED',
            message: j['message'] as String? ?? '결제창을 열지 못했습니다',
          ),
        ));
      })
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri != null && _isReturn(uri, target)) {
          finish((returnUrl: request.url, failure: null));
          return NavigationDecision.prevent;
        }
        if (uri != null && !_webSchemes.contains(uri.scheme)) {
          unawaited(_openApp(request.url));
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }));
    if (html != null) {
      await controller.loadHtmlString(html, baseUrl: baseUrl);
    } else {
      await controller.loadRequest(Uri.parse(url!));
    }
    unawaited(navigator
        .push(PageRouteBuilder<void>(
      pageBuilder: (context, _, __) => _PaymentWindow(controller: controller),
      transitionDuration: Duration.zero,
    ))
        .then((_) {
      routeOpen = false;
      finish((returnUrl: null, failure: null)); // 구매자가 닫았다
    }));
    return completer.future;
  }

  /// 복귀 주소로 가는 이동인가 — 스킴·호스트·포트·경로가 같으면 쿼리는 PG가 덧붙인 결과다
  static bool _isReturn(Uri uri, Uri target) =>
      uri.scheme == target.scheme && uri.host == target.host && uri.port == target.port && uri.path == target.path;

  /// 카드사·은행·간편결제 앱을 연다. Android `intent://`는 스킴 주소로 바꾸고, 앱이 없으면 스토어로 보낸다
  static Future<void> _openApp(String url) async {
    var target = url;
    String? package;
    if (url.startsWith('intent:')) {
      final hash = url.indexOf('#Intent;');
      final params = hash < 0 ? '' : url.substring(hash + 8);
      String? param(String key) => RegExp('(?:^|;)${RegExp.escape(key)}=([^;]*)').firstMatch(params)?.group(1);
      final scheme = param('scheme');
      package = param('package');
      final body = url.substring('intent:'.length, hash < 0 ? url.length : hash);
      if (scheme != null) target = '$scheme:$body';
      final fallback = param('S.browser_fallback_url');
      if (fallback != null && !await _launch(target)) {
        await _launch(Uri.decodeComponent(fallback));
        return;
      }
    }
    if (await _launch(target)) return;
    if (package != null) await _launch('market://details?id=$package');
  }

  static Future<bool> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  String? currentUrl() => null;

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}

/// 전체 화면 결제창 — 닫기 버튼과 WebView
class _PaymentWindow extends StatelessWidget {
  const _PaymentWindow({required this.controller});

  final WebViewController controller;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('닫기', style: TextStyle(color: Color(0xFF111111), fontSize: 16)),
                  ),
                ),
              ),
              Expanded(child: WebViewWidget(controller: controller)),
            ],
          ),
        ),
      );
}
