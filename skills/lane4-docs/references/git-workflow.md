# Git Worktree 워크플로우 상세 가이드

## 개요

여러 도메인 문서를 병렬로 작업할 때 Git Worktree를 활용하여 충돌을 최소화하는 워크플로우.

## 초기 설정

### .gitignore 추가

프로젝트 루트의 `.gitignore`에 다음 내용 추가:

```gitignore
# Git Worktrees (문서 병렬 작업용)
worktrees/
```

### worktrees 폴더 생성

```bash
mkdir -p worktrees
```

## 디렉토리 구조

```
{project-root}/
├── worktrees/               # .gitignore에 추가됨 (워크트리 작업 공간)
│   ├── coupon/              # feature/docs-coupon 브랜치
│   ├── order/               # feature/docs-order 브랜치
│   └── payment/             # feature/docs-payment 브랜치
├── domains/
├── business/
├── projects/
├── .meta/
│   ├── index/
│   │   ├── coupon.yml
│   │   └── order.yml
│   └── glossary/
│       ├── coupon.yml
│       └── order.yml
├── _index.md                # 자동 생성됨
├── _glossary.md             # 자동 생성됨
└── .gitignore               # worktrees/ 포함
```

## 메타 파일 시스템

### 왜 메타 파일을 사용하는가?

**문제**: 여러 워크트리에서 동시에 `_index.md` 수정 시 충돌 발생

```
워크트리 A: _index.md에 쿠폰 행 추가
워크트리 B: _index.md에 주문 행 추가
→ Rebase 시 충돌!
```

**해결**: 도메인별 메타 파일 분리 → 마지막에 통합

```
워크트리 A: .meta/index/coupon.yml 생성 (충돌 없음)
워크트리 B: .meta/index/order.yml 생성 (충돌 없음)
→ Merge 후 메타 파일 기반으로 _index.md 재생성
```

### 메타 파일 상세 스키마

**.meta/index/{domain}.yml**

```yaml
# 필수 필드
domain: string           # 도메인 ID (영문, 소문자)
description: string      # 한글 설명
status: draft | review | stable
last_updated: YYYY-MM-DD

# 문서 경로
paths:
  developer: string      # 개발자용 README 경로
  business:
    overview: string     # 비개발자용 개요
    faq: string          # FAQ
    policies: string     # 정책
    admin: string        # 운영 가이드

# 관련 프로젝트
projects:
  - backend
  - web
  - mobile
```

**.meta/glossary/{domain}.yml**

```yaml
domain: string
terms:
  - term: string         # 영문 용어
    term_ko: string      # 한글 용어
    definition: string   # 정의
    related_doc: string  # 관련 문서 경로
    code_refs:           # 코드 참조 (선택)
      - string
    status_values:       # 상태값 (선택)
      - string
```

## 인덱스 재생성 로직

### _index.md 생성 알고리즘

```
1. .meta/index/*.yml 파일 목록 조회
2. 각 yml 파일 파싱
3. domain 기준 알파벳 정렬
4. 비개발자용 테이블 생성 (business 경로 사용)
5. 개발자용 테이블 생성 (developer 경로 사용)
6. 프로젝트별 테이블 생성
7. _index.md 파일 출력
```

### _glossary.md 생성 알고리즘

```
1. .meta/glossary/*.yml 파일 목록 조회
2. 모든 terms 수집
3. term 기준 알파벳 정렬
4. 알파벳별 섹션 생성 (A, B, C...)
5. 각 용어 마크다운 형식으로 출력
6. _glossary.md 파일 출력
```

## 전체 워크플로우

### Phase 1: 워크트리 준비

```bash
# 메인 저장소에서 실행
git checkout develop
git pull origin develop

# 워크트리 생성
git worktree add worktrees/{domain} -b feature/docs-{domain} develop

# 워크트리로 이동
cd worktrees/{domain}
```

### Phase 2: 문서 작업

```bash
# Claude에게 요청
# "{domain} 도메인 문서 생성해줘"

# 생성되는 파일들:
# - domains/{domain}/*.md
# - business/{domain}/*.md
# - projects/*/{domain}.md
# - .meta/index/{domain}.yml
# - .meta/glossary/{domain}.yml
```

### Phase 3: 커밋

```bash
git add domains/ business/ projects/ .meta/
git commit -m "docs({domain}): 문서 생성"
```

### Phase 4: Rebase & Merge

