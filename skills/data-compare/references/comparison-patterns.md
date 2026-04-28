# 소스 쌍별 비교 워크플로우

## 조회 순서 원칙

비교 시 항상 빠른 소스부터 조회하여 불필요한 쿼리를 최소화한다:

```
1. Redis (밀리초)     → 캐시 현재 상태 즉시 확인
2. Firebase (수백ms)  → 앱 실시간 상태 확인
3. ES (초 단위)       → 실시간 인덱스 조회
4. MySQL (초 단위)    → 원본 마스터 최종 확인
```

빠른 소스에서 정상이면 느린 소스 조회를 **생략 가능**.
불일치 발견 시에만 Source of Truth(MySQL/ES)까지 확인한다.

---

## 2자 비교 패턴

### Redis ↔ MySQL

**적용 도메인:** 대시보드, 요금, 매출

#### 대시보드 건수 비교

```
1. /lane4-redis → hgetall dashboard:{companyCode}:TYPE3
   - values.summary.totalSummary.daily.current 추출
   - lastUpdatedAt 추출 → 신선도 확인

2. /lane4-mysql →
   SELECT STATUS, COUNT(*) cnt
   FROM ALLOCATION
   WHERE ALLOC_DT = CURDATE() AND COMP_CD = '{companyCode}'
   GROUP BY STATUS
   - STATUS='50' → completedCount
   - STATUS IN ('55','50N') → cancelledCount
   - 전체 합 → totalCount

3. 비교 항목:
   - totalCount (Redis summary.daily.current vs MySQL 전체)
   - completedCount
   - cancelledCount + notBoardedCount
```

#### 요금 비교

```
1. /lane4-redis → get fares:{companyCode}:distance:{startRange}:{endRange}:{carModelId}
   - JSON 파싱 → 요금 항목 추출

2. /lane4-mysql →
   SELECT * FROM FARE
   WHERE COMPANY_CODE = '{companyCode}'
     AND CAR_MODEL_ID = {carModelId}
   - SERVICE_FARE, CAR_FARE, ADDITIONAL_DISTANCE_FARE 비교

3. 비교 항목:
   - 기본 요금 (SERVICE_FARE)
   - 차량 요금 (CAR_FARE)
   - 추가 거리 요금 (ADDITIONAL_DISTANCE_FARE)
```

#### 매출 비교

```
1. /lane4-redis → hgetall operational-analytics:{companyCode}:revenue
   - values 파싱 → 매출 합계 추출
   - lastUpdatedAt → 신선도 확인

2. /lane4-mysql →
   SELECT SUM(TOTAL_AMOUNT) total, SUM(PAYMENT_AMOUNT) payment
   FROM FARE_HISTORY
   WHERE COMPANY_CODE = '{companyCode}'
     AND CREATED_DATE = CURDATE()

3. 비교 항목:
   - 총 매출 (TOTAL_AMOUNT)
   - 결제 금액 (PAYMENT_AMOUNT)
```

### Redis ↔ ES

**적용 도메인:** 좌표/경로

#### 배차 좌표 비교

```
1. /lane4-redis → get allocations-coordinates:{companyCode}:{allocId}
   - 좌표 데이터 + TTL 확인

2. /lane4-es → search actual-allocation-path
   {
     "query": { "term": { "allocationId": {allocId} } },
     "sort": [{ "timestamp": "desc" }],
     "size": 1
   }
   - 최신 좌표(location) + timestamp 추출

3. 비교 항목:
   - 최신 좌표 위치 (위도/경도)
   - 타임스탬프 차이 (Redis 캐시 vs ES 실제)
```

### Firebase ↔ MySQL

**적용 도메인:** 배차 상태, 콜 상태

#### 배차 상태 비교

