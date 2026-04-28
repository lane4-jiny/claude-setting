# 크로스 레퍼런스 가이드

Redis 캐시 데이터와 다른 데이터 소스 (MySQL, Elasticsearch, Firebase) 간의 연계 조회 방법을 정리한 문서이다.
캐시 불일치 진단, 데이터 검증, 실시간 상태 비교 등에 활용한다.

---

## 1. Redis ↔ MySQL 연계

Redis 캐시의 원본(source of truth)은 대부분 MySQL이다. 캐시와 DB 간 불일치가 의심될 때 아래 매핑을 참조하여 lane4-mysql 스킬과 연계한다.

| Redis 키 패턴 | Redis 키 필드 | MySQL 테이블 | MySQL 키 필드 | 연계 용도 |
|---------------|-------------|-------------|-------------|----------|
| `dashboard:*:TYPE1:*` | companyCode | COMP | COMP_CD | 법인 상세정보 조회 |
| `dashboard:*:TYPE1:*` | whiteListId | WHITE_LIST | WHITE_LIST_ID | 서비스 지역 정보 조회 |
| `fares:*` | companyCode + carModelId | FARE | COMP_CD + CAR_MODEL_ID | 요금 원본 데이터 비교 |
| `allocations-coordinates:*` | allocationId | ALLOCATION | ALLOC_ID | 배차 상세정보 조회 |
| `work-schedules:*` | workScheduleId | DRIVER_SCHEDULE | SCHEDULE_ID | 스케줄 상세정보 조회 |
| `flights:*` | flightNumber | 외부 API (FlightAware) | - | 항공편 원본 (외부) |
| `operational-analytics:*` | companyCode | FARE_HISTORY + ALLOCATION | COMP_CD | 매출 원본 데이터 비교 |

### 연계 조회 시나리오

**캐시 ↔ DB 일치 여부 확인:**
```
1. Redis: hgetall("dashboard:gmcc:TYPE3") → values 파싱 → summary.totalSummary.daily.current
2. MySQL (lane4-mysql): SELECT COUNT(*) FROM ALLOCATION WHERE COMP_CD='gmcc' AND DATE(CREATED_AT)=CURDATE()
3. 두 값 비교 → 차이가 크면 캐시 갱신 지연 가능성
```

**요금 캐시 검증:**
```
1. Redis: scan_all_keys("fares:gmcc:distance:*") → 캐시된 요금 목록
2. MySQL (lane4-mysql): SELECT * FROM FARE WHERE COMP_CD='gmcc' → 원본 요금표
3. 비교하여 누락되거나 다른 요금 식별
```

---

## 2. Redis ↔ Elasticsearch 연계

실시간 데이터와 캐시 데이터를 비교하거나, 캐시된 좌표/경로를 ES의 실제 데이터와 대조할 때 lane4-es 스킬과 연계한다.

| Redis 키 패턴 | ES 인덱스 | 연계 키 | 연계 용도 |
|---------------|----------|--------|----------|
| `allocations-coordinates:*:{allocId}` | `actual-allocation-path` | allocId | 캐시 좌표 vs ES 실제 경로 비교 |
| `allocations-coordinates:*:{allocId}` | `predicated-allocation-path` | allocId | 캐시 좌표 vs ES 예측 경로 비교 |
| `work-schedules:*` | `driver` | driverId | 스케줄 캐시 vs 기사 실시간 상태 |
| `dashboard:*:TYPE3` | `allocation` | companyCode | 대시보드 통계 vs ES 실시간 배차 |

### 연계 조회 시나리오

**배차 경로 캐시 vs 실제 경로 비교:**
```
1. Redis: scan_all_keys("allocations-coordinates:gmcc:12345") → 캐시 좌표
2. ES (lane4-es): actual-allocation-path 인덱스에서 allocId=12345 조회 → 실제 경로
3. 좌표 수, 경로 길이, 마지막 좌표 비교
```

