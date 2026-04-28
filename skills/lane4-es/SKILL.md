---
name: lane4-es
description: |
  LANE4 Elasticsearch 자연어 쿼리 및 실시간 데이터 분석 스킬.
  lane4-es MCP 서버를 통해 ES에 접근하여 자연어 질문을 ES|QL 또는 Query DSL로 변환하고 실행한다.
  이 스킬은 다음 상황에서 반드시 사용한다:
  - 기사/차량의 실시간 위치, 이동 경로, 운행 상태 조회
  - 배차 경로(실제/예측) 조회 및 비교
  - 셔틀 상태 이력, 배차 상태 알림 이력 조회
  - 지역/목적지 검색 (반경 검색, 지오펜싱, 벡터 검색)
  - 시계열 데이터 집계 및 분석
  - ES 인덱스 구조, 매핑 확인
  - 관제 대시보드 위치 데이터 이슈 디버깅
  위치, 실시간, 경로, 궤적, GPS, 좌표, 지오, geo, 운행, 트래킹, 반경, 인덱스 매핑 등의 키워드가 포함되면 이 스킬을 사용할 것.
  MySQL의 마스터/트랜잭션 데이터가 아닌 실시간/시계열/위치 데이터는 이 스킬의 영역이다.
---

# lane4-es 스킬

LANE4 Elasticsearch에 저장된 실시간/시계열 운영 데이터를 자연어로 조회·분석하는 스킬.

## 절대 규칙: READ-ONLY (쓰기 작업 전면 금지)

이 스킬은 **조회 전용**이다. 어떤 상황에서도 ES 데이터를 변경하는 작업을 수행해서는 안 된다.

### 허용되는 작업 (읽기만)

| 도구 | 허용 여부 | 용도 |
|------|----------|------|
| `list_indices` | **허용** | 인덱스 목록 조회 |
| `get_mappings` | **허용** | 인덱스 매핑 조회 |
| `get_shards` | **허용** | 샤드 상태 조회 |
| `search` | **허용** | Query DSL 검색 (읽기) |
| `esql` | **조건부 허용** | SELECT/FROM 조회만 허용 |

### 금지되는 작업 (절대 수행 금지)

사용자가 명시적으로 요청하더라도 아래 작업은 거부하고 이유를 설명한다:

- **문서 생성/수정/삭제**: index, update, delete, bulk write 등 문서 변경 작업
- **인덱스 생성/삭제/설정 변경**: create index, delete index, put mapping, put settings 등
- **별칭(alias) 변경**: add/remove alias 등
- **ES|QL로 변경 쿼리 실행**: INSERT, UPDATE, DELETE 등 변경성 ES|QL 문
- **reindex, snapshot, restore** 등 클러스터 운영 작업
- **인덱스 열기/닫기(open/close)**, **refresh/flush/forcemerge** 등 관리 작업

### 거부 시 응답 예시

```
❌ ES 데이터 쓰기/수정/삭제는 이 스킬에서 수행할 수 없습니다.
ES 데이터 변경이 필요한 경우, 해당 데이터를 생산하는 원본 서비스(lane4-monitoring-api, lane4-admin-api 등)에서 처리해야 합니다.
```

---

## 핵심 원칙

1. **READ-ONLY** — 위 절대 규칙을 반드시 준수한다.
2. **대용량 보호** — `actual-allocation-path`(1.39억건), `allocation_location`(1,860만건) 등은 반드시 ID + 시간 범위 조건 + `size` 제한을 포함해야 한다.
3. **일별 인덱스 패턴** — `driver-location_*`, `car-history_*`, `shuttle-status-history_*`는 날짜별 롤링 인덱스다. 와일드카드(`*`) 또는 특정 날짜(`_2026-02-27`)를 지정한다.
4. **도구 선택** — 단순 필터링/집계는 `esql`, 지리/nested/집계/벡터 검색은 `search`(Query DSL).
5. **스킬 간 연계** — ES에 없는 마스터 데이터(법인 상세, 요금 등)는 `lane4-mysql`, 캐시 비교는 `lane4-redis`, 실시간 운행 상태 교차확인은 `lane4-firebase`와 연계한다.

