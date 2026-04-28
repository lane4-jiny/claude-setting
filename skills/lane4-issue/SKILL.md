---
name: lane4-issue
description: >
  Lane4 운영 이슈 대응 스킬. 운영 이슈가 보고되면 프론트엔드~백엔드 전체 프로젝트 코드를 분석하여 
  원인 파악, 데이터 흐름 추적, 영향 범위 분석을 수행하고, 구체적인 대응 가이드를 claudedocs/{title}.md로 생성한다.
  이 스킬은 Lane4 서비스(뉴어드민, 법인어드민, 레인포웹, 레인포앱, 기사앱)에서 발생하는 
  배차/결제/알림/관제/외부연동/앱/인프라 이슈를 다룬다. 
  사용자가 버그, 에러, 장애, 이슈, 문제를 언급하면서 Lane4 프로젝트와 관련된 맥락이 있을 때 반드시 이 스킬을 사용하라.
  "배차가 안 돼요", "결제 실패", "알림이 안 갔어요", "관제에서 위치가 안 보여요", "에미레이츠 파싱 실패" 같은 
  이슈 리포트에 모두 트리거되어야 한다. 이슈 분석뿐 아니라 코드 수정 방향까지 포함한 실행 가능한 대응 가이드를 생성하는 것이 핵심이다.
---

# Lane4 운영 이슈 대응 스킬

## 목적

운영 이슈가 발생했을 때 **사람의 개입 없이** 이슈를 분석하고 처리할 수 있도록, 프론트~백엔드 전체 코드를 탐색하여 원인을 파악하고, 실행 가능한 대응 가이드 문서를 자동 생성한다.

## 워크플로우 개요

```
[이슈 접수] → [분류] → [관련 프로젝트 식별] → [코드 탐색/분석] → [원인 파악] → [대응 가이드 생성]
```

---

## Step 1: 이슈 분류

이슈를 아래 카테고리 중 하나 이상으로 분류한다:

| 카테고리 | 키워드 | 주요 프로젝트 |
|---------|--------|-------------|
| **배차** | 배차, allocation, 예약, 생성 실패, 상태, 노쇼 | admin-api, partner-api, guest-api, app-api, allocation-api |
| **결제** | 결제, 환불, 취소, PG, 카드, billing | guest-api, app-api, admin-api, lane4_backend |
| **알림** | 알림, 푸시, SMS, 카카오, 이메일, notification | notification-api, notification-server, scheduler |
| **관제** | 위치, 관제, 모니터링, WebSocket, 실시간 | monitoring-api, driver-api, app-driver |
| **외부연동** | 에미레이츠, 클룩, 크리에이트립, 항공편, TMap | emirates-api, klook-api, scheduler, backend-library |
| **앱** | 앱, 로그인, CodePush, 스마트키, BLE | app-user, app-driver, driver-api, app-api |
| **인프라** | DB, Redis, Kafka, RabbitMQ, 커넥션, 타임아웃 | 전체 |

## Step 2: 관련 프로젝트 식별 및 코드 탐색

이슈 카테고리에 따라 아래 프로젝트 경로에서 관련 코드를 탐색한다.
**반드시 `references/project-map.md`를 먼저 읽어서** 프로젝트 간 호출 관계와 DB 테이블 매핑을 확인하라.

### 프로젝트 경로

```
프론트엔드:
  /Users/kyh/project/lane4/frontend/lane4-admin
  /Users/kyh/project/lane4/frontend/lane4-biz
  /Users/kyh/project/lane4/frontend/lane4-web
  /Users/kyh/project/lane4/frontend/lane4-app-user
  /Users/kyh/project/lane4/frontend/lane4-app-driver

백엔드:
  /Users/kyh/project/lane4/lane4-admin-api
  /Users/kyh/project/lane4/lane4-partner-api
  /Users/kyh/project/lane4/lane4-guest-api
  /Users/kyh/project/lane4/lane4-app-api
  /Users/kyh/project/lane4/lane4-driver-api
  /Users/kyh/project/lane4/lane4-monitoring-api
  /Users/kyh/project/lane4/lane4-notification-api
  /Users/kyh/project/lane4/lane4-notification-server
  /Users/kyh/project/lane4/lane4-scheduler
  /Users/kyh/project/lane4/lane4-allocation-api
  /Users/kyh/project/lane4/lane4-backend-library
  /Users/kyh/project/lane4/lane4-emirates-api
  /Users/kyh/project/lane4/lane4-klook-api
  /Users/kyh/project/lane4/lane4_backend
```

