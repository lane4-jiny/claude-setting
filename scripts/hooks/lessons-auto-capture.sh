#!/bin/bash
# UserPromptSubmit hook: 사용자 정정 패턴 감지 시 lessons.md 에 스텁을 자동 추가.
# - 감지된 프롬프트를 그대로 stub 으로 적어두고, Claude 에게 정제 요청을 context 로 전달.
# - 거짓 양성 방지: 의문문/요청문이 아닌 정정/지시문 패턴만 매칭.

INPUT=$(cat 2>/dev/null)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 4 ] && exit 0
[ -z "$CWD" ] && CWD="$PWD"

# 슬래시 커맨드 스킵
case "$PROMPT" in
  /*) exit 0 ;;
esac

# 정정/지시 패턴 매칭 (한국어 + 영어)
# 매칭되면 has_correction = 1
HAS_CORRECTION=0

# 한국어 정정 패턴
if echo "$PROMPT" | grep -qE '아니|그게 아니|그러지 말|그러지말|하지마|하지 마|쓰지마|쓰지 마|그렇게 하지|왜 그렇게|왜 ~?(이렇게|저렇게|그렇게)|다음부터|앞으로는|항상|절대|금지|말랬|말했잖|했잖아|다시는|이렇게 하지'; then
  HAS_CORRECTION=1
fi

# 영어 정정 패턴
if echo "$PROMPT" | grep -qiE "don't|do not|never|stop doing|stop using|why did you|why are you|that's not|that is not|wrong approach"; then
  HAS_CORRECTION=1
fi

[ "$HAS_CORRECTION" -eq 0 ] && exit 0

# 단순 질문/감탄 ("왜?" 만 있는 경우) 스킵
if [ ${#PROMPT} -lt 8 ]; then
  exit 0
fi

# lessons.md 위치 결정: cwd/tasks/lessons.md 우선, 없으면 워크스페이스
LESSONS_FILE=""
if [ -d "$CWD/tasks" ]; then
  LESSONS_FILE="$CWD/tasks/lessons.md"
elif [ -d "$HOME/IdeaProjects/tasks" ]; then
  LESSONS_FILE="$HOME/IdeaProjects/tasks/lessons.md"
else
  # tasks 디렉토리 자동 생성 (워크스페이스 레벨)
  mkdir -p "$HOME/IdeaProjects/tasks" 2>/dev/null
  LESSONS_FILE="$HOME/IdeaProjects/tasks/lessons.md"
fi

# lessons.md 가 없으면 헤더 작성
if [ ! -f "$LESSONS_FILE" ]; then
  cat > "$LESSONS_FILE" <<'EOF'
# Lessons (사용자 정정 기반 학습 기록)

사용자가 작업 방식을 정정/지시할 때마다 자동 캡처 후 정제된다.
각 항목은 **규칙 / 이유 / 적용 시점** 3단 구조로 정리한다.

---

EOF
fi

# 프롬프트 일부를 stub 으로 추가 (200자 제한)
TS=$(date "+%Y-%m-%d %H:%M")
PROJECT=$(basename "$CWD")
EXCERPT=$(echo "$PROMPT" | head -c 200 | tr '\n' ' ' | sed 's/  */ /g')

# stub 마커로 미정제 항목 표시 (Claude 가 나중에 정제)
cat >> "$LESSONS_FILE" <<EOF

## [stub] $TS — $PROJECT
원문: "$EXCERPT"
정제 필요: 아직 규칙/이유/적용시점으로 정리되지 않음.

EOF

CTX="## 정정 패턴 감지 (auto-captured)

사용자 프롬프트에 정정/지시 패턴이 포함되어 \`$LESSONS_FILE\` 에 stub 이 자동 추가되었습니다.

응답 마지막에 다음을 수행하세요:
1. \`Read\` 로 \`$LESSONS_FILE\` 의 방금 추가된 \`[stub]\` 섹션 확인
2. 이번 정정의 핵심을 **규칙 / 이유 / 적용 시점** 3단 구조로 정제하여 stub 을 교체
3. 메모리에도 저장할 가치가 있으면 별도로 feedback 메모리 작성
4. 사용자에게 별도 보고 불필요 (정제 결과만 lessons.md 에 남기면 됨)

stub 위치: $LESSONS_FILE"

jq -nc --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
