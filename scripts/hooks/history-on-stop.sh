#!/bin/bash
# Stop hook: 세션 종료 직전에 작업 히스토리 저장을 한 번 유도한다.
# - sentinel 파일로 세션당 1회만 block 한다 (재진입 시 통과).
# - 도구 호출이 3회 미만이면 사소한 세션으로 보고 스킵.
# - decision: block 으로 Claude 를 다시 활성화해서 히스토리 저장을 시키고,
#   저장 후 자연스럽게 다시 Stop 이 호출되면 sentinel 덕분에 통과.

INPUT=$(cat 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

HISTORY_DIR="$HOME/IdeaProjects/claudedocs/history"
SENTINEL_DIR="/tmp/claude-history-sentinels"
mkdir -p "$SENTINEL_DIR" "$HISTORY_DIR"

# session_id 없으면 그냥 통과
[ -z "$SESSION_ID" ] && exit 0

SENTINEL_FILE="$SENTINEL_DIR/$SESSION_ID"

# 이미 이번 세션에서 유도했으면 통과
if [ -f "$SENTINEL_FILE" ]; then
  exit 0
fi

# 트랜스크립트 찾기
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 도구 호출 횟수로 의미 있는 작업인지 판단
TOOL_COUNT=$(grep -c '"type":"tool_use"' "$TRANSCRIPT" 2>/dev/null || echo 0)
if [ "$TOOL_COUNT" -lt 3 ]; then
  touch "$SENTINEL_FILE"
  exit 0
fi

# 컨텍스트 수집
BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null)
PROJECT=$(basename "$CWD")
TODAY=$(date +%Y-%m-%d)

# 1회성 유도 표시
touch "$SENTINEL_FILE"

REASON=$(cat <<EOF
[자동 히스토리 저장 안내 — 세션당 1회]

작업 내용을 ~/IdeaProjects/claudedocs/history/ 에 저장한 뒤 세션을 종료하세요.

컨텍스트:
- 날짜: $TODAY
- 프로젝트: $PROJECT
- 브랜치: ${BRANCH:-unknown}
- 세션 도구 호출 수: $TOOL_COUNT

절차:
1. ~/IdeaProjects/claudedocs/history/INDEX.md 를 Read 로 확인
2. 이번 작업이 기존 항목의 후속이면 해당 .md 파일을 Edit 로 업데이트
3. 신규 주제면 ~/IdeaProjects/claudedocs/history/${TODAY}_<slug>.md 새로 작성
   - slug: 영문 kebab-case, 핵심 키워드 2~4 단어 (예: creatrip-status-resync)
   - 파일 맨 위에 아래 YAML frontmatter 를 반드시 포함한다 (Obsidian Dataview 집계용):
     ---
     type: history
     project: $PROJECT
     domain: <핵심 도메인 키워드 1개, 예: ssgdfs / payment / allocation / klook / driver-schedule>
     date: $TODAY
     committed: <커밋했으면 true, 미커밋이면 false>
     followup: <후속작업이 남았으면 true, 없으면 false>
     tags:
       - history
     ---
   - frontmatter 값은 추측하지 말고 실제 작업 기준으로 채운다. project 는 실제 작업한 lane4 프로젝트명으로 보정 가능.
4. 신규 파일을 만들었으면 INDEX.md 맨 위에 한 줄 추가:
   - [한국어 제목](파일명.md) — 프로젝트명 / 한 줄 요약 / $TODAY
5. 저장 후 짧게 "히스토리 저장 완료" 안내 1줄만 출력하고 종료

저장 내용 (간결하게, 추측 없이 실제 작업 기반):
- 목적 / 배경 (왜 이 작업을 했는가)
- 변경된 주요 파일 (path:line 형식)
- 핵심 결정 사항과 이유
- 후속 작업 (있으면)
- 관련 커밋 해시 (있으면, git log 로 확인)

스킵 조건:
- 단순 질문 응답, 탐색만 한 세션, 변경 없는 코드 리뷰 등이면 "히스토리 저장 스킵 (사소한 세션)" 한 줄만 출력하고 종료

이 안내는 세션당 1회만 표시됩니다.
EOF
)

jq -nc --arg reason "$REASON" '{decision: "block", reason: $reason}'
exit 0