### 코드 탐색 전략

JetBrains 도구를 적극 활용하여 분석한다:

1. **키워드 검색** (`search_in_files_by_text` / `search_in_files_by_regex`): 이슈 관련 키워드(에러 메시지, API 엔드포인트, 테이블명, 함수명)로 관련 코드를 찾는다
2. **파일 구조 파악** (`list_directory_tree`): 관련 도메인 모듈의 디렉토리 구조를 파악한다
3. **코드 읽기** (`get_file_text_by_path`): 핵심 파일(service, controller, entity, dto)을 읽고 로직을 분석한다
4. **심볼 정보** (`get_symbol_info`): 특정 함수나 타입의 정의를 추적한다
5. **파일 검색** (`find_files_by_name_keyword`): 관련 파일을 빠르게 찾는다

### 탐색 순서 (이슈 유형별)

**배차 이슈:**
1. 관련 API의 `allocation` 또는 `call` 도메인 모듈 확인
2. service 파일에서 생성/수정/상태변경 로직 분석
3. ALLOCATION, ALLOC_STATUS_HIST 엔티티 확인
4. allocation-api의 예약 가능일자 로직 확인
5. 프론트엔드 API 호출 코드 확인

**결제 이슈:**
1. 관련 API의 `payment` 또는 `pay` 도메인 모듈 확인
2. PG 연동 코드 (Toss/PortOne/KCP) 분석
3. PAY_TRX, PG_REQ, PG_RES 엔티티 확인
4. lane4_backend의 결제 관련 Java 코드 확인 (레거시 연동 시)

**알림 이슈:**
1. notification-api의 TaskType 매핑 확인
2. notification-server의 발송 채널별 핸들러 확인
3. 호출하는 API의 NotificationUtils.notify() 호출부 확인
4. RabbitMQ 큐 설정 확인

**관제 이슈:**
1. monitoring-api의 WebSocket 게이트웨이 확인
2. Kafka consumer 구현 확인
3. driver-api의 위치 전송 로직 확인
4. Redis 위치 저장 로직 확인

**외부연동 이슈:**
1. emirates-api / klook-api의 파싱/크롤링 로직 확인
2. backend-library의 외부 API 유틸 확인
3. scheduler의 관련 cron 작업 확인

**앱 이슈:**
1. 프론트엔드 앱 코드에서 관련 화면/훅 확인
2. 백엔드 API 엔드포인트 확인
3. 인증 관련이면 auth 도메인 확인

## Step 3: 원인 분석

코드 탐색 결과를 바탕으로 다음을 분석한다:

1. **데이터 흐름**: 요청 시작점(프론트) → API 엔드포인트 → 서비스 로직 → DB/외부API → 응답
2. **에러 발생 지점**: try-catch, 조건 분기, 유효성 검증 실패 지점
3. **의존성 체인**: 프로젝트 간 호출(HTTP, Kafka, RabbitMQ, Redis RPC), 외부 API 의존
4. **DB 상태**: 관련 테이블과 컬럼, 상태값, 제약조건
5. **타이밍 이슈**: 스케줄러 주기, 캐시 TTL, 토큰 만료, 비동기 처리 순서

## Step 4: 대응 가이드 문서 생성

분석 결과를 `claudedocs/{title}.md` 파일로 생성한다. title은 이슈를 간결하게 요약한 kebab-case 문자열로 한다.

### 문서 템플릿

