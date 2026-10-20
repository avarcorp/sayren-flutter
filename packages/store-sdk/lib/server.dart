/// sayren 관리 API SDK의 서버 엔트리포인트입니다. Node `@sayren/store-sdk/server`에 대응합니다.
///
/// 시크릿을 다루는 도우미(웹훅 서명, 구매자 위임)만 둡니다. 앱(클라이언트) 코드에서 import하지 마십시오.
///
/// ```dart
/// import 'package:sayren_store_sdk/server.dart';
///
/// final result = await verifyWebhookSignature(VerifyWebhookSignatureOptions(
///   payload: rawBody,
///   header: signatureHeader,
///   secret: webhookSecret,
/// ));
/// ```
library;

export 'src/member-delegation.dart';
export 'src/webhook-headers.dart'
    show
        WEBHOOK_DEFAULT_TOLERANCE_SEC,
        WEBHOOK_DELIVERY_ID_HEADER,
        WEBHOOK_EVENT_ID_HEADER,
        WEBHOOK_EVENT_TYPE_HEADER,
        WEBHOOK_HEADERS,
        WEBHOOK_SIGNATURE_HEADER,
        WEBHOOK_USER_AGENT;
export 'src/webhook-signature.dart';
