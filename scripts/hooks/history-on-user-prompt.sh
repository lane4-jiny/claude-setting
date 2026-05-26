#!/bin/bash
# UserPromptSubmit hook: 사용자 프롬프트에서 키워드 추출 → claudedocs/history 매칭 파일 주입.
# - INDEX.md 의 각 라인(파일명 포함)에 대해 프롬프트와 토큰 매칭 점수 계산
# - 매칭 점수 임계치 이상이면 해당 파일 경로 + 한 줄 요약을 additionalContext 로 주입
# - 비용 절감: 매칭 없으면 빈 출력으로 즉시 종료

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# 프롬프트 너무 짧으면 스킵 (4글자 미만)
[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 4 ] && exit 0

HISTORY_DIR="$HOME/IdeaProjects/claudedocs/history"
INDEX_FILE="$HISTORY_DIR/INDEX.md"

# INDEX 가 비어있으면 스킵
[ ! -s "$INDEX_FILE" ] && exit 0

# 슬래시 커맨드는 스킵 (Claude 가 직접 처리)
case "$PROMPT" in
  /*) exit 0 ;;
esac

# 프롬프트에서 토큰 추출 (한글/영문/숫자, 2자 이상)
# 흔한 stopword 는 제외
TOKENS=$(echo "$PROMPT" \
  | tr '[:upper:]' '[:lower:]' \
  | grep -oE '[가-힣]{2,}|[a-z][a-z0-9_-]+' \
  | sort -u \
  | grep -vwE 'the|and|for|are|but|not|you|all|can|has|have|will|with|this|that|을|를|이|가|은|는|에|와|과|의|도|만|좀|해|줘|해줘|하고|하는|같이|어떻게|진행|작업|해야|이거|저거|그거|어떤|하나|모두|전부' \
  || true)

[ -z "$TOKENS" ] && exit 0

# INDEX.md 각 라인을 후보로 점수 계산
MATCHES=""
while IFS= read -r LINE; do
  # 빈 라인 / 헤더 / 비-항목 스킵
  [ -z "$LINE" ] && continue
  case "$LINE" in
    \#*|"") continue ;;
  esac

  # 라인을 소문자로 변환해서 토큰 매칭
  LINE_LC=$(echo "$LINE" | tr '[:upper:]' '[:lower:]')

  SCORE=0
  while IFS= read -r TOK; do
    [ -z "$TOK" ] && continue
    if echo "$LINE_LC" | grep -qF "$TOK"; then
      SCORE=$((SCORE + 1))
    fi
  done <<EOF
$TOKENS
EOF

  if [ "$SCORE" -ge 2 ]; then
    MATCHES="${MATCHES}- (점수 $SCORE) $LINE
"
  fi
done < "$INDEX_FILE"

# 매칭 없으면 조용히 종료
[ -z "$MATCHES" ] && exit 0

CTX="## 관련 작업 히스토리 발견 (auto-injected)

사용자 프롬프트와 매칭되는 과거 작업이 있습니다. 진행 전에 관련 파일을 Read 로 먼저 확인하세요.

매칭된 항목 (점수 = 프롬프트 토큰 중 라인 일치 개수):

${MATCHES}
저장 위치 prefix: \`~/IdeaProjects/claudedocs/history/\`"

jq -nc --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
