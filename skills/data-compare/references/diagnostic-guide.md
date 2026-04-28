# 불일치 원인 진단 의사결정 트리

## 동기화 파이프라인 참조

데이터 흐름을 이해해야 불일치 원인을 정확히 진단할 수 있다:

```
                    ┌──────────┐
                    │  MySQL   │ (원본 마스터)
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │  Kafka   │ topic: local.monitoring.sync.elastic-search
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              │          │          │
         ┌────▼───┐ ┌───▼────┐ ┌──▼───────┐
         │  ES    │ │ Redis  │ │ Firebase │
         └────────┘ └────────┘ └──────────┘

동기화 주체:
- MySQL → ES:      lane4-monitoring-api (Kafka consumer → IndexDocumentService)
- MySQL → Redis:   lane4-admin-api / lane4-app-api (비즈니스 로직 내 캐시 갱신)
- MySQL → Firebase: lane4-driver-api / lane4-monitoring-api (CustomFirebase)
```

**핵심 포인트:**
- ES는 Kafka 통해 비동기 동기화 → Kafka lag이 불일치 원인일 수 있음
- Redis는 비즈니스 로직에서 직접 갱신 → 코드 경로 누락이 원인일 수 있음
- Firebase는 API 서버에서 직접 갱신 → 서버 에러가 원인일 수 있음

---

## 마스터 의사결정 트리

```
불일치 발견
│
├─ 어떤 도메인인가?
│  │
│  ├─ 대시보드 (배차 건수/통계) ─────→ [대시보드 진단 트리]
│  ├─ 위치/경로 (좌표, GPS) ─────────→ [위치/경로 진단 트리]
│  ├─ 요금 (금액, 할인) ────────────→ [요금 진단 트리]
│  ├─ 기사 상태 (근무, 운행) ────────→ [기사 상태 진단 트리]
│  ├─ 배차 상태 (진행, 완료, 취소) ──→ [배차 상태 진단 트리]
│  └─ 앱 상태 (점검, 버전, 콜) ─────→ [앱 상태 진단 트리]
```

---

## 도메인별 진단 트리

### 대시보드 진단 트리

```
Redis dashboard ≠ MySQL 집계
│
├─ Redis lastUpdatedAt 확인
│  │
│  ├─ 1시간 이상 경과
│  │  → 원인: 캐시 갱신 스케줄러 중단
│  │  → 확인: lane4-admin-api 스케줄러 로그
│  │  → 조치 제안: 스케줄러 재시작 또는 수동 캐시 갱신 API 호출
│  │
│  └─ 1시간 이내
│     │
│     ├─ 차이가 소수 건 (1~5건)
│     │  → 원인: 갱신 시점 차이 (정상 범위)
│     │  → 조치: 다음 갱신 주기까지 대기
│     │
│     └─ 차이가 대량 (10건 이상)
│        → 원인: 캐시 갱신 로직 버그 또는 집계 쿼리 불일치
│        → 확인: operational.analytics.service.ts 집계 로직 리뷰
│        → 확인: STATUS 필터 조건이 MySQL 쿼리와 일치하는지
```

### 위치/경로 진단 트리

```
Redis coordinates ≠ ES actual-allocation-path
│
├─ Redis TTL 확인
│  │
│  ├─ TTL = -2 (만료)
│  │  → 원인: 7일 경과로 자동 만료
│  │  → 판정: ES가 Source of Truth. Redis 데이터 없는 것은 정상.
│  │
│  └─ TTL > 0 (유효)
│     │
│     ├─ Redis 타임스탬프 vs ES 최신 timestamp 비교
│     │  │
│     │  ├─ 수 분 차이
│     │  │  → 원인: 캐시 갱신 지연 (정상 범위)
│     │  │
│     │  └─ 수 시간 이상 차이
│     │     → 원인: redis.allocation.service.ts 갱신 중단
│     │     → 확인: 해당 배차 상태가 아직 활성인지 MySQL에서 확인
│     │
│     └─ 좌표값 자체가 다름 (같은 시점인데)
│        → 원인: 좌표 변환 또는 반올림 차이
│        → 확인: 소수점 자릿수 비교 (ES float vs Redis string 변환)
```

### 요금 진단 트리

