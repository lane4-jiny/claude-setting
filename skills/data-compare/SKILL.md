---
name: data-compare
description: >
  LANE4 크로스 데이터소스 정합성 비교·진단 메타스킬.
  MySQL, Redis, ES, Firebase 4개 데이터 소스 간 데이터 불일치를 체계적으로 비교·분석한다.
  이 스킬은 도구를 직접 호출하지 않고, 전담 스킬(lane4-mysql, lane4-redis, lane4-es, lane4-firebase)에 위임한다.
  이 스킬은 다음 상황에서 반드시 사용한다:
  - "데이터 불일치", "데이터가 안 맞아요", "캐시 불일치", "수치 차이" 등 정합성 이슈
  - "대시보드 숫자가 달라요", "앱이랑 관리자 화면이 달라" 등 소스 간 괴리 보고
  - "Redis랑 DB 비교", "ES랑 MySQL 비교" 등 명시적 교차 비교 요청
  - "캐시 갱신이 안 됐어", "데이터 동기화 문제" 등 파이프라인 이슈 의심
  - 장애/이슈 진단 중 여러 소스의 데이터를 교차 확인할 필요가 있을 때
---

# data-compare 스킬

## 역할

LANE4 서비스의 4대 데이터 소스(MySQL, Redis, ES, Firebase) 간 데이터 정합성을 비교·진단하는 **오케스트레이션 메타스킬**.

직접 MCP 도구나 CLI를 호출하지 않는다. 각 데이터 소스 조회는 반드시 전담 스킬에 위임한다:

| 데이터 소스 | 전담 스킬 | 위임 방법 |
|------------|----------|----------|
| MySQL | `lane4-mysql` | `/lane4-mysql` 스킬 호출 |
| Redis | `lane4-redis` | `/lane4-redis` 스킬 호출 |
| Elasticsearch | `lane4-es` | `/lane4-es` 스킬 호출 |
| Firebase RTDB | `lane4-firebase` | `/lane4-firebase` 스킬 호출 |

## Source of Truth 계층

데이터 불일치 발견 시, 아래 계층에 따라 어느 소스가 정확한지 판단한다:

```
MySQL (원본 마스터)
  └─ ES (실시간 원본 — 위치/상태 도메인)
       └─ Firebase (앱 상태 원본 — 콜/운행 상태)
            └─ Redis (캐시 — 대시보드/요금/좌표)
```

**도메인별 Source of Truth:**

| 도메인 | Source of Truth | 보조 소스 |
|--------|---------------|----------|
| 배차 마스터 데이터 (금액, 승객, 주소) | MySQL `ALLOCATION` | - |
| 배차 실시간 상태 | ES `driver` 인덱스 | Firebase `driving/driver_{id}/resv` |
| 기사 실시간 위치/경로 | ES `actual-allocation-path` | Redis `allocations-coordinates:*` |
| 기사 근무 상태 | ES `driver` 인덱스 (`drivingStatus`) | MySQL `DRIVER.WORK_STATUS` |
| 대시보드 통계 | MySQL (집계 쿼리) | Redis `dashboard:*`, ES `allocation` |
| 요금 정보 | MySQL `FARE` | Redis `fares:*` |
| 매출 통계 | MySQL `FARE_HISTORY` | Redis `operational-analytics:*` |
| 콜/호출 상태 | Firebase `calling/user_{id}` | ES `allocation` |
| 앱 점검/버전 | Firebase `common/maintenance` | - |

## 비교 시나리오

### 시나리오 1: 대시보드 캐시 불일치
> 트리거: "대시보드 숫자가 달라요", "배차 건수가 안 맞아요"

**비교 대상:** Redis `dashboard:*` ↔ MySQL `ALLOCATION` 집계 ↔ ES `allocation`

**워크플로우:**
1. 법인코드(companyCode) 확인 → `references/field-mapping.md` 참조
2. `/lane4-redis` → `dashboard:{companyCode}:TYPE3` 의 `values.summary` 조회
3. `/lane4-mysql` → 같은 기간 ALLOCATION 집계 쿼리 (STATUS별 건수)
4. `/lane4-es` → `allocation` 인덱스에서 같은 법인 건수 집계
5. 3자 비교 테이블 출력 → 불일치 시 `references/diagnostic-guide.md` 진단

### 시나리오 2: 배차 좌표/경로 불일치
> 트리거: "위치가 안 맞아", "경로가 이상해", "좌표 불일치"

**비교 대상:** Redis `allocations-coordinates:*` ↔ ES `actual-allocation-path` ↔ ES `predicated-allocation-path`

**워크플로우:**
1. 배차 ID(allocId) 확인
2. `/lane4-redis` → `allocations-coordinates:{companyCode}:{allocId}` 조회
3. `/lane4-es` → `actual-allocation-path` 에서 해당 allocationId 최신 레코드
4. `/lane4-es` → `predicated-allocation-path` 에서 예측 경로
5. 좌표 비교 + Redis TTL/신선도 확인

### 시나리오 3: 요금 캐시 불일치
> 트리거: "요금이 달라요", "요금 캐시 확인", "요금 불일치"

**비교 대상:** Redis `fares:*` ↔ MySQL `FARE`

**워크플로우:**
1. 법인코드 + 차량모델ID 확인
2. `/lane4-redis` → `fares:{companyCode}:distance:*:{carModelId}` 조회
3. `/lane4-mysql` → `FARE` 테이블에서 동일 조건 조회
4. 금액 비교 테이블 출력

### 시나리오 4: 기사 상태 불일치
> 트리거: "기사 상태가 안 맞아", "운행 중인데 대기로 나와", "기사 상태 확인"