## lane4-mysql과의 역할 분담

| 구분 | lane4-mysql | lane4-es (이 스킬) |
|------|-------------|---------------------|
| 대상 | 마스터 데이터, 트랜잭션 기록 | 실시간 상태, 위치, 시계열 로그 |
| 데이터 성격 | 정규화된 관계형 데이터 | 비정규화된 문서/이벤트 데이터 |
| 주요 쿼리 | JOIN, GROUP BY, 집계 | geo_point 검색, 시계열 집계, 텍스트/벡터 검색 |
| 예시 | "이번 달 법인별 매출", "기사 스케줄" | "현재 운행 중인 기사 위치", "오늘 배차 경로" |

## MCP 도구

`lane4-es` MCP 서버에서 제공하는 도구:

| 도구 | 용도 | 사용 시점 |
|------|------|----------|
| `list_indices` | 인덱스 목록 조회 | 어떤 인덱스가 있는지 확인할 때 |
| `get_mappings` | 인덱스 매핑(스키마) 조회 | 필드명/타입을 확인할 때 |
| `get_shards` | 샤드 상태 조회 | 인프라 상태 확인할 때 |
| `search` | Query DSL 검색 | 복잡한 geo/nested 쿼리, 복합 집계 |
| `esql` | ES\|QL 쿼리 실행 | 단순 필터링/집계, SQL-like 조회 |

### 도구 선택 기준

```
단순 필터링/집계/정렬         → esql (SQL-like 문법, 간결)
geo_point 검색 (반경, bbox)  → search (Query DSL)
nested 필드 검색             → search (Query DSL)
dense_vector 유사도 검색      → search (Query DSL, kNN)
복합 집계 (aggs + sub-aggs)  → search (Query DSL)
```

## 워크플로우

질문을 받으면 아래 순서로 처리한다:

1. **도메인 파악** → `references/index-map.md`를 참조하여 어떤 인덱스 도메인에 해당하는지 판단
2. **인덱스 선택** → 일별 롤링 인덱스면 오늘 날짜 기반 인덱스명 결정 (예: `driver-location_2026-02-27`)
3. **필드 확인** → `references/index-schemas.md`에서 필드명과 타입 확인
4. **쿼리 방식 결정** → 위 도구 선택 기준에 따라 `esql` vs `search` 결정
5. **쿼리 패턴 참고** → `references/query-patterns.md`에서 유사 쿼리 템플릿 참조
6. **MCP 도구로 실행** → 쿼리 실행
7. **결과 해석 및 요약** → 사용자에게 이해하기 쉬운 형태로 전달

## 대용량 인덱스 보호 규칙

아래 인덱스는 조건 없이 전체 스캔하면 안 된다:

| 인덱스 | 문서 수 | 필수 조건 |
|--------|---------|----------|
| `actual-allocation-path` | 1.39억 | `allocationId` + 시간 범위 + `size` ≤ 100 |
| `allocation_location` | 1,860만 | `driver_id` + 시간 범위 + `size` ≤ 100 |
| `driver-location_*` | 일별 75만 | 특정 날짜 인덱스 지정 + 필터 조건 + `size` ≤ 1000 |

이 규칙을 지키지 않으면 ES 클러스터에 과부하를 줄 수 있다.

## 일별 인덱스 날짜 처리

- 오늘 날짜 기반으로 인덱스명 자동 생성: `driver-location_{오늘날짜}` (예: `driver-location_2026-02-27`)
- 범위 조회 시 와일드카드 사용 가능: `driver-location_2026-02-*`
- `car-history_default`는 별도 상시 인덱스 (일별과 병행)
- 너무 넓은 범위의 와일드카드는 지양 (예: `driver-location_*`보다 `driver-location_2026-02-*`)

## 법인코드 참조