```markdown
# [이슈 제목]

> 생성일: {YYYY-MM-DD}
> 분류: {카테고리}
> 심각도: {Critical/High/Medium/Low}
> 관련 서비스: {서비스 목록}

## 1. 이슈 요약

{이슈에 대한 간결한 설명}

## 2. 영향 범위

- **영향받는 서비스**: {프론트엔드, 백엔드 목록}
- **영향받는 사용자**: {고객/기사/운영자/법인}
- **영향받는 기능**: {구체적 기능 목록}

## 3. 원인 분석

### 3.1 데이터 흐름
{요청부터 응답까지의 전체 데이터 흐름을 다이어그램 또는 단계별로 기술}

### 3.2 근본 원인
{코드 분석 결과 파악된 근본 원인. 관련 코드 파일 경로와 라인 포함}

### 3.3 관련 코드

| 프로젝트 | 파일 | 설명 |
|---------|------|------|
| {프로젝트명} | {파일 경로} | {해당 코드의 역할} |

### 3.4 관련 DB 테이블

| 테이블 | 주요 컬럼 | 확인 쿼리 |
|--------|----------|----------|
| {테이블명} | {컬럼 목록} | {진단용 SQL 쿼리} |

## 4. 대응 방안

### 4.1 즉시 조치 (Hotfix)
{즉각 적용 가능한 수정 사항. 구체적 코드 변경 포함}

#### 수정 대상 파일 및 변경 내용:

**파일: {경로}**
```diff
- {삭제할 코드}
+ {추가할 코드}
```

### 4.2 확인 절차
{수정 후 확인해야 할 항목}

1. {확인 항목 1}: {확인 방법}
2. {확인 항목 2}: {확인 방법}

### 4.3 DB 확인/수정 쿼리
```sql
-- 현재 상태 확인
{조회 쿼리}

-- 필요시 데이터 수정 (주의: 반드시 백업 후 실행)
{수정 쿼리}
```

### 4.4 근본적 개선 (장기)
{재발 방지를 위한 구조적 개선 사항}

## 5. 모니터링

- **확인 로그**: {Sentry/Datadog/Slack 채널}
- **주요 메트릭**: {모니터링할 지표}
- **알림 설정**: {필요한 알림 추가 사항}

## 6. 참고

- **관련 API 엔드포인트**: {URL 목록}
- **관련 Kafka 토픽**: {토픽 목록}
- **관련 스케줄러 작업**: {Cron 작업 목록}
- **외부 API**: {외부 서비스 목록}
```

## 핵심 원칙

1. **코드 기반 분석**: 추측하지 말고 반드시 실제 코드를 읽고 분석하라. JetBrains 도구로 프로젝트 코드를 탐색하라.
2. **전체 흐름 추적**: 프론트엔드 호출부터 백엔드 처리, DB, 외부 API까지 End-to-End로 추적하라.
3. **실행 가능한 가이드**: "~할 수 있다" 같은 모호한 표현 대신 구체적 파일 경로, 코드 diff, SQL 쿼리를 포함하라.
4. **자동화 우선**: 사람이 수동으로 판단해야 하는 부분을 최소화하라. 확인 쿼리와 수정 사항을 바로 실행할 수 있게 작성하라.
5. **영향 범위 명시**: 수정이 다른 서비스에 미치는 영향을 반드시 분석하라 (공유 DB, 공통 라이브러리 사용 시 특히 주의).

## DB 참조 정보

- **Prod Master**: `prod-lane4-aurora.cluster-cjog7fnrqcmz.ap-northeast-2.rds.amazonaws.com:3306`
- **Prod Slave**: `prod-lane4-aurora.cluster-ro-cjog7fnrqcmz.ap-northeast-2.rds.amazonaws.com:3306`
- **Dev**: `test-lane4-aurora.cluster-cjog7fnrqcmz.ap-northeast-2.rds.amazonaws.com:3306`
- **Database**: LANE4

## API 참조

| 서비스 | Prod URL | Dev URL |
|--------|----------|---------|
| admin-api | https://admin-api.lane4.ai | https://test-admin-api.lane4.ai |
| partner-api | https://partner-api.lane4.ai | https://test-partner-api.lane4.ai |
| guest-api | https://guest-api.lane4.ai | https://test-guest-api.lane4.ai |
| app-api | https://app-api.lane4.ai | https://test-app-api.lane4.ai |
| driver-api | https://driver-api.lane4.ai | https://test-driver-api.lane4.ai |
| monitoring-api | https://monitoring-api.lane4.ai | https://test-monitoring-api.lane4.ai |
| legacy | https://api.lane4.ai/api/ | https://test-api.lane4.ai/api/ |

## 표준 응답 포맷

```typescript
// 성공: { result: true, code: null | 0, data: { ... } }
// 실패: { result: false, code: number, data: { message: string } }
```