```
Redis fares ≠ MySQL FARE
│
├─ Redis TTL 확인
│  │
│  ├─ TTL = -1 (영구)
│  │  │
│  │  ├─ MySQL FARE.MODIFIED_AT > Redis 캐시 시점
│  │  │  → 원인: 요금 변경 후 캐시 미갱신
│  │  │  → 확인: find.fare.redis.service.ts 캐시 무효화 로직
│  │  │  → 조치 제안: 요금 재저장으로 캐시 갱신 트리거
│  │  │
│  │  └─ MySQL FARE.MODIFIED_AT ≤ Redis 캐시 시점
│  │     → 원인: 캐시 생성 후 MySQL 데이터가 변경되지 않음
│  │     → 판정: 다른 조건(거리 범위, 차량 모델)으로 잘못 비교한 것은 아닌지 확인
│  │
│  └─ TTL = -2 (만료)
│     → 판정: 캐시 없음. MySQL이 유일한 Source of Truth.
```

### 기사 상태 진단 트리

```
MySQL DRIVER ≠ ES driver ≠ Firebase driving
│
├─ MySQL vs ES 불일치
│  │
│  ├─ MySQL WORK_STATUS=CALL_COMMUTE, ES drivingStatus=DRIVING
│  │  → 판정: 정상. 출근 중 운행 시작한 상태.
│  │  → MySQL WORK_STATUS는 운행 시작으로 바뀌지 않음 (설계상 정상).
│  │
│  ├─ MySQL WORK_STATUS=END_WORK, ES drivingStatus=DRIVING
│  │  → 원인: MySQL 퇴근 처리 후 ES 미반영
│  │  → 확인: Kafka consumer 정상 동작 여부
│  │  → 확인: lane4-monitoring-api 로그
│  │
│  └─ MySQL에 활성 배차 없음, ES allocationId 있음
│     → 원인: MySQL 배차 완료/취소 후 ES driver 인덱스 미갱신
│     → 확인: SyncElasticSearchService 동기화 이벤트 발행 여부
│
├─ ES vs Firebase 불일치
│  │
│  ├─ ES allocationId 있음, Firebase resv 없음
│  │  → 원인: Firebase RTDB 동기화 누락
│  │  → 확인: lane4-driver-api CustomFirebase 로직
│  │
│  ├─ ES allocationId 없음, Firebase resv 있음
│  │  → 원인: 배차 완료 후 Firebase 노드 미삭제
│  │  → 확인: lane4-monitoring-api 상태 변경 → Firebase 업데이트 로직
│  │
│  └─ 둘 다 있지만 allocId 다름
│     → 원인: 배차 변경 시 한쪽만 업데이트
│     → MySQL ALLOCATION 기준으로 정답 판별
│
└─ MySQL vs Firebase 불일치
   │
   ├─ MySQL STATUS='50' (완료), Firebase resv 있음
   │  → 원인: 운행 완료 처리 후 Firebase 노드 미삭제 (가장 빈번)
   │  → 확인: lane4-driver-api의 배차 완료 시 Firebase 업데이트 호출 여부
   │
   └─ MySQL 활성 배차 있음, Firebase resv 없음
      → 원인: Firebase RTDB 쓰기 실패
      → 확인: lane4-driver-api 에러 로그
```

### 배차 상태 진단 트리

```
배차 상태가 소스 간 불일치
│
├─ MySQL STATUS 확인 (Source of Truth)
│  │
│  ├─ STATUS = '50' (완료)
│  │  │
│  │  ├─ ES driver.allocationId 아직 있음
│  │  │  → 원인: ES 동기화 지연
│  │  │  → 확인: Kafka topic lag 확인
│  │  │  → 일반적으로 수 초~수 분 내 자동 해소
│  │  │
│  │  ├─ Firebase resv 아직 있음
│  │  │  → 원인: Firebase 해제 지연 (빈번한 이슈)
│  │  │  → 확인: lane4-driver-api / lane4-monitoring-api 로그
│  │  │
│  │  └─ Redis coordinates 아직 있음
│  │     → 판정: 정상. Redis TTL=7일이므로 완료 후에도 유지됨.
│  │
│  ├─ STATUS = '55' (취소) 또는 '50N' (미탑승)
│  │  │
│  │  ├─ ES/Firebase에 아직 활성으로 남아있음
│  │  │  → 원인: 취소/미탑승 처리 시 동기화 누락
│  │  │  → 확인: 취소 로직의 Kafka 이벤트 발행 + Firebase 업데이트 코드
│  │  │
│  │  └─ ES/Firebase 정상 해제
│  │     → 판정: 정상
│  │
│  └─ STATUS IN ('정상','10','20','30') (활성)
│     │
│     ├─ ES/Firebase 모두 반영됨
│     │  → 판정: 정상
│     │
│     └─ ES 또는 Firebase 미반영
│        → 원인: 상태 전이 시 동기화 실패
│        → 확인: 해당 상태 전이 API의 에러 로그
```