```
1. /lane4-firebase →
   firebase --project lane4-driver-c8064 database:get /real/driving/driver_{driverId}/resv
   - allocId, status 추출

2. /lane4-mysql →
   SELECT ALLOC_ID, STATUS, DRV_ID
   FROM ALLOCATION
   WHERE ALLOC_ID = {allocId}
   - 또는: WHERE DRV_ID = {driverId} AND STATUS IN ('정상','10','20','30') ORDER BY REG_DT DESC LIMIT 1

3. 비교 항목:
   - allocId 일치 여부
   - status 매핑 일치 여부 (field-mapping.md 참조)
   - Firebase에 데이터 있는데 MySQL STATUS='50'이면 동기화 지연
```

#### 콜 상태 비교

```
1. /lane4-firebase →
   firebase --project lane4-driver-c8064 database:get /real/calling/user_{userId}
   - allocId_{allocId}: true 목록 추출

2. /lane4-mysql →
   SELECT a.ALLOC_ID, a.STATUS
   FROM ALLOCATION a
   JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
   WHERE cr.USER_ID = {userId} AND a.STATUS IN ('정상','10','20','30')

3. 비교 항목:
   - Firebase calling 목록 vs MySQL 활성 배차 목록
   - Firebase에만 있는 allocId → 해제 안 된 잔여 콜
   - MySQL에만 있는 allocId → Firebase 동기화 누락
```

### Firebase ↔ ES

**적용 도메인:** 기사 실시간 상태

#### 기사 운행 상태 비교

```
1. /lane4-firebase →
   firebase --project lane4-driver-c8064 database:get /real/driving/driver_{driverId}
   - resv.status, resv.allocId 추출

2. /lane4-es → esql
   FROM driver
   | WHERE id == "{driverId}"
   | KEEP id, drivingStatus, allocationId, allocationStatus
   - drivingStatus, allocationId, allocationStatus 추출

3. 비교 항목:
   - Firebase resv.allocId vs ES allocationId
   - Firebase resv.status vs ES allocationStatus
   - Firebase 노드 존재 + ES drivingStatus=DEFAULT → 동기화 불일치
```

---

## 3자 비교 패턴

### Redis ↔ MySQL ↔ ES (대시보드 종합)

> 대시보드 캐시가 원본과 일치하는지 3방향 검증

```
1. /lane4-redis → dashboard:{companyCode}:TYPE3
   → 일별/주별/월별 건수 추출

2. /lane4-mysql → ALLOCATION 집계
   → 같은 기간 STATUS별 건수

3. /lane4-es → allocation 인덱스 집계
   → 같은 법인 활성 배차 건수

비교 매트릭스:
┌────────────┬────────┬────────┬────────┐
│    항목     │ MySQL  │  Redis │   ES   │
├────────────┼────────┼────────┼────────┤
│ 전체 건수   │  203   │  203   │  45*   │
│ 완료 건수   │  185   │  180   │   -    │
│ 취소 건수   │   18   │   23   │   -    │
│ 활성 건수   │   12   │   -    │  12    │
└────────────┴────────┴────────┴────────┘
* ES allocation 인덱스는 활성 배차만 보유

판정:
- MySQL = Redis → ✅ 캐시 정상
- MySQL ≠ Redis, MySQL = ES → Redis 캐시 갱신 지연
- MySQL ≠ ES → ES 동기화 지연 (Kafka 확인)
- 3자 모두 다름 → 파이프라인 전체 점검 필요
```

### MySQL ↔ ES ↔ Firebase (기사 상태 종합)

> 기사의 운행 상태를 3개 소스에서 교차 검증

