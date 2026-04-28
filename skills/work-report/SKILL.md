---
name: work-report
description: git log 기반 작업 리포트 생성. 사용자가 "작업 리포트", "work-report", "오늘 뭐했지", "이번주 작업", "작업 보고", "일일 보고" 등을 요청할 때 사용. 기간별 커밋 분석으로 작업 요약 + 전주 대비 비교 리포트 출력.
---

# Work Report

git log 기반으로 기간별 작업 내용을 간결하게 요약하고, 전주와 비교하는 리포트를 생성한다.

## 핵심 제약사항

- 코드를 수정하지 않는다. 리포트 생성만 수행한다.
- git log에 기록된 사실만 기반으로 작성한다. 추측하지 않는다.
- **커밋 하나하나를 나열하지 않는다.** 같은 주제의 커밋은 하나의 작업 항목으로 통합한다.
- 커밋 메시지가 불명확한 경우 diff를 참고하여 보완한다.
- 출력 형식은 `references/report-template.md`를 따른다.

## 설정

| 항목 | 값 |
|------|-----|
| git author | `lane4-jiny` (email: `jiny@lane4.ai`) |
| 프로젝트 디렉토리 | `/Users/ojieun/IdeaProjects/` 내 `lane4-*` 레포지토리 |

## 리포트 유형

| 유형 | 기간 | 용도 |
|------|------|------|
| 일일 | 오늘 (당일) | 일일 작업 보고, 스탠드업 |
| 주간 | 이번 주 (월~금) | 주간 보고, 회고 |
| 커스텀 | 사용자 지정 기간 | 특정 기간 작업 정리 |

## 워크플로우

### 1단계: 기간 확인
- 사용자에게 기간 확인 (오늘 / 이번 주 / 커스텀 기간)

### 2단계: 이번 주 + 전주 커밋 조회

```bash
# 이번 주 커밋
for dir in /Users/ojieun/IdeaProjects/lane4-*/; do
  git -C "$dir" log --author="lane4-jiny" --since="{이번주 월요일}" --until="{이번주 금요일+1}" --oneline 2>/dev/null
done

# 전주 커밋 (비교용)
for dir in /Users/ojieun/IdeaProjects/lane4-*/; do
  git -C "$dir" log --author="lane4-jiny" --since="{전주 월요일}" --until="{전주 금요일+1}" --oneline 2>/dev/null
done
```

### 3단계: 작업 요약 (간결하게)

- 같은 주제의 여러 커밋을 **하나의 작업 항목으로 통합**한다.
  - 예: "feat: FARE_HISTORY 저장 로직" + "fix: FARE_HISTORY 쿼리 수정" + "chore: FARE_HISTORY 엔티티 정리" → `FARE_HISTORY 저장 기능 구현 및 수정`
- 작업 유형별로 분류 (신규 기능 / 버그 수정 / 리팩토링 / 기타)
- **커밋 해시, 커밋 상세 테이블은 포함하지 않는다.**

### 4단계: 전주 대비 비교

이번 주와 전주를 비교하여 다음 항목을 분석한다:
- **작업량 비교**: 총 커밋 수, 작업 항목 수 변화
- **작업 유형 변화**: 신규 기능 vs 버그 수정 vs 리팩토링 비율 변화
- **프로젝트 분포 변화**: 어떤 프로젝트에 집중했는지 변화
- **특이사항**: 전주에 없던 새로운 프로젝트, 전주 대비 급증/급감한 영역

### 5단계: 리포트 출력

- `references/report-template.md` 형식에 맞춰 출력한다.

## 참조 문서

| 문서 | 용도 | 언제 읽는가 |
|------|------|-----------|
| `references/report-template.md` | 리포트 출력 템플릿 | 리포트 작성 시 출력 형식을 결정할 때 |