### 앱 상태 진단 트리

```
앱 관련 불일치
│
├─ Driver ↔ User 점검 모드 불일치
│  │
│  ├─ Driver active=true, User active=false (또는 반대)
│  │  → 원인: 점검 모드 토글 시 한 프로젝트만 업데이트
│  │  → 확인: lane4-admin-api CustomFirebase 로직 (양쪽 동시 업데이트 여부)
│  │  → 참고: 점검 모드는 Driver/User 양쪽 동시 변경이 원칙
│  │
│  └─ 둘 다 일치
│     → 판정: 정상
│
├─ Firebase calling ≠ MySQL 활성 배차
│  │
│  ├─ Firebase에 calling 있는데 MySQL 활성 배차 없음
│  │  → 원인: 콜 요청 후 취소/완료됐지만 Firebase calling 미삭제
│  │  → 확인: 콜 취소/배차 완료 시 Firebase calling 노드 삭제 로직
│  │
│  └─ MySQL 활성 배차 있는데 Firebase calling 없음
│     → 가능성 1: 콜 단계가 지나 driving으로 이동 (정상)
│     → 가능성 2: Firebase 쓰기 실패
│     → 확인: driving/driver_{driverId}/resv 존재 여부로 구분
```

---

## 공통 원인 체크리스트

불일치 발견 시 아래 항목을 순서대로 확인한다:

### 1. 타임스탬프 확인

| 소스 | 타임스탬프 필드 | 확인 방법 |
|------|--------------|----------|
| MySQL | `REG_DT`, `MOD_DT` | 마지막 수정 시각 |
| Redis | `lastUpdatedAt` (hash 내) | 캐시 갱신 시각 |
| Redis | TTL | `type` 도구로 TTL 확인 |
| ES | `timestamp` (각 인덱스) | 마지막 인덱싱 시각 |
| Firebase | (실시간 — 별도 타임스탬프 없음) | 조회 시점이 현재 상태 |

### 2. 동기화 지연 vs 동기화 실패 판별

```
마지막 동기화 시각 확인
│
├─ 시각이 있고, 최근 (수 분 이내)
│  → 동기화 정상 동작 중, 데이터 변경 직후 조회한 것
│  → 조치: 잠시 후 재확인
│
├─ 시각이 있고, 오래됨 (수 시간 이상)
│  → 동기화 스케줄러/파이프라인 중단 가능성
│  → 조치: 파이프라인 상태 점검 (Kafka lag, 서버 로그)
│
└─ 시각이 없거나 확인 불가
   → 캐시가 한번도 갱신되지 않았거나, 다른 경로로 생성된 데이터
   → 조치: 소스 코드에서 캐시 생성 로직 확인
```

### 3. 파이프라인별 점검 포인트

| 파이프라인 | 점검 포인트 | 관련 서비스 |
|-----------|-----------|-----------|
| MySQL → ES | Kafka topic lag, consumer 상태 | lane4-monitoring-api |
| MySQL → Redis | 캐시 갱신 API 호출 로그 | lane4-admin-api, lane4-app-api |
| MySQL → Firebase | RTDB 쓰기 에러 로그 | lane4-driver-api, lane4-monitoring-api |
| ES ← 인덱싱 | IndexDocumentService 로그 | lane4-monitoring-api |
| Redis ← 갱신 | redis.cache.service.ts 로그 | 각 도메인 서비스 |
| Firebase ← 갱신 | CustomFirebase 에러 로그 | lane4-admin-api, lane4-driver-api |

### 4. 빈번한 불일치 패턴 (경험 기반)

| 패턴 | 빈도 | 원인 | 자동 해소 |
|------|------|------|----------|
| 운행 완료 후 Firebase resv 잔존 | 높음 | Firebase 삭제 누락 | 안 됨 |
| 대시보드 수치 소폭 차이 | 높음 | 갱신 주기 차이 | 1시간 내 |
| ES driver 상태 지연 | 중간 | Kafka consumer lag | 수 분 내 |
| 요금 캐시 불일치 | 낮음 | 요금 변경 후 캐시 미갱신 | 안 됨 |
| Redis 좌표 ≠ ES 좌표 | 낮음 | 캐시 갱신 지연 | 운행 중 수 분 내 |