```
1. /lane4-mysql →
   SELECT DRV_ID, WORK_STATUS, COMMUTE_STATUS, CALL_STATUS FROM DRIVER WHERE DRV_ID = {driverId}
   SELECT ALLOC_ID, STATUS FROM ALLOCATION WHERE DRV_ID = {driverId} AND STATUS IN ('정상','10','20','30') LIMIT 1

2. /lane4-es → driver 인덱스
   drivingStatus, allocationId, allocationStatus

3. /lane4-firebase → driving/driver_{driverId}/resv
   allocId, status

비교 매트릭스:
┌──────────────┬──────────────────┬──────────────┬──────────────┐
│     항목      │     MySQL        │     ES       │   Firebase   │
├──────────────┼──────────────────┼──────────────┼──────────────┤
│ 운행 상태     │ WORK_STATUS      │ drivingStatus│ resv 존재여부 │
│ 현재 배차 ID  │ ALLOCATION 조회   │ allocationId │ resv.allocId │
│ 배차 상태     │ ALLOCATION.STATUS│ allocStatus  │ resv.status  │
└──────────────┴──────────────────┴──────────────┴──────────────┘

정상 시나리오:
- MySQL WORK_STATUS=CALL_COMMUTE + ES DRIVING + Firebase resv 있음 → 운행 중 (정상)
- MySQL WORK_STATUS=END_WORK + ES DEFAULT + Firebase resv 없음 → 퇴근 (정상)

이상 시나리오:
- ES DRIVING + Firebase resv 없음 → Firebase 동기화 누락
- Firebase resv 있음 + ES DEFAULT → ES 동기화 누락
- MySQL STATUS='50' + Firebase resv 있음 → Firebase 해제 지연
```

---

## 4자 비교 패턴

### Firebase ↔ MySQL ↔ ES ↔ Redis (배차 라이프사이클 전체)

> 특정 배차의 전체 데이터 정합성을 4개 소스에서 종합 검증

```
[입력] allocId (또는 driverId로 활성 배차 조회)

1. /lane4-redis →
   - allocations-coordinates:{companyCode}:{allocId} → 좌표 캐시
   - dashboard:{companyCode}:TYPE3 → 대시보드 반영 여부

2. /lane4-firebase →
   - driving/driver_{driverId}/resv → 앱 상태

3. /lane4-es →
   - driver 인덱스 (driverId) → 실시간 상태
   - actual-allocation-path (allocationId) → 실제 경로

4. /lane4-mysql →
   - ALLOCATION (ALLOC_ID) → 마스터 데이터
   - FARE_HISTORY (ALLOCATION_ID) → 요금 데이터
   - DRIVER (DRV_ID) → 기사 마스터

종합 비교 매트릭스:
┌──────────────────┬───────────┬──────────┬──────────┬──────────┐
│       항목        │  MySQL    │  Redis   │    ES    │ Firebase │
├──────────────────┼───────────┼──────────┼──────────┼──────────┤
│ 배차 존재         │ ALLOC_ID  │ coord 키 │ allocId  │ allocId  │
│ 배차 상태         │ STATUS    │    -     │ allocSt  │ status   │
│ 기사 ID          │ DRV_ID    │    -     │ driverId │ driverId │
│ 좌표 데이터       │    -      │ coord값  │ location │    -     │
│ 금액             │ PAY_AMT   │    -     │    -     │    -     │
│ 마지막 업데이트    │ MOD_DT    │ TTL/upd  │ timestamp│ (실시간)  │
└──────────────────┴───────────┴──────────┴──────────┴──────────┘

판정 우선순위:
1. 배차 상태 일치 여부 (MySQL = Source of Truth)
2. 기사 할당 일치 여부
3. 좌표 데이터 일치 여부 (ES = Source of Truth)
4. 캐시 신선도 (Redis TTL + lastUpdatedAt)
5. 앱 상태 동기화 (Firebase vs ES)
```

---

## 비교 불가 조합

아래 조합은 직접 비교할 데이터가 없으므로 간접 비교만 가능:

| 조합 | 이유 | 대안 |
|------|------|------|
| Redis ↔ Firebase (직접) | 공통 키가 거의 없음 | MySQL 또는 ES를 중간 브릿지로 사용 |
| Firebase → 요금 | Firebase에 요금 데이터 없음 | MySQL `FARE` 직접 조회 |
| Redis → 기사 마스터 | Redis에 기사 마스터 없음 | MySQL `DRIVER` 직접 조회 |
