#!/bin/bash
# PreToolUse hook (matcher: Write|Edit): 편집 대상 파일의 형제 파일을 grep 해 주변 관습을 컨텍스트로 주입한다.
# - lane4 프로젝트의 TypeScript 소스 파일만 대상 (성능 보호)
# - 같은 디렉토리의 동일 suffix 파일 3개를 참조 후보로 제시
# - PreToolUse 는 매 편집마다 실행되므로 작업을 가볍게 유지

INPUT=$(cat 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Edit/Write 가 아니면 그냥 통과
case "$TOOL_NAME" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -z "$FILE_PATH" ] && exit 0

# lane4-* 프로젝트가 아니면 스킵
case "$FILE_PATH" in
  */lane4-*) ;;
  *) exit 0 ;;
esac

# TypeScript/JavaScript 소스만 대상
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# 빌드/벤더 디렉토리 제외
case "$FILE_PATH" in
  */node_modules/*|*/dist/*|*/.next/*|*/build/*|*/coverage/*) exit 0 ;;
esac

DIR=$(dirname "$FILE_PATH")
BASE=$(basename "$FILE_PATH")

# suffix 추출 (예: foo.service.ts → service.ts, bar.controller.ts → controller.ts)
# 단순 .ts/.tsx 만 있으면 그냥 .ts/.tsx 로 본다
SUFFIX=""
case "$BASE" in
  *.module.ts) SUFFIX="module.ts" ;;
  *.controller.ts) SUFFIX="controller.ts" ;;
  *.service.ts) SUFFIX="service.ts" ;;
  *.entity.ts) SUFFIX="entity.ts" ;;
  *.repository.ts) SUFFIX="repository.ts" ;;
  *.dto.ts) SUFFIX="dto.ts" ;;
  *.guard.ts) SUFFIX="guard.ts" ;;
  *.pipe.ts) SUFFIX="pipe.ts" ;;
  *.interceptor.ts) SUFFIX="interceptor.ts" ;;
  *.filter.ts) SUFFIX="filter.ts" ;;
  *.decorator.ts) SUFFIX="decorator.ts" ;;
  *.spec.ts) SUFFIX="spec.ts" ;;
  *.test.ts) SUFFIX="test.ts" ;;
  *.tsx) SUFFIX="tsx" ;;
  *.ts) SUFFIX="ts" ;;
  *) exit 0 ;;
esac

# 형제 파일 검색 (자기 자신 제외, 최대 3개)
SIBLINGS=$(find "$DIR" -maxdepth 1 -type f -name "*.${SUFFIX}" 2>/dev/null \
  | grep -vF "$FILE_PATH" \
  | head -3)

# 형제가 없으면 부모 도메인 디렉토리에서도 검색
if [ -z "$SIBLINGS" ]; then
  PARENT=$(dirname "$DIR")
  # lane4-*-api/src 보다 하위에서만 탐색 (너무 광범위 방지)
  case "$PARENT" in
    */lane4-*/src*|*/lane4-*/apps/*)
      SIBLINGS=$(find "$PARENT" -type f -name "*.${SUFFIX}" 2>/dev/null \
        | grep -vF "$FILE_PATH" \
        | head -3)
      ;;
  esac
fi

# 그래도 없으면 조용히 종료 (컨텍스트 없이 통과)
[ -z "$SIBLINGS" ] && exit 0

# 액션에 따라 메시지 다르게
ACTION="편집"
case "$TOOL_NAME" in
  Write)
    if [ ! -f "$FILE_PATH" ]; then
      ACTION="신규 작성"
    else
      ACTION="덮어쓰기"
    fi
    ;;
esac

# 형제 파일 리스트 포맷
SIBLING_LIST=""
while IFS= read -r S; do
  [ -z "$S" ] && continue
  SIBLING_LIST="${SIBLING_LIST}- \`$S\`
"
done <<EOF
$SIBLINGS
EOF

REASON="## 주변 파일 관습 참조 (auto-injected, $ACTION 직전)

대상: \`$FILE_PATH\`

같은 \`$SUFFIX\` 유형의 형제 파일 (참조 권장):

${SIBLING_LIST}
편집 진행 전에 형제 파일의 import 순서 / 명명 / 데코레이터 순서 / 응답 envelope / 트랜잭션 패턴이 일관되는지 1~2개 빠르게 Read 후 동일 톤 유지 권장.

(이 안내는 PreToolUse 훅으로 매 편집마다 표시됩니다. 무시하고 진행해도 무방.)"

# PermissionRequest 가 아니라 PreToolUse 이므로 hookSpecificOutput.permissionDecision 은 사용 불가
# additionalContext 만 주입하여 Claude 가 인지하도록 함
jq -nc --arg ctx "$REASON" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
exit 0
