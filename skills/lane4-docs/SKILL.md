---
name: lane4-docs
description: "코드베이스 분석을 통한 도메인 문서 자동 생성 스킬. 도메인 용어(예: 쿠폰, 주문, 결제)를 입력받아 여러 프로젝트(백엔드/프론트엔드)를 크로스 분석하여 프로젝트별로 분리된 문서를 생성. 비즈니스 규칙, API 명세, 데이터 플로우, 에러 처리, 프로젝트 간 흐름도 등을 마크다운으로 문서화."
---

# Lane4-Docs

코드에서 비즈니스 정책과 기능을 추출하여 **프로젝트별로 분리된** 도메인 중심 문서를 생성하는 스킬.

## 프로젝트 설정

문서 생성 전 분석할 프로젝트들의 경로를 파악할 것. 사용자에게 확인:

```
분석할 프로젝트 경로를 알려주세요:

[백엔드]
- partner-api (법인어드민):
- guest-api (레인포웹/기사앱):
- app-api (레인포앱):
- admin-api (뉴어드민):
- (기타 API):

[프론트엔드]
- biz (법인어드민 웹):
- web (레인포웹):
- app-user (레인포앱):
- admin (뉴어드민 웹):
- (기타 FE):

[공통/인프라]
- notification-server:
- scheduler:
- (기타):

[문서 출력 경로]:
```

### 프로젝트 네이밍 규칙

- `lane4-` 접두사 제거
- suffix 유지 (api, server, web 등)

| Lane4 프로젝트명 | 문서 폴더명 |
|-----------------|------------|
| lane4-guest-api | `guest-api/` |
| lane4-partner-api | `partner-api/` |
| lane4-admin-api | `admin-api/` |
| lane4-app-api | `app-api/` |
| lane4-driver-api | `driver-api/` |
| lane4-biz | `biz/` |
| lane4-web | `web/` |
| lane4-admin | `admin/` |
| lane4-app-user | `app-user/` |
| lane4-app-driver | `app-driver/` |
| lane4-notification-api | `notification-api/` |
| lane4-notification-server | `notification-server/` |
| lane4-scheduler | `scheduler/` |
| lane4-monitoring-api | `monitoring-api/` |
| lane4-allocation-api | `allocation-api/` |

## 문서 디렉토리 구조

**중요**: 문서는 프로젝트 **루트**에 직접 생성합니다. `docs/` 폴더를 만들지 마세요.

```
{project-root}/                  # 문서 프로젝트 루트 (예: lane4-docs/)
├── _index.md                    # 전체 인덱스 (자동 생성)
├── _glossary-dev.md             # 개발자용 용어 사전 (코드 참조 포함)
├── _glossary-biz.md             # 비개발자용 용어 사전 (완전 한글)
├── .meta/                       # 메타 파일 (인덱스/용어사전 자동 생성용)
│   ├── index/{domain}.yml
│   └── glossary/{domain}.yml    # 개발자용/비개발자용 통합 구조
│
├── domains/                     # 📘 개발자용 문서
│   └── {domain-name}/
│       ├── README.md            # 도메인 공통 개요
│       ├── data-model.md        # 공통 데이터 모델 (Entity, DB 스키마)
│       │
│       ├── {project-name}/      # 프로젝트별 상세 문서
│       │   ├── api-spec.md      # API 명세 (백엔드만)
│       │   ├── business-rules.md# 비즈니스 규칙
│       │   ├── data-flow.md     # 데이터 흐름
│       │   ├── error-handling.md# 에러 처리
│       │   └── components.md    # 컴포넌트 (프론트엔드만)
│       │
│       └── cross-project.md     # 프로젝트 간 비교/흐름도
│
├── business/                    # 📗 비개발자용 문서 (RAG 최적화)
│   └── {domain-name}/
│       ├── overview.md          # 기능 개요 (쉬운 설명)
│       ├── faq.md               # 자주 묻는 질문
│       ├── policies.md          # 비즈니스 정책/규칙
│       └── admin-guide.md       # 운영자 가이드
│
└── worktrees/                   # Git Worktree 작업 디렉토리 (.gitignore)
```

### 프로젝트별 문서 구조 예시

