// 손으로 쓴 부분 — ai.ts의 경로 판정 함수.
part of 'ai.dart';

/// 에이전트 작업 메모 폴더([AI_AGENT_NOTES_DIR]) 안의 경로인지 판정합니다.
bool isAiAgentNotesPath(String path) => path == AI_AGENT_NOTES_DIR || path.startsWith('$AI_AGENT_NOTES_DIR/');

/// 디자인 아트보드 폴더([AI_DESIGN_DIR]) 안의 경로인지 판정합니다.
bool isAiDesignPath(String path) => path == AI_DESIGN_DIR || path.startsWith('$AI_DESIGN_DIR/');

/// 작업 공간 문서 탭의 문서 파일(사이트맵·디자인 가이드라인)인지 판정합니다.
///
/// 앱 코드가 아니라서 코드 탭·미리보기 점검·코드 변경 판정에서 뺍니다.
bool isAiWorkspaceDocPath(String path) => path == AI_SITEMAP_PATH || path == AI_DESIGN_GUIDE_PATH;

/// 셀러 메시지가 선택지에서 고른 답인지(조각에 `choice`가 있는지) 판정합니다.
///
/// 할 일 목록은 셀러 요청 하나(사이클)의 일입니다. 고른 답(선택지·만들기 확인·계획 승인·발행 확인·「이어서 진행」)은 같은 사이클을 잇고
/// 새로 쓴 글은 새 사이클입니다.
bool isAiChoiceAnswer(List<({String type, String? choice})> parts) =>
    parts.any((part) => part.type == 'text' && truthy(part.choice));
