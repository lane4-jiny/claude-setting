---
name: git-committer
description: Git 커밋 메시지 작성 및 커밋 수행. 사용자가 "커밋", "commit", "git commit", "커밋 메시지", "변경사항 커밋" 등을 요청할 때 사용. 변경점 분석 후 한국어 커밋 메시지 생성 및 최소 작업 단위로 분할 커밋 수행.
---

# Git Committer

Git 변경점을 분석하여 커밋 메시지를 생성하고 커밋을 수행한다.

## 핵심 제약사항

- `git commit`은 사용자가 명시적으로 "커밋" 요청시에만 수행
- `git add`시 현재 커밋 작업에 맞는 파일만 선택
- 브랜치 이름 변경 금지
- rebase, reset, push, merge 등 파괴적 명령 실행 금지
- 작업 단위가 큰 경우 반드시 분할 커밋 수행 (최소 작업 단위)
- 클로드코드가 작성했다는 등의 메시지를 작성하지 않는다.

## 커밋 메시지 구조

```
type: subject

body
```

## Type 종류

| Type | 설명 |
|------|------|
| feat | 신규 기능 |
| fix | 버그 수정 |
| docs | 문서 작업 |
| style | 코드 스타일 정리 |
| refactor | 리팩토링 |
| test | 테스트 코드 (신규 기능은 feat) |
| chore | 의존성 등 기타 작업 |
| design | CSS 등 디자인 요소 변경 |

## Subject 규칙

- 한국어, 50자 이내
- 간결한 개조식 표현
- 마침표/특수문자 금지
- 핵심 변경사항 요약

## Body 규칙

- 80자 기준 줄바꿈
- 무엇을/왜 변경했는지 설명
- 파일별 변경사항 bullet 사용 가능

## 커밋 메시지 예시

### 예시 1: 버그 수정

```
fix: 배차 조회시 누락된 요금 데이터 관련 테이블 연관관계 수정

find.allocation.repository.ts
- Fare 테이블과 연관관계 추가
- 조회 컬럼 추가(amount)

find.allocation.response.ts
- amount 필드 추가 반환
```

### 예시 2: 신규 기능

```
feat: ETA 기능 구현

Overview
- 관제 페이지 도착 예상 시간 적용을 위한 신규 기능 구현
- 차량 예약일시, 실시간 이동 좌표, 전체 거리 등을 통해 ETA 계산 및 소켓 데이터 응답 반환

eta.service.ts
- 엘라스틱서치에 실시간으로 쌓이는 좌표데이터 기반 ETA 계산로직 추가

monitoring.service.ts
- 계산된 ETA 데이터를 실시간 소켓 데이터에 추가하여 반환
```

## 워크플로우

1. `git status`로 변경사항 확인
2. `git diff`로 변경 내용 분석
3. 관련 파일들을 논리적 단위로 그룹화
4. 각 그룹별로:
    - `git add <files>` (해당 작업 관련 파일만)
    - 커밋 메시지 작성
    - `git commit -m "..."` 수행
5. 분할 커밋 필요시 반복