```
domains/
└── pricing/                     # 요금 조회 도메인
    ├── README.md                # 도메인 공통 개요
    ├── data-model.md            # 공통 Entity (Fare, FareZone 등)
    │
    ├── guest-api/               # lane4-guest-api
    │   ├── api-spec.md
    │   ├── business-rules.md
    │   └── data-flow.md
    │
    ├── partner-api/             # lane4-partner-api
    │   ├── api-spec.md
    │   ├── business-rules.md
    │   └── data-flow.md
    │
    ├── app-api/                 # lane4-app-api
    │   ├── api-spec.md
    │   └── business-rules.md
    │
    ├── web/                     # lane4-web
    │   ├── components.md
    │   └── data-flow.md
    │
    ├── biz/                     # lane4-biz
    │   └── components.md
    │
    ├── app-user/                # lane4-app-user
    │   └── components.md
    │
    └── cross-project.md         # 프로젝트 간 비교/흐름도
```

## 문서 유형별 특성

| 구분 | 개발자용 (domains/) | 비개발자용 (business/) |
|------|---------------------|----------------------|
| **언어** | 기술 용어, 코드 참조 | 일상 언어, 쉬운 설명 |
| **포맷** | API 명세, Entity 구조, Mermaid | FAQ, 시나리오, 표 |
| **대상** | 개발자, QA | 운영팀, CS, 경영진, 전사 |
| **목적** | 구현 참조 | RAG 검색, 업무 이해 |

## 분석 워크플로우

### Step 1: 도메인 코드 탐색 (프로젝트별)

도메인 용어를 받으면 **각 프로젝트별로** 관련 코드 탐색:

**백엔드 (NestJS/TypeORM)**

```bash
# 모듈/컨트롤러/서비스 찾기
find {backend-path}/src -type f -name "*.ts" | xargs grep -l -i "{domain}"

# 주요 탐색 대상
- src/domains/{domain}/**      # 도메인 디렉토리
- src/**/*.module.ts           # 모듈 정의
- src/**/*.controller.ts       # API 엔드포인트
- src/**/*.service.ts          # 비즈니스 로직
```

**웹 (NextJS/React)**

```bash
find {web-path}/src -type f \( -name "*.tsx" -o -name "*.ts" \) | xargs grep -l -i "{domain}"

# 주요 탐색 대상
- pages/**                     # 페이지 라우트 (Next.js Page Router)
- pages/pc/**                  # PC 페이지 라우트
- pages/mobile/**              # 모바일 페이지 라우트
- components/**/{domain}**     # 관련 컴포넌트
- features/**                  # 기능별 모듈
- hooks/**                     # 커스텀 훅
- apis/**                      # API 서비스 (서비스 클래스)
- entities/**                  # TanStack Query (queries, mutations)
- contexts/**                  # React Context (상태 관리)
- shareable/**                 # 재사용 UI 프리미티브
- types/**                     # TypeScript 타입 정의
- constants/**                 # 상수 정의
- utils/**                     # 유틸리티 함수
```

**모바일 (React Native)**

```bash
find {mobile-path}/src -type f \( -name "*.tsx" -o -name "*.ts" \) | xargs grep -l -i "{domain}"

# 주요 탐색 대상
- src/Containers/**            # 화면 (Screen components)
- src/Components/**            # 재사용 UI 컴포넌트
- src/api/**                   # React Query hooks (신규 패턴)
- src/apis/**                  # API 서비스 클래스/타입
- src/entities/**              # React Query factories (FSD 패턴)
- src/Services/**              # API 클라이언트, 유틸리티
- src/Stores/**                # Redux stores
- src/Sagas/**                 # Redux-Saga side effects
- src/hooks/**                 # Custom React hooks
- src/Navigators/**            # Navigation 설정
- src/types/**                 # TypeScript 타입 정의
```

### Step 2: 프로젝트별 코드 분석

분석 패턴 상세는 [references/analysis-patterns.md](references/analysis-patterns.md) 참조.

**각 프로젝트에서 추출할 정보:**

| 카테고리 | 백엔드 | 프론트(웹/모바일) |
|---------|--------|------------------|
| 비즈니스 규칙 | Service 내 조건문, Guard, Interceptor | 조건부 렌더링, validation |
| API 명세 | Controller 데코레이터, DTO | API 호출 함수, request/response 타입 |
| 데이터 모델 | Entity, enum, 관계 | 타입 정의, 인터페이스 |
| 에러 처리 | Exception, ExceptionFilter | try-catch, error boundary, toast |
| 상태 흐름 | 트랜잭션, 이벤트 | 상태 관리, 화면 전환 |

