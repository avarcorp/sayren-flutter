// 손으로 쓴 부분 — webhook-event.ts의 타입 하나로 좁힌 이벤트와 parseWebhookEvent.
part of 'webhook-event.dart';

/// 이벤트 타입 하나로 좁힌 이벤트입니다(Node `WebhookEventOf<"ORDER.PAID">`).
///
/// Dart에는 문자열 리터럴 타입이 없어 [WebhookEvent] 그대로입니다. 타입별 `data`는 [WebhookEvent]의 하위 클래스로 읽으십시오.
typedef WebhookEventOf<T extends String> = WebhookEvent;

/// [parseWebhookEvent]의 결과입니다. [known]이 true면 [ParsedWebhookEventKnown], false면 [ParsedWebhookEventUnknown]입니다.
///
/// ```dart
/// switch (parseWebhookEvent(body)) {
///   case ParsedWebhookEventKnown(:final event): handle(event);
///   case ParsedWebhookEventUnknown(:final event): log(event.type);
/// }
/// ```
sealed class ParsedWebhookEvent {
  const ParsedWebhookEvent();

  /// 이 SDK 버전이 아는 이벤트 타입인지입니다.
  bool get known;

  /// JSON으로 바꿉니다(`{ known, event }`).
  Map<String, Object?> toJson();
}

/// 이 SDK 버전이 아는 이벤트입니다(`known: true`).
final class ParsedWebhookEventKnown extends ParsedWebhookEvent {
  /// 결과를 만듭니다.
  const ParsedWebhookEventKnown(this.event);

  @override
  bool get known => true;

  /// 타입별 스키마로 검증한 이벤트입니다.
  final WebhookEvent event;

  @override
  Map<String, Object?> toJson() => {'known': true, 'event': event.toJson()};
}

/// 이 SDK 버전이 모르는 이벤트입니다(`known: false`). 봉투만 검증하고 `data`는 그대로 둡니다.
final class ParsedWebhookEventUnknown extends ParsedWebhookEvent {
  /// 결과를 만듭니다.
  const ParsedWebhookEventUnknown(this.event);

  @override
  bool get known => false;

  /// 봉투만 검증한 이벤트입니다.
  final UnknownWebhookEvent event;

  @override
  Map<String, Object?> toJson() => {'known': false, 'event': event.toJson()};
}

/// 웹훅 본문을 `type`으로 먼저 판별해 읽습니다.
///
/// 알려진 타입은 그 타입의 스키마([webhookEventSchema])로 엄격하게 읽고 틀리면 [ZodError]를 던집니다. 모르는 타입은
/// 봉투만 검증해([unknownWebhookEventSchema]) [ParsedWebhookEventUnknown]으로 돌려줍니다. 새 이벤트에 옛 SDK가 깨지지 않습니다.
ParsedWebhookEvent parseWebhookEvent(Object? body) {
  final type = body is Map ? body['type'] : null;
  if (type is String && KNOWN_WEBHOOK_EVENT_TYPES.contains(type)) {
    return ParsedWebhookEventKnown(webhookEventSchema.parse(body));
  }
  return ParsedWebhookEventUnknown(unknownWebhookEventSchema.parse(body));
}