| 법인코드 | 법인명 | 비고 |
|---------|--------|------|
| `gmcc` | GMCC | 주요 법인 |
| `lane4` | Lane4 | 자사 |
| `emirates` | 에미레이츠 | 항공사 제휴 |
| `ke` | 대한항공 | 항공사 제휴 |

## 스킬 간 연계 시나리오

| 연계 스킬 | 시나리오 | 연계 방법 |
|-----------|---------|----------|
| **lane4-mysql** | ES의 driverId로 기사 상세정보(이름, 소속 등) 조회 | ES 결과의 ID → MySQL DRIVER 테이블 JOIN |
| **lane4-mysql** | ES의 allocationId로 배차 상세정보(요금, 고객 등) 조회 | ES 결과의 ID → MySQL ALLOCATION 테이블 JOIN |
| **lane4-redis** | 배차 좌표 캐시(`allocations-coordinates:*`) vs ES 실제 경로 비교 | Redis 캐시 좌표 조회 → ES actual-allocation-path 좌표 조회 → 비교 |
| **lane4-firebase** | Firebase RTDB 운행 상태와 ES driver/driver-location 실시간 상태 교차 확인 | 두 소스의 동일 기사 상태 비교 |
| **lane4-issue** | "관제에서 위치가 안 보여요" → ES driver-location 인덱스 데이터 존재 확인 | 최근 timestamp 점검 → 데이터 공백 구간 확인 |
| **lane4-issue** | "기사 경로가 이상해요" → actual vs predicated 경로 비교 | 두 인덱스의 동일 allocationId 좌표 대조 |

크로스 레퍼런스 상세는 `references/cross-reference.md`를 참조한다.

## 자연어 → 쿼리 변환 예시

| 자연어 질문 | 도구 | 쿼리 방식 |
|------------|------|----------|
| "현재 운행 중인 기사 목록" | `esql` | `FROM driver WHERE drivingStatus == "DRIVING"` |
| "강남역 반경 3km 내 기사" | `search` | `geo_distance` on `driver-location_오늘날짜` |
| "배차 12345의 실제 이동 경로" | `search` | `term` on `actual-allocation-path` + size 제한 |
| "오늘 기사 홍길동의 위치 이력" | `esql` | `FROM driver-location_오늘날짜 WHERE name == "홍길동"` |
| "인천공항 근처 목적지 검색" | `search` | `geo_distance` 또는 `knn` on `destinations` |
| "이번 주 셔틀 상태 변경 이력" | `esql` | `FROM shuttle-status-history_* WHERE createdAt >= ...` |

## 데이터 플로우 (코드베이스 참조)

ES 데이터가 어떻게 생산·소비되는지 이해하면 디버깅에 도움이 된다:

```
lane4-admin-api (Car/Driver 변경)
    ↓ SyncElasticSearchService (Kafka 메시지 발행)
    ↓ Topic: local.monitoring.sync.elastic-search
lane4-monitoring-api (Kafka 소비 → ES 색인)
    ↓ IndexDocumentService
Elasticsearch (driver-location_*, car-history_*, shuttle-status-history_*)
    ↓
lane4-monitoring-api (조회 → 관제 대시보드 제공)
```

| 프로젝트 | 역할 | 관련 인덱스 |
|---------|------|-----------|
| **lane4-admin-api** | Producer (Kafka 경유) | `car-history_*`, `driver-location`, `voice_report_process_result` |
| **lane4-monitoring-api** | Producer/Consumer (핵심) | `driver-location_*`, `car-history_*`, `shuttle-status-history_*` |
| **lane4-partner-api** | Producer/Consumer | `destinations` (벡터 임베딩) |
| **lane4-scheduler** | Consumer | `destinations` (벡터 검색) |

## 참조 문서

- `references/index-map.md` — 인덱스 도메인별 분류 및 규모 요약
- `references/index-schemas.md` — 인덱스별 전체 필드 매핑 상세
- `references/query-patterns.md` — 카테고리별 ES|QL / Query DSL 쿼리 템플릿
- `references/cross-reference.md` — MySQL ↔ ES 테이블 매핑 및 연계 조회 가이드
