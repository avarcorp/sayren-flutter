// 손으로 쓴 부분 — payment.ts의 superRefine(결제위젯 키 거부).
part of 'payment.dart';

/// 토스페이먼츠 키 superRefine — 결제위젯 키를 칸마다 따로 짚는다(둘 다 위젯 키면 이슈 2개)
void _tossWidgetKeyCheck(TossPaymentsCredentialsInput value, ZodCheckContext ctx) {
  if (TOSS_WIDGET_CLIENT_KEY_PATTERN.hasMatch(value.clientKey)) {
    ctx.addIssue(TOSS_WIDGET_KEY_MESSAGE, path: ['clientKey']);
  }
  final secretKey = value.secretKey;
  if (secretKey != null && TOSS_WIDGET_SECRET_KEY_PATTERN.hasMatch(secretKey)) {
    ctx.addIssue(TOSS_WIDGET_KEY_MESSAGE, path: ['secretKey']);
  }
}