```bash
# develop 최신화
git fetch origin develop

# rebase
git rebase origin/develop

# 충돌 해결 (있는 경우)
git add .
git rebase --continue

# 인덱스 재생성 (Claude에게 요청)
# "인덱스 파일 재생성해줘"

# 인덱스 커밋
git add _index.md _glossary.md
git commit -m "docs: 인덱스 재생성"

# develop에 merge
git checkout develop
git merge feature/docs-{domain}
git push origin develop
```

### Phase 5: 정리

```bash
# 메인 저장소로 이동
cd ../..

# 워크트리 제거
git worktree remove worktrees/{domain}

# 브랜치 삭제
git branch -d feature/docs-{domain}
```

## 충돌 시나리오별 대응

### 시나리오 1: 메타 파일 충돌 (드묾)

**원인**: 같은 도메인을 여러 워크트리에서 동시 작업

**해결**:
```bash
# 충돌 파일 확인
git status

# 둘 중 최신 버전 선택 또는 수동 병합
git checkout --theirs .meta/index/coupon.yml  # 원격 버전
# 또는
git checkout --ours .meta/index/coupon.yml    # 로컬 버전

git add .
git rebase --continue
```

### 시나리오 2: 도메인 문서 충돌 (매우 드묾)

**원인**: 같은 도메인 문서를 여러 워크트리에서 수정

**해결**: 수동 병합 필요 (드문 케이스이므로 직접 확인)

### 시나리오 3: _index.md 충돌 (발생 안 함)

메타 파일 기반 재생성이므로 _index.md 자체는 git에서 충돌 대상이 아님.
단, 재생성 시점에 모든 메타 파일이 있어야 함.

## 병렬 작업 예시

```bash
# 터미널 1: 쿠폰 도메인
git worktree add worktrees/coupon -b feature/docs-coupon develop
cd worktrees/coupon
# Claude: "쿠폰 도메인 문서 생성해줘"

# 터미널 2: 주문 도메인 (동시 작업)
git worktree add worktrees/order -b feature/docs-order develop
cd worktrees/order
# Claude: "주문 도메인 문서 생성해줘"

# 터미널 3: 결제 도메인 (동시 작업)
git worktree add worktrees/payment -b feature/docs-payment develop
cd worktrees/payment
# Claude: "결제 도메인 문서 생성해줘"
```

### 작업 완료 후 순차 Merge

```bash
# 쿠폰 먼저 merge
cd worktrees/coupon
git fetch origin develop
git rebase origin/develop
# Claude: "인덱스 재생성해줘"
git add _index.md _glossary.md
git commit -m "docs: 인덱스 재생성"
git checkout develop
git merge feature/docs-coupon
git push origin develop

# 주문 merge (쿠폰 merge 후)
cd ../order
git fetch origin develop
git rebase origin/develop  # 쿠폰의 메타 파일이 포함됨
# Claude: "인덱스 재생성해줘"
git add _index.md _glossary.md
git commit -m "docs: 인덱스 재생성"
git checkout develop
git merge feature/docs-order
git push origin develop

# 결제 merge (쿠폰, 주문 merge 후)
cd ../payment
git fetch origin develop
git rebase origin/develop  # 쿠폰, 주문의 메타 파일이 포함됨
# Claude: "인덱스 재생성해줘"
...
```

## 워크트리 관리 명령어

```bash
# 워크트리 목록 확인
git worktree list

# 워크트리 제거
git worktree remove worktrees/{domain}

# 워크트리 정리 (삭제된 디렉토리 정리)
git worktree prune

# 브랜치 삭제
git branch -d feature/docs-{domain}
```

## 체크리스트

### 작업 시작 전

- [ ] develop 브랜치 최신화 (`git pull origin develop`)
- [ ] 워크트리 생성 (`git worktree add worktrees/{domain} -b feature/docs-{domain} develop`)
- [ ] 워크트리로 이동 (`cd worktrees/{domain}`)
- [ ] 현재 브랜치 확인 (`git branch`)

### 문서 작업 중

- [ ] _index.md, _glossary.md 직접 수정 안 함
- [ ] .meta/index/{domain}.yml 생성됨
- [ ] .meta/glossary/{domain}.yml 생성됨
- [ ] 도메인 문서 생성됨 (domains/, business/, projects/)

### Merge 전

- [ ] develop fetch 및 rebase
- [ ] 충돌 해결 (있는 경우)
- [ ] 인덱스 재생성 요청
- [ ] 인덱스 커밋

### Merge 후

- [ ] develop push
- [ ] 워크트리 제거 (`git worktree remove worktrees/{domain}`)
- [ ] feature 브랜치 삭제 (`git branch -d feature/docs-{domain}`)