**비교 대상:** MySQL `DRIVER` ↔ ES `driver` ↔ Firebase `driving/driver_{id}`

**워크플로우:**
1. 기사 ID(driverId) 확인
2. `/lane4-mysql` → `DRIVER` 테이블의 `WORK_STATUS`, `COMMUTE_STATUS`, `CALL_STATUS`
3. `/lane4-es` → `driver` 인덱스에서 `drivingStatus`, `allocationId`, `allocationStatus`
4. `/lane4-firebase` → `driving/driver_{driverId}/resv` 에서 `status`, `allocId`
5. 상태값 매핑 비교 → `references/field-mapping.md`의 상태값 매핑표 참조

### 시나리오 5: 배차 상태 불일치
> 트리거: "배차 상태가 안 맞아", "완료됐는데 진행 중으로 나와"

**비교 대상:** MySQL `ALLOCATION` ↔ ES `driver` ↔ Firebase `driving/driver_{id}/resv`

**워크플로우:**
1. 배차 ID(allocId) 또는 기사 ID(driverId) 확인
2. `/lane4-mysql` → `ALLOCATION.STATUS` 조회
3. `/lane4-es` → `driver` 인덱스에서 `allocationStatus` 조회
4. `/lane4-firebase` → `driving/driver_{driverId}/resv/status` 조회
5. 상태값 3자 비교 → 불일치 원인 진단

### 시나리오 6: 매출 캐시 불일치
> 트리거: "매출 수치가 안 맞아", "매출 캐시 확인", "운영 분석 데이터 불일치"

**비교 대상:** Redis `operational-analytics:*:revenue` ↔ MySQL `FARE_HISTORY`

**워크플로우:**
1. 법인코드 확인
2. `/lane4-redis` → `operational-analytics:{companyCode}:revenue` 의 `values` 조회
3. `/lane4-mysql` → `FARE_HISTORY` 에서 같은 법인·기간 매출 집계
4. 금액 비교 + `lastUpdatedAt` 신선도 확인

## 비교 결과 출력 형식

모든 비교 결과는 아래 형식을 따른다:

### 1. 비교 요약 테이블

```markdown
## 비교 결과: {시나리오명}

| 항목 | MySQL | Redis | ES | Firebase | 일치 |
|------|-------|-------|-----|----------|------|
| 배차 건수 | 203 | 203 | 203 | - | ✅ |
| 완료 건수 | 185 | 180 | 185 | - | ❌ |
| 취소 건수 | 18 | 23 | 18 | - | ❌ |
```

- 해당 소스에 데이터가 없는 항목은 `-`로 표시
- 일치: ✅ / 불일치: ❌

### 2. 불일치 분석

불일치 항목이 있을 때만 출력:

```markdown
### 불일치 분석

**불일치 항목:** 완료 건수, 취소 건수
**Source of Truth:** MySQL (원본 마스터)
**불일치 소스:** Redis (캐시)
**차이:** MySQL=185건, Redis=180건 (5건 차이)
**추정 원인:** Redis 캐시 갱신 지연 (lastUpdatedAt: 2시간 전)
**조치 방안:** 캐시 갱신 주기 확인 또는 수동 갱신 필요
```

### 3. 캐시 신선도 표시

Redis/Firebase 데이터 포함 시 항상 표시:

```markdown
### 캐시 신선도

| 소스 | 키/경로 | lastUpdatedAt | 경과 시간 | TTL | 상태 |
|------|--------|--------------|----------|-----|------|
| Redis | dashboard:gmcc:TYPE3 | 2026-03-03 14:30:00 | 32분 | 10368000s | 🟢 정상 |
| Redis | fares:gmcc:distance:... | - | - | -1 (영구) | 🟡 확인 필요 |
```

상태 기준:
- 🟢 정상: 갱신 주기 내 (대시보드: 1시간, 매출: 1시간)
- 🟡 확인 필요: TTL=-1(영구 캐시) 또는 갱신 시각 없음
- 🔴 만료/지연: 갱신 주기 초과 또는 TTL=-2(만료)

## 조회 순서 원칙

비교 시 데이터 조회 순서는 **빠른 소스 → 느린 소스** 순:

1. **Redis** (밀리초) — 캐시 현재 상태 확인
2. **Firebase** (수백 밀리초) — 앱 실시간 상태 확인
3. **ES** (초 단위) — 실시간 인덱스 조회
4. **MySQL** (초 단위) — 원본 마스터 확인

빠른 소스에서 이상 없으면 느린 소스 조회를 생략할 수 있다.

## 참조 문서

| 문서 | 용도 |
|------|------|
| `references/field-mapping.md` | 소스 간 필드명·상태값·엔티티 ID 매핑 |
| `references/comparison-patterns.md` | 소스 쌍별 비교 워크플로우 상세 |
| `references/diagnostic-guide.md` | 불일치 원인 진단 의사결정 트리 |

## 안전 제약

1. **READ ONLY** — 모든 데이터 소스에 대해 읽기 전용. 캐시 삭제/갱신, DB 수정 절대 금지.
2. **위임 전용** — MCP 도구나 Firebase CLI를 직접 호출하지 않는다. 반드시 전담 스킬 경유.
3. **민감 데이터 마스킹** — 개인정보(전화번호, 이메일 등) 출력 시 마스킹 처리.
4. **대량 조회 금지** — 비교에 필요한 최소한의 데이터만 조회. 전체 덤프 금지.
5. **조치 방안은 제안만** — 캐시 갱신, 재동기화 등 수정 작업은 제안만 하고 실행하지 않는다.
