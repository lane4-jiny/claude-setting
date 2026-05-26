---
description: 작업 히스토리(~/IdeaProjects/claudedocs/history)를 검색/조회. 인자 없으면 INDEX 표시, 키워드 인자 있으면 본문 grep.
argument-hint: "[검색 키워드]"
---

당신은 `/history` 슬래시 커맨드를 처리합니다.

저장 위치: `~/IdeaProjects/claudedocs/history/`

## 입력 인자

`$ARGUMENTS` — 사용자가 슬래시 커맨드 뒤에 입력한 텍스트. 빈 값일 수 있음.

## 동작

### 인자 없음 → 인덱스 표시
1. `Bash` 로 `cat ~/IdeaProjects/claudedocs/history/INDEX.md` 또는 `Read` 로 INDEX.md 표시
2. 인덱스가 비어있으면 "히스토리 없음" 안내
3. 추가로 디렉토리에 있는 모든 .md 파일 목록을 `ls -t ~/IdeaProjects/claudedocs/history/*.md 2>/dev/null` 로 최신순 표시 (INDEX 누락 항목 확인용)

### 인자 있음 → 본문 grep
1. `Bash` 로 `grep -l -i "<인자>" ~/IdeaProjects/claudedocs/history/*.md` 실행하여 매칭 파일 목록 획득
2. INDEX.md 에서도 동일 키워드 grep
3. 매칭된 각 파일에 대해 다음 표시:
   - 파일 경로
   - INDEX 의 한 줄 요약 (있으면)
   - 본문에서 키워드 주변 1~3줄 컨텍스트 (`grep -B1 -A2 -i`)
4. 매칭 0건이면 "<키워드>와 매칭되는 히스토리 없음" 안내 + 가장 최근 5개 파일 목록 제시

## 출력 규칙

- 한국어
- 결과만 출력 — 절차 설명/사고 과정은 출력하지 않음
- 매칭 파일이 5개 초과면 상위 5개만 본문 미리보기, 나머지는 경로만
- 각 파일 항목 사이 빈 줄 1개로 구분

## 예시

`/history` → INDEX.md 표시

`/history 크리에이트립` → 본문에 "크리에이트립" 포함된 .md 파일을 키워드 컨텍스트와 함께 표시
