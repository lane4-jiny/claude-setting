# lane4-es 크로스 레퍼런스 가이드

MySQL ↔ ES 간 데이터 연계, 그리고 다른 lane4 스킬과의 연계 조회 방법.

## 목차

1. [MySQL ↔ ES 키 필드 매핑](#1-mysql--es-키-필드-매핑)
2. [연계 조회 패턴](#2-연계-조회-패턴)
3. [Redis ↔ ES 연계](#3-redis--es-연계)
4. [Firebase ↔ ES 연계](#4-firebase--es-연계)
5. [이슈 디버깅 연계](#5-이슈-디버깅-연계)

---

## 1. MySQL ↔ ES 키 필드 매핑

ES 데이터를 MySQL 마스터 데이터와 조인할 때 사용하는 키 필드 대응표.

| ES 인덱스 | ES 키 필드 | MySQL 테이블 | MySQL 키 필드 | 연계 용도 |
|-----------|-----------|-------------|-------------|----------|
| `allocation` | `driverId` | `DRIVER` | `DRV_ID` | 기사 상세정보 (이름, 소속 등) |
| `actual-allocation-path` | `allocationId` | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 (고객, 요금, 일정 등) |
| `predicated-allocation-path` | `allocationId` | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 |
| `allocation_location` | `driver_id` | `DRIVER` | `DRV_ID` | 기사 상세정보 |
| `driver` | `id` | `DRIVER` | `DRV_ID` | 기사 마스터 데이터 |
| `driver-location_*` | `id` | `DRIVER` | `DRV_ID` | 기사 상세정보 |
| `car-history_*` | `carId` | `CAR` | `CAR_ID` | 차량 상세정보 (모델, 소유 등) |
| `car-history_*` | `allocationId` | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 |
| `allocation-status-update-reminder-history` | `allocationId` | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 |
| `allocation-status-update-reminder-history` | `driverId` | `DRIVER` | `DRV_ID` | 기사 상세정보 |

### 주의사항: 필드명 불일치

ES와 MySQL 간 같은 개념이지만 필드명이 다른 경우가 있다:

| 개념 | ES 필드명 (인덱스별 다름) | MySQL 필드명 |
|------|------------------------|-------------|
| 기사 ID | `driverId`, `driver_id`, `id` | `DRV_ID` |
| 배차 ID | `allocationId` | `ALLOC_ID` |
| 차량 ID | `carId` | `CAR_ID` |
| 법인코드 | `companyCode`, `carCompanyCode`, `allocationCompanyCode` | `COMP_CD` |

---

## 2. 연계 조회 패턴

### 패턴 A: ES에서 ID 조회 → MySQL에서 상세정보 보완

가장 일반적인 연계 패턴. ES에서 실시간/위치 데이터를 먼저 조회한 뒤, 얻은 ID로 MySQL 마스터 데이터를 보완한다.

**예시: "현재 운행 중인 기사들의 상세 정보"**

1. ES `driver` 인덱스에서 `drivingStatus == "DRIVING"` 기사 목록 조회 → `id` 목록 획득
2. MySQL `DRIVER` 테이블에서 해당 `DRV_ID` 목록으로 상세정보 (소속, 계약 등) 조회
3. 두 결과를 기사 ID 기준으로 합산하여 응답

### 패턴 B: MySQL에서 조건 조회 → ES에서 실시간 데이터 보완

MySQL에서 먼저 조건을 만족하는 엔티티를 찾고, 해당 ID로 ES 실시간 데이터를 조회한다.

**예시: "GMCC 소속 프리미엄 기사들의 현재 위치"**

1. MySQL `DRIVER` 테이블에서 `COMP_CD = 'gmcc' AND CAR_GRADE = 'PREMIUM'` 기사 ID 목록 조회
2. ES `driver-location_오늘날짜`에서 해당 기사 ID 목록으로 현재 위치 조회
3. 합산하여 응답

### 패턴 C: ES 배차 경로 + MySQL 배차 상세 결합

**예시: "배차 12345의 경로와 고객 정보"**

1. ES `actual-allocation-path`에서 `allocationId: 12345`로 경로 좌표 조회
2. MySQL `ALLOCATION` 테이블에서 `ALLOC_ID = 12345`로 고객명, 출발지, 도착지, 요금 등 조회
3. 경로 + 상세정보 합산하여 응답

---

## 3. Redis ↔ ES 연계

`lane4-redis` 스킬과의 연계 시나리오.

### 배차 좌표 캐시 vs ES 실제 경로 비교

Redis의 `allocations-coordinates:{allocationId}` 키에는 배차의 현재/최근 좌표가 캐시되어 있다.
ES의 `actual-allocation-path`에는 전체 이동 경로가 시계열로 저장되어 있다.

**비교 흐름:**

1. `lane4-redis` 스킬로 `allocations-coordinates:{allocationId}` 조회 → 캐시된 좌표 획득
2. `lane4-es` 스킬로 `actual-allocation-path`에서 동일 `allocationId`의 최근 좌표 조회
3. 두 좌표의 일치 여부/시간 차이 비교 → 캐시 정합성 판단

### 활용 시나리오

- "관제 화면에 표시되는 위치가 실제와 다릅니다" → 캐시 vs ES 데이터 비교
- "배차 좌표 업데이트가 지연됩니다" → Redis 캐시 갱신 시각 vs ES 최신 timestamp 비교

---

## 4. Firebase ↔ ES 연계

`lane4-firebase` 스킬과의 연계 시나리오.

### 운행 상태 교차 확인

Firebase RTDB에는 기사의 실시간 운행 상태가 저장된다.
ES `driver` 인덱스에도 기사의 `drivingStatus`가 있다.

**교차 확인 흐름:**

1. `lane4-firebase` 스킬로 Firebase RTDB에서 기사의 운행 상태 조회
2. `lane4-es` 스킬로 ES `driver` 인덱스에서 동일 기사의 `drivingStatus` 조회
3. 두 상태가 일치하는지 확인 → 불일치 시 동기화 이슈 가능

### 활용 시나리오

- "기사 앱에서는 운행 중인데 관제 화면에는 대기로 보입니다" → Firebase vs ES 상태 비교
- "기사 상태 변경이 반영되지 않습니다" → 두 소스의 상태 및 타임스탬프 비교

---

## 5. 이슈 디버깅 연계

`lane4-issue` 스킬과 연계하여 운영 이슈를 디버깅하는 패턴.

### "관제에서 위치가 안 보여요"

1. ES `driver-location_오늘날짜`에서 해당 기사 ID로 최근 데이터 존재 확인
2. 데이터가 없으면 → 기사 앱의 GPS 전송 문제 또는 Kafka/인덱싱 파이프라인 장애 의심
3. 데이터가 있으면 → `timestamp` 확인하여 마지막 수집 시각 점검. 지연이 있다면 모니터링 API 쪽 조회

### "기사 경로가 이상해요"

1. ES `actual-allocation-path`에서 해당 배차의 실제 경로 좌표 조회
2. ES `predicated-allocation-path`에서 동일 배차의 예측 경로 좌표 조회
3. 두 경로를 좌표 시퀀스로 대조 → 이탈 구간 식별
4. 필요 시 MySQL `ALLOCATION` 테이블에서 배차 상세(출발지, 도착지) 확인

### "배차 상태가 안 바뀌어요"

1. ES `allocation-status-update-reminder-history`에서 해당 배차의 리마인드 이력 조회
2. `currentStatus`와 `requestedStatus` 비교 → 상태 전환 요청이 발생했는지 확인
3. 리마인드가 반복적으로 발생하면 → 기사 앱에서 상태 전환을 누르지 않았을 가능성
4. 필요 시 MySQL에서 배차 상태 변경 이력 추가 확인

### "셔틀이 정류장에 도착했는데 상태가 안 바뀌어요"

1. ES `shuttle-status-history_오늘날짜`에서 해당 셔틀 노선의 최근 이력 조회
2. `sequence`(정류장 순서)와 `shuttleStatus` 확인
3. 기대 정류장에서의 상태 변경 기록이 없으면 → GPS 정확도 또는 지오펜스 범위 문제 의심
