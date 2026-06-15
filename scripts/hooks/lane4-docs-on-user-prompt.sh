#!/bin/bash
# UserPromptSubmit hook: 사용자 프롬프트에서 도메인 키워드 추출 → lane4-docs/_index.md 매칭 도메인 문서 주입.
# - history-on-user-prompt.sh 와 동일한 토큰 매칭 방식 (점수 = 프롬프트 토큰 중 라인 일치 개수)
# - _index.md 의 각 라인(.md 링크 포함)에 대해 점수 계산, 임계치 이상이면 해당 문서 경로 주입
# - 비용 절감: 매칭 없으면 빈 출력으로 즉시 종료
# - 도메인 질문은 lane4-docs 우선 검색 (CLAUDE.md) 규칙을 자동화한 것

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# 프롬프트 너무 짧으면 스킵 (4글자 미만)
[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 4 ] && exit 0

DOCS_DIR="$HOME/IdeaProjects/lane4-docs"
INDEX_FILE="$DOCS_DIR/_index.md"

# 인덱스 없으면 스킵
[ ! -s "$INDEX_FILE" ] && exit 0

# 슬래시 커맨드는 스킵 (Claude 가 직접 처리)
case "$PROMPT" in
  /*) exit 0 ;;
esac

# 프롬프트에서 토큰 추출 (한글/영문/숫자, 2자 이상)
# 흔한 stopword + _index.md 경로/메타 토큰(노이즈 유발) 제외
TOKENS=$(echo "$PROMPT" \
  | tr '[:upper:]' '[:lower:]' \
  | grep -oE '[가-힣]{2,}|[a-z][a-z0-9_-]+' \
  | sort -u \
  | grep -vwE 'the|and|for|are|but|not|you|all|can|has|have|will|with|this|that|을|를|이|가|은|는|에|와|과|의|도|만|좀|해|줘|해줘|하고|하는|같이|어떻게|진행|작업|해야|이거|저거|그거|어떤|하나|모두|전부|domains|business|readme|overview|faq|policies|policy|guide|admin|md|stable|draft|api|기능|소개|정책|문서|도메인' \
  || true)

[ -z "$TOKENS" ] && exit 0

# _index.md 각 라인을 후보로 점수 계산 (.md 링크 포함 라인만)
MATCHES=""
while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  case "$LINE" in
    \#*) continue ;;
  esac
  # .md 링크 없는 라인(헤더/구분/설명문)은 스킵
  echo "$LINE" | grep -q '\.md)' || continue

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
    # 라인에서 첫 .md 문서 경로 추출 (없으면 라인 원문)
    DOCPATH=$(echo "$LINE" | grep -oE '\(([^)]+\.md)\)' | head -1 | tr -d '()')
    if [ -n "$DOCPATH" ]; then
      MATCHES="${MATCHES}- (점수 $SCORE) \`lane4-docs/${DOCPATH}\` — ${LINE}
"
    else
      MATCHES="${MATCHES}- (점수 $SCORE) ${LINE}
"
    fi
  fi
done < "$INDEX_FILE"

# 매칭 없으면 조용히 종료
[ -z "$MATCHES" ] && exit 0

CTX="## 관련 lane4-docs 도메인 문서 발견 (auto-injected)

사용자 프롬프트와 매칭되는 도메인 문서가 있습니다. 도메인/비즈니스 규칙 관련 작업이면 진행 전에 해당 문서를 Read 로 먼저 확인하세요.

매칭된 문서 (점수 = 프롬프트 토큰 중 라인 일치 개수):

${MATCHES}
문서 루트: \`~/IdeaProjects/lane4-docs/\` (전체 인덱스: \`_index.md\`)"

jq -nc --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