**대시보드 통계 vs 실시간 배차 비교:**
```
1. Redis: hgetall("dashboard:gmcc:TYPE3") → 캐시된 배차 통계
2. ES (lane4-es): allocation 인덱스에서 오늘 배차 집계 → 실시간 수치
3. 차이가 있으면 캐시 갱신 지연 가능성
```

---

## 3. Redis ↔ Firebase 연계

앱 실시간 상태와 캐시 데이터를 비교할 때 lane4-firebase 스킬과 연계한다.

| Redis 키 패턴 | Firebase 경로 | 연계 키 | 연계 용도 |
|---------------|-------------|--------|----------|
| `dashboard:*:TYPE1:*:{userId}:*` | `/{env}/calling/user_{userId}` | userId | 대시보드 캐시 사용자 vs RTDB 콜 상태 |
| `allocations-coordinates:*:{allocId}` | `/{env}/driving/driver_{driverId}/resv` | allocId ↔ driverId | 배차 좌표 캐시 vs RTDB 운행 상태 |

### 연계 조회 시나리오

**사용자 대시보드 캐시 vs RTDB 콜 상태:**
```
1. Redis: hgetall("dashboard:gmcc:TYPE1:327:user123:Y") → 사용자 배차현황 캐시
2. Firebase (lane4-firebase): /{env}/calling/user_user123 → 실시간 콜 상태
3. 캐시 데이터의 배차 상태와 RTDB의 콜 상태 일치 여부 확인
```

---

## 4. 연계 조회 의사결정 가이드

어떤 스킬과 연계해야 할지 판단하는 기준:

| 상황 | 연계 대상 | 이유 |
|------|----------|------|
| "캐시와 실제 데이터가 다르다" | lane4-mysql | MySQL이 원본이므로 원본 대비 검증 |
| "대시보드 수치가 이상하다" | lane4-mysql 또는 lane4-es | 원본 집계와 비교 |
| "배차 경로가 캐시와 다르다" | lane4-es | ES에 실제/예측 경로가 저장됨 |
| "실시간 상태와 캐시가 안 맞다" | lane4-es 또는 lane4-firebase | 실시간 데이터는 ES/Firebase |
| "앱에서 보이는 것과 캐시가 다르다" | lane4-firebase | 앱은 Firebase RTDB 참조 |
| "요금이 잘못 적용됐다" | lane4-mysql | 요금 원본은 MySQL FARE 테이블 |
| "기사 스케줄 상태 불일치" | lane4-es | 기사 실시간 상태는 ES driver 인덱스 |

---

## 5. 멀티 스킬 연계 워크플로우 예시

### 예시: "대시보드 캐시 데이터가 이상해요" (종합 진단)

```
Step 1 (lane4-redis):
  - hgetall("dashboard:gmcc:TYPE3") → 캐시 데이터 확인
  - lastUpdatedAt 확인 → 갱신 시점 파악
  - values 파싱 → 현재 통계 수치 추출

Step 2 (lane4-mysql):
  - 오늘 배차 수 집계: SELECT COUNT(*) FROM ALLOCATION WHERE ...
  - 캐시 수치와 DB 수치 비교

Step 3 (lane4-es):
  - allocation 인덱스에서 실시간 배차 수 조회
  - 실시간 수치와 캐시/DB 수치 3자 비교

Step 4 (결과 종합):
  - 캐시 ↔ DB ↔ ES 수치 비교표 제공
  - 불일치 원인 추정 및 해결 방안 안내
```

### 예시: "특정 배차의 좌표가 안 보여요" (경로 추적)

```
Step 1 (lane4-redis):
  - scan_all_keys("allocations-coordinates:*:{allocId}") → 캐시 존재 여부 확인
  - 키가 없으면 TTL 만료 가능성 안내 (7일)

Step 2 (lane4-mysql):
  - ALLOCATION 테이블에서 해당 배차 정보 확인 → 배차가 유효한지 확인

Step 3 (lane4-es):
  - actual-allocation-path에서 실제 경로 조회 → 원본 좌표 확인

Step 4 (결과 종합):
  - 캐시 만료 여부, 원본 데이터 존재 여부, 실제 경로 존재 여부를 종합 보고
```
