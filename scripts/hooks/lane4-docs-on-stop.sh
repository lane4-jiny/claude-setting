#!/bin/bash
# Stop hook: 세션 종료 직전, 이번 세션이 lane4 코드를 변경했고 문서화 가치가 있으면
# lane4-docs 도메인 문서 갱신을 유도한다. (history-on-stop.sh 와 동일 패턴)
# - 세션당 1회 sentinel 로만 block (재진입 시 통과)
# - 게이트: lane4-* 코드 파일을 Write/Edit 로 수정 + 도구 호출 3회 이상
#   (lane4-docs 리포 자체 편집은 코드 변경이 아니므로 제외 → 자기참조 루프 방지)
# - decision: block 으로 Claude 재활성화 → 문서화 가치 판단(모호하면 사용자 질문) 후 문서 적재.

INPUT=$(cat 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

DOCS_DIR="$HOME/IdeaProjects/lane4-docs"
SENTINEL_DIR="/tmp/claude-lane4docs-sentinels"
mkdir -p "$SENTINEL_DIR"

# lane4-docs 리포/인덱스 없으면 스킵
[ ! -s "$DOCS_DIR/_index.md" ] && exit 0

# session_id 없으면 통과
[ -z "$SESSION_ID" ] && exit 0
SENTINEL_FILE="$SENTINEL_DIR/$SESSION_ID"

# 이미 이번 세션에서 유도했으면 통과
[ -f "$SENTINEL_FILE" ] && exit 0

# 트랜스크립트 찾기
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# 도구 호출 횟수로 의미 있는 작업인지 판단 (사소한 세션 스킵)
TOOL_COUNT=$(grep -c '"type":"tool_use"' "$TRANSCRIPT" 2>/dev/null)
TOOL_COUNT=${TOOL_COUNT:-0}
if [ "$TOOL_COUNT" -lt 3 ]; then
  touch "$SENTINEL_FILE"
  exit 0
fi

# 이번 세션에서 편집한 lane4 코드 파일 추출 (lane4-docs 리포 자체 편집은 제외)
CHANGED=$(grep -oE '"file_path":"[^"]*/IdeaProjects/lane4[^"]*"' "$TRANSCRIPT" 2>/dev/null \
  | sed 's/.*"file_path":"//; s/"$//' \
  | grep -v '/lane4-docs/' \
  | sort -u)

# cwd 가 lane4 코드 프로젝트인지 (문서 리포는 제외)
CWD_LANE4=""
case "$CWD" in
  */IdeaProjects/lane4-docs*) ;;                 # 문서 리포에서 작업한 세션은 게이트 제외
  */IdeaProjects/lane4-docs) ;;
  */IdeaProjects/lane4*) CWD_LANE4="1" ;;
esac

# 게이트: lane4 코드 편집이 하나도 없고 cwd 도 lane4 코드가 아니면 스킵
if [ -z "$CHANGED" ] && [ -z "$CWD_LANE4" ]; then
  touch "$SENTINEL_FILE"
  exit 0
fi

BRANCH=$(cd "$CWD" 2>/dev/null && git branch --show-current 2>/dev/null)
PROJECT=$(basename "$CWD")
TODAY=$(date +%Y-%m-%d)

# 변경 파일 목록 (최대 15개)
CHANGED_LIST=$(echo "$CHANGED" | grep -v '^$' | head -15 | sed 's/^/  - /')
[ -z "$CHANGED_LIST" ] && CHANGED_LIST="  (transcript 에서 lane4 편집 미검출 — cwd 가 lane4 코드 프로젝트)"

# 1회성 유도 표시
touch "$SENTINEL_FILE"

REASON=$(cat <<EOF
[lane4-docs 자동 문서화 안내 — 세션당 1회]

이번 세션에서 lane4 코드가 변경되었습니다. 이 변경이 **lane4-docs 도메인 문서**
(비즈니스 규칙 / 정책 / API 명세 / 데이터 플로우)에 반영할 가치가 있는지 판단한 뒤,
가치가 있으면 문서를 갱신하세요. (히스토리 저장 안내와는 별개 작업입니다.)

컨텍스트:
- 날짜: $TODAY
- 프로젝트: $PROJECT / 브랜치: ${BRANCH:-unknown}
- 변경된 lane4 파일:
$CHANGED_LIST

판단 기준 — 다음 중 하나면 "문서화 가치 있음":
- 문서화된 도메인의 정책/규칙/계산 로직이 바뀜 (예: 요금 계산, 쿠폰 적용 조건, 예약 정책)
- 새 도메인 동작/엔드포인트/플로우가 추가됨
- 문서에 적힌 내용과 실제 코드가 달라지는 변경

"문서화 가치 낮음" (스킵 대상):
- 단순 버그 픽스 / 리팩토링 / 스타일 / 로그 / 테스트 / 빌드·설정 변경
- 도메인 동작에 영향 없는 내부 구현 변경

절차:
1. 변경 요약 확인: 해당 프로젝트에서 git diff (또는 git log -p) 로 실제 변경 파악
2. 위 기준으로 판단:
   - 명백히 가치 낮음 → "lane4-docs 적재 스킵 (문서화 가치 낮음)" 1줄 출력 후 종료
   - 명백히 가치 있음 → 3단계로 진행
   - **모호하면 → AskUserQuestion 으로 사용자에게 질문**
     ("이 변경을 lane4-docs 에 반영할까요? 반영한다면 어느 도메인 문서에?")
3. 반영 대상 도메인을 ~/IdeaProjects/lane4-docs/_index.md 에서 확인
   (business/<도메인>/ 의 overview·faq·policies·admin-guide 구조)
4. lane4-docs 스킬(/lane4-docs) 컨벤션대로 해당 도메인 문서를 Edit 로 갱신
   - 반드시 코드 근거 기반, 추측 금지 (미확인 사항은 "확인 필요"로 표기)
   - 새 도메인이면 스킬 흐름으로 신규 문서 생성 + _index.md 에 행 추가
5. _index.md 상단의 "최종 업데이트" 날짜를 $TODAY 로 갱신
6. 갱신 후 "lane4-docs 갱신 완료: <도메인/파일>" 1줄 안내 후 종료

이 안내는 세션당 1회만 표시됩니다.
EOF
)

jq -nc --arg reason "$REASON" '{decision: "block", reason: $reason}'
exit 0