**프로젝트별로 별도 문서 생성:**
- `domains/{domain}/guest-api/api-spec.md`
- `domains/{domain}/partner-api/api-spec.md`
- `domains/{domain}/web/components.md`
- ...

### Step 3: 크로스-프로젝트 분석 (핵심)

**불일치 탐지 체크리스트:**

1. **API 불일치**: 백엔드에 없는 엔드포인트를 프론트에서 호출
2. **에러 처리 불일치**: 백엔드에서 던지지 않는 에러를 프론트에서 처리
3. **비즈니스 로직 분산**: 백엔드에 없는 validation이 프론트에만 존재
4. **상태 불일치**: 백엔드 enum과 프론트 상수 값 차이
5. **숨겨진 기능**: 프론트에서만 구현된 기능 (예: 로컬 캐싱, 오프라인 모드)

**프로젝트 간 흐름도 분석:**

여러 프로젝트에 걸친 기능 흐름을 파악하여 도식화:

```
예시: 예약 생성 흐름
biz (FE) → partner-api (BE) → notification-server → scheduler

분석 방법:
1. FE에서 호출하는 API 엔드포인트 추적
2. BE에서 호출하는 외부 서비스/다른 API 추적
3. 이벤트 발행/구독 관계 파악
4. 전체 흐름을 Mermaid sequenceDiagram으로 표현
```

**분석 결과 → cross-project.md에 기록:**
- 프로젝트 간 API 호출 관계
- 프로젝트별 역할 정리
- 불일치 항목
- 전체 흐름도

### Step 4: 문서 생성

템플릿 상세는 [references/document-templates.md](references/document-templates.md) 참조.

**필수 문서 헤더:**

```markdown
---
domain: {domain-name}
project: {project-name}  # 프로젝트별 문서에만
version: 1.0.0
last_updated: {YYYY-MM-DD}
status: draft | review | stable
source_project: lane4-{project-name}
watch_paths:
  - {변경 감지할 파일 경로들}
---
```

**상호 참조 형식:**

```markdown
<!-- 같은 도메인 내 다른 프로젝트 -->
[partner-api API 명세](../partner-api/api-spec.md)
[guest-api 비즈니스 규칙](../guest-api/business-rules.md)

<!-- 도메인 공통 문서 -->
[데이터 모델](../data-model.md)

<!-- 프로젝트 간 분석 -->
[크로스-프로젝트 분석](../cross-project.md)

<!-- 비개발자 문서 -->
[쉬운 설명 보기](../../business/{domain}/overview.md)
```

### Step 5: 비개발자용 문서 생성 (RAG 최적화)

개발자용 문서 생성 후, 추출된 비즈니스 규칙을 쉬운 말로 변환하여 비개발자용 문서 생성.

**변환 원칙:**
1. 기술 용어 → 일상 언어로 변환
2. 코드 참조 제거 → 결과/효과만 설명
3. FAQ 형식으로 구성 → RAG 검색 정확도 향상
4. 개발자 문서 링크 추가 → "기술적 상세는 [여기] 참조"

**RAG 최적화 문서 헤더:**

```markdown
---
domain: {domain-name}
doc_type: business  # business | developer
version: 1.0.0
last_updated: {YYYY-MM-DD}
keywords:
  - {검색될 키워드1}
  - {검색될 키워드2}
questions:
  - {이 문서가 답할 수 있는 질문1}
  - {이 문서가 답할 수 있는 질문2}
related_domains:
  - {연관 도메인1}
  - {연관 도메인2}
---
```

**비개발자용 문서 생성 순서:**

```
1. overview.md    - 기능 한눈에 보기 (가장 먼저)
2. policies.md    - 비즈니스 규칙을 쉬운 말로
3. faq.md         - 예상 질문-답변 (RAG 핵심)
4. admin-guide.md - 운영자가 알아야 할 것
```

**용어 변환 예시:**

| 기술 용어 | 비개발자용 표현 |
|----------|----------------|
| Entity | 데이터/정보 |
| API 호출 | 기능 요청/처리 |
| Validation | 입력값 검사/확인 |
| Exception | 오류/에러 |
| Transaction | 처리 과정 |
| enum 상태값 | 상태 (예: 발급됨, 사용됨) |
| null/undefined | 없음/미입력 |
| 최소/최대 제약조건 | 제한/조건 |

