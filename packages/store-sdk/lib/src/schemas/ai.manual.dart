// 손으로 쓴 부분 — ai.ts의 경로 판정 함수.
part of 'ai.dart';

/// 에이전트 작업 메모 폴더([AI_AGENT_NOTES_DIR]) 안의 경로인지 판정합니다.
bool isAiAgentNotesPath(String path) => path == AI_AGENT_NOTES_DIR || path.startsWith('$AI_AGENT_NOTES_DIR/');

/// 디자인 아트보드 폴더([AI_DESIGN_DIR]) 안의 경로인지 판정합니다.
bool isAiDesignPath(String path) => path == AI_DESIGN_DIR || path.startsWith('$AI_DESIGN_DIR/');
