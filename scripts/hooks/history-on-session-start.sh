#!/bin/bash
# SessionStart hook: 작업 히스토리 인덱스를 컨텍스트에 자동 주입한다.
# Claude 가 세션 시작 시 관련 과거 작업을 인지하도록 한다.

HISTORY_DIR="$HOME/IdeaProjects/claudedocs/history"
INDEX_FILE="$HISTORY_DIR/INDEX.md"

mkdir -p "$HISTORY_DIR"

if [ ! -s "$INDEX_FILE" ]; then
  # INDEX 가 비어있거나 없으면 가이드만 주입
  CTX="## Claude 작업 히스토리 (auto-injected)

저장 위치: \`~/IdeaProjects/claudedocs/history/\`
현재 인덱스 비어있음 — 의미 있는 작업이 끝나면 자동으로 저장이 유도됩니다."
else
  # 상단 50줄까지만 주입 (컨텍스트 비용 절약)
  INDEX_CONTENT=$(head -50 "$INDEX_FILE" 2>/dev/null)

  CTX="## Claude 작업 히스토리 인덱스 (auto-injected)

저장 위치: \`~/IdeaProjects/claudedocs/history/\`

기존 히스토리 인덱스:

${INDEX_CONTENT}

규칙:
- 사용자 요청이 위 항목과 관련되면 해당 .md 파일을 **Read 로 먼저 확인**한 뒤 작업 시작
- 후속 작업이면 새 파일 만들지 말고 기존 파일을 업데이트할 것
- 의미 있는 작업이 끝나고 세션이 종료될 때 자동 저장 안내가 1회 표시됨"
fi

jq -nc --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