## 문서 업데이트 워크플로우

코드 변경 후 문서 업데이트 요청 시:

```
1. 변경된 파일 목록 확인
2. 해당 도메인 및 프로젝트의 watch_paths와 대조
3. 영향받는 문서 파일 식별
4. 변경 사항만 업데이트 (전체 재생성 X)
5. version 증가, last_updated 갱신
6. 변경 이력 섹션에 기록 추가
```

**변경 이력 형식:**

```markdown
## 변경 이력

| 버전 | 날짜 | 변경 내용 | 관련 코드 |
|------|------|----------|----------|
| 1.0.1 | 2025-01-28 | 쿠폰 최대 적용 개수 3→5로 변경 | `partner-api/src/coupon/coupon.service.ts:45` |
```

## 인덱스 자동 갱신

새 도메인 문서 생성 시 `_index.md` 자동 업데이트:

```markdown
# 프로젝트 문서 인덱스

> 최종 업데이트: {YYYY-MM-DD}

## 📗 비개발자용 문서 (전사 공용)

빠르게 기능을 이해하고 싶다면 이 문서들을 먼저 확인하세요.

| 도메인 | 개요 | FAQ | 정책 |
|--------|------|-----|------|
| 쿠폰 | [기능 소개](business/coupon/overview.md) | [FAQ](business/coupon/faq.md) | [정책](business/coupon/policies.md) |

## 📘 개발자용 문서

| 도메인 | 설명 | 관련 프로젝트 | 상태 |
|--------|------|--------------|------|
| [요금 조회](domains/pricing/README.md) | 요금 계산/할인 | guest-api, partner-api, web, biz | stable |
```

## 용어 사전 관리

용어 사전은 개발자용(`_glossary-dev.md`)과 비개발자용(`_glossary-biz.md`)으로 분리됩니다.
메타 파일(`.meta/glossary/{domain}.yml`)에서 두 용어 사전이 모두 생성됩니다.

### 개발자용 용어 사전 (`_glossary-dev.md`)

- 영문 용어명 + 한글명: `### GiftCard (기프트카드)`
- 코드 참조 포함: `**백엔드 위치**: GiftCard, GiftCardService`
- 상태값 코드 중심: `ISSUED`, `REGISTERED`, ...
- 도메인 문서 링크: `domains/` 경로
- 알파벳 순 정렬

```markdown
## G

### GiftCard (기프트카드) {#giftcard}
- **정의**: 선불 결제 수단으로 LANE4 서비스에서 할인에 사용되는 상품권
- **관련 도메인**: [기프트카드](domains/giftcard/README.md)
- **백엔드 위치**: `GiftCard`, `GiftCardService`
- **상태값**: `ISSUED` | `REGISTERED` | `USED` | `EXPIRED` | `REVOKED`
```

### 비개발자용 용어 사전 (`_glossary-biz.md`)

- 한글 용어명만: `### 기프트카드`
- 코드 참조 없음
- 상태값은 한글 레이블 + 설명 테이블
- 도메인 문서 링크: `business/` 경로
- 한글 가나다 순 정렬
- 문장체 사용 (~입니다)

```markdown
## ㄱ

### 기프트카드

선불 결제 수단으로 LANE4 서비스에서 할인에 사용되는 상품권입니다.

**상태**:

| 상태 | 설명 |
|------|------|
| 발급됨 | 카드가 생성되었지만 아직 등록되지 않은 상태 |
| 등록됨 | 사용자가 본인 계정에 등록한 상태 |
| 사용완료 | 전액 사용된 상태 |
| 만료됨 | 유효기간이 지난 상태 |
| 취소됨 | 관리자에 의해 취소된 상태 |

→ [자세히 보기](business/giftcard/overview.md)
```

## 마크다운 작성 규칙

### 테이블 작성 규칙 (필수)

마크다운 테이블이 정상적으로 렌더링되려면 **테이블 시작 전에 반드시 빈 줄이 있어야 합니다**.

**올바른 예시:**

```markdown
설명 텍스트입니다.

| 헤더1 | 헤더2 |
|-------|-------|
| 값1   | 값2   |
```

**잘못된 예시 (테이블 깨짐):**

