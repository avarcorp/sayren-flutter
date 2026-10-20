/// @docImport '../client.dart';
library;

/// 방문자 ID 헤더 이름입니다. 스토어프론트 API 요청에 실어 서버 거래 이벤트와 방문자를 잇습니다.
///
/// [StorefrontClientOptions.visitorId]를 넘기면 SDK가 이 헤더로 보냅니다.
const ANALYTICS_VISITOR_HEADER = 'x-sayren-visitor';

/// 방문 세션 ID 헤더 이름입니다. [StorefrontClientOptions.sessionId]를 넘기면 SDK가 이 헤더로 보냅니다.
const ANALYTICS_SESSION_HEADER = 'x-sayren-session';