```markdown
설명 텍스트입니다.
| 헤더1 | 헤더2 |
|-------|-------|
| 값1   | 값2   |
```

### 기타 마크다운 규칙

- 코드 블록(```) 앞뒤로 빈 줄 필요
- Mermaid 다이어그램 앞뒤로 빈 줄 필요
- 헤딩(#) 앞에 빈 줄 필요 (문서 시작 제외)

## 문서 작성 원칙 (필수!)

### ⚠️ 추측 금지 원칙

**코드나 문서에서 확인되지 않은 내용은 절대 작성하지 않습니다.**

| 허용 | 금지 |
|------|------|
| 코드에서 직접 확인한 비즈니스 규칙 | 코드에 없는 추측성 규칙 |
| 실제 존재하는 API 엔드포인트 | 있을 것 같은 API 추측 |
| 코드의 조건문/상수에서 추출한 정책값 | 일반적으로 그럴 것 같은 값 |
| 에러 메시지/코드에 명시된 에러 케이스 | 발생할 수 있을 것 같은 에러 |

**확인되지 않은 경우 처리:**
```markdown
<!-- 확인 필요 -->
> ⚠️ **확인 필요**: 이 부분은 코드에서 명확히 확인되지 않았습니다.
> - [ ] {확인이 필요한 내용}
```

**코드 참조 필수:**
- 모든 비즈니스 규칙에는 코드 위치 명시
- 추출 근거가 없는 내용은 작성하지 않음
- 불확실한 경우 "확인 필요" 마크 표시

---

## 출력 품질 체크리스트

문서 생성 완료 후 확인:

**개발자용 문서**
- [ ] 프로젝트별로 문서가 분리되었는가?
- [ ] 모든 상호 참조 링크가 유효한가?
- [ ] 코드 위치 참조가 정확한가?
- [ ] Mermaid 다이어그램이 렌더링되는가?
- [ ] 프로젝트 간 흐름도가 작성되었는가?
- [ ] cross-project.md에 불일치 항목이 기술되었는가?
- [ ] 용어 사전에 새 용어가 추가되었는가?
- [ ] 인덱스가 업데이트되었는가?
- [ ] **테이블 앞에 빈 줄이 있는가?**

**비개발자용 문서 (RAG 최적화)**
- [ ] 기술 용어가 쉬운 말로 변환되었는가?
- [ ] FAQ 질문이 실제 검색 쿼리와 유사한가?
- [ ] keywords에 검색될 키워드가 충분히 포함되었는가?
- [ ] questions에 이 문서가 답할 수 있는 질문이 나열되었는가?
- [ ] 개발자 문서로의 링크가 포함되었는가?
- [ ] 코드/API 참조 없이 결과/효과만 설명하는가?

---

## Git Worktree 워크플로우

이 스킬은 Git Worktree를 활용하여 여러 도메인 문서를 병렬로 작업할 수 있습니다.
상세 가이드는 [references/git-workflow.md](references/git-workflow.md) 참조.

### 워크트리 디렉토리

```
{project-root}/
├── worktrees/           # .gitignore에 추가됨
│   ├── coupon/          # feature/docs-coupon 워크트리
│   ├── order/           # feature/docs-order 워크트리
│   └── payment/         # feature/docs-payment 워크트리
└── ...
```

### 워크트리 생성

```bash
# 1. develop 최신화
git checkout develop
git pull origin develop

# 2. 워크트리 생성
git worktree add worktrees/{domain} -b feature/docs-{domain} develop

# 3. 워크트리로 이동
cd worktrees/{domain}
```

### 충돌 방지 규칙 (필수!)

**⚠️ 절대 직접 수정하지 말 것:**
- `_index.md` - 메타 파일 기반 자동 생성
- `_glossary-dev.md` - 메타 파일 기반 자동 생성
- `_glossary-biz.md` - 메타 파일 기반 자동 생성

**✅ 대신 메타 파일 사용:**
- `.meta/index/{domain}.yml` - 도메인 인덱스 정보
- `.meta/glossary/{domain}.yml` - 도메인 용어 정보 (개발자용/비개발자용 통합)

### 메타 파일 구조

**.meta/index/{domain}.yml**

```yaml
domain: coupon
description: 쿠폰 발급/사용/관리
status: stable
last_updated: 2025-01-28
paths:
  developer: domains/coupon/README.md
  business:
    overview: business/coupon/overview.md
    faq: business/coupon/faq.md
    policies: business/coupon/policies.md
    admin: business/coupon/admin-guide.md
projects:
  - partner-api
  - guest-api
  - biz
  - web
```

**.meta/glossary/{domain}.yml** (확장된 구조)

```yaml
domain: coupon
terms:
  - term: Coupon
    term_ko: 쿠폰

    # 개발자용 정보
    definition: 할인 혜택을 제공하는 디지털 증서
    related_doc: domains/coupon/README.md
    code_refs:
      - Coupon
      - CouponService
    implemented_in:
      - partner-api
      - guest-api
      - biz
      - web

    # 비개발자용 정보 (선택)
    definition_biz: 할인 혜택을 제공하는 디지털 증서입니다.  # 없으면 definition 사용
    related_doc_biz: business/coupon/overview.md

    # 상태값 (확장된 구조)
    status_values:
      - code: ISSUED
        label: 발급됨
        description: 쿠폰이 생성되었지만 아직 사용되지 않은 상태
      - code: USED
        label: 사용됨
        description: 쿠폰이 결제에 적용된 상태
      - code: EXPIRED
        label: 만료됨
        description: 유효기간이 지난 상태
```

**메타 파일 필드 설명:**

| 필드 | 용도 | 필수 |
|------|------|------|
| `term` | 영문 용어 (코드명) | O |
| `term_ko` | 한글 용어 | O |
| `definition` | 개발자용 정의 | O |
| `definition_biz` | 비개발자용 정의 (없으면 definition + "입니다." 사용) | X |
| `related_doc` | 개발자 문서 링크 | O |
| `related_doc_biz` | 비개발자 문서 링크 | X |
| `code_refs` | 코드 참조 (개발자용에만 표시) | X |
| `implemented_in` | 구현 프로젝트 목록 | X |
| `status_values` | 상태값 (code/label/description 구조) | X |

### 문서 작업 순서

```
1. 도메인 문서 생성
   - domains/{domain}/README.md (공통 개요)
   - domains/{domain}/data-model.md (공통 Entity)
   - domains/{domain}/{project}/*.md (프로젝트별 문서)
   - domains/{domain}/cross-project.md (프로젝트 간 분석)
   - business/{domain}/*.md

2. 메타 파일 생성
   - .meta/index/{domain}.yml
   - .meta/glossary/{domain}.yml

3. 커밋 (/git-committer 스킬 사용)
   /git-committer 스킬을 호출하여 커밋
```

**중요**: 커밋 시 반드시 `/git-committer` 스킬을 사용하세요.

### Rebase & Merge (깔끔한 브랜치 그래프)

**목표**: 브랜치가 나갔다가 병합되는 것이 명시적으로 보이는 깔끔한 그래프

```
# 기대하는 결과 (깔끔한 브랜치 그래프)
*   Merge branch 'feature/docs-pricing'
|\
| * docs(pricing): 요금 도메인 문서
|/
*   Merge branch 'feature/docs-giftcard'
|\
| * docs(giftcard): 기프트카드 도메인 문서
|/
* 시작점
```

#### Step 1: 메인 레포에서 develop 최신화

```bash
cd /path/to/lane4-docs
git checkout develop
git pull origin develop
```

#### Step 2: 워크트리에서 rebase 수행 (핵심!)

```bash
cd worktrees/{domain}
git rebase develop

# 충돌 발생 시
git add .
git rebase --continue
```

#### Step 3: 메인 레포에서 No-FF 머지

```bash
cd /path/to/lane4-docs
git checkout develop
git pull origin develop
git merge --no-ff feature/docs-{domain}
```

#### Step 4: 워크트리 정리

```bash
git worktree remove worktrees/{domain}
git branch -d feature/docs-{domain}
git push origin develop
```

### 인덱스 재생성 명령

```
"인덱스 파일 재생성해줘"
```

Claude가 `.meta/index/*.yml`, `.meta/glossary/*.yml` 파일들을 읽어서 다음 파일들을 자동 생성합니다:
- `_index.md` - 전체 문서 인덱스
- `_glossary-dev.md` - 개발자용 용어 사전 (알파벳 순, 코드 참조 포함)
- `_glossary-biz.md` - 비개발자용 용어 사전 (가나다 순, 완전 한글)
