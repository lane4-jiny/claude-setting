# 크로스 소스 필드 매핑표

## 엔티티 ID 매핑

### 배차 ID (Allocation ID)

| 소스 | 위치 | 필드명 | 타입 |
|------|------|--------|------|
| MySQL | `ALLOCATION` | `ALLOC_ID` | int |
| MySQL | `FARE_HISTORY` | `ALLOCATION_ID` (⚠️ 이름 다름) | bigint |
| MySQL | `PAY_TRX` | `ALLOC_ID` | int |
| Redis | `allocations-coordinates:{companyCode}:{allocId}` | 키 내 `allocId` | string |
| ES | `actual-allocation-path` | `allocationId` | long |
| ES | `predicated-allocation-path` | `allocationId` | integer |
| ES | `allocation` | (인덱스 자체가 배차 단위) | - |
| ES | `car-history_*` | `allocationId` | integer |
| Firebase | `calling/user_{userId}/allocId_{allocId}` | 경로 내 `allocId` | string |
| Firebase | `driving/driver_{driverId}/resv` | `allocId` | number |

### 기사 ID (Driver ID)

| 소스 | 위치 | 필드명 | 타입 |
|------|------|--------|------|
| MySQL | `DRIVER` | `DRV_ID` | int |
| MySQL | `ALLOCATION` | `DRV_ID` | int |
| MySQL | `DRIVER_SCHEDULE` | `DRV_ID` | int |
| ES | `driver` | `id` | keyword |
| ES | `allocation_location` | `driver_id` (⚠️ 언더스코어) | keyword |
| ES | `allocation` | `driverId` (⚠️ camelCase) | keyword |
| ES | `driver-location_*` | `id` | integer |
| Firebase | `driving/driver_{driverId}` | 경로 내 `driverId` | string |

> ⚠️ ES 내에서도 인덱스마다 기사 ID 필드명이 다름: `id`, `driver_id`, `driverId`

### 사용자 ID (User ID)

| 소스 | 위치 | 필드명 | 타입 |
|------|------|--------|------|
| MySQL | `SVC_USER` | `USER_ID` | int |
| MySQL | `CALL_REQ` | `USER_ID` | int |
| Redis | `dashboard:*:TYPE1:*:{userId}:*` | 키 내 `userId` | string |
| ES | `destinations` | `userId` | keyword |
| Firebase | `calling/user_{userId}` | 경로 내 `userId` | string |

### 법인 코드 (Company Code)

| 소스 | 위치 | 필드명 | 타입 | 값 예시 |
|------|------|--------|------|---------|
| MySQL | `COMP` | `COMP_CD` | varchar | `gmcc`, `lane4` |
| MySQL | `EMPLOYEE` | `company_code` (⚠️ lower_snake) | varchar | |
| MySQL | `FARE` | `COMPANY_CODE` (⚠️ UPPER) | varchar | |
| MySQL | `FARE_HISTORY` | `COMPANY_CODE` | varchar | |
| Redis | 키 prefix | `{companyCode}` | string | `gmcc`, `lane4`, `emirates`, `ke` |
| ES | `driver` | `companyCode` | keyword | |
| ES | `car-history_*` | `carCompanyCode`, `allocationCompanyCode` | keyword | |
| Firebase | - | (직접 저장 안 됨) | - | - |

> 주요 법인 코드: `gmcc` (GMCC), `lane4` (Lane4), `emirates` (에미레이츠), `ke` (대한항공)

### 차량 ID (Car ID)

| 소스 | 위치 | 필드명 | 타입 |
|------|------|--------|------|
| MySQL | `CAR` | `CAR_ID` | int |
| MySQL | `ALLOCATION` | `CAR_ID` | int |
| ES | `driver` | `carId` | integer |
| ES | `car-history_*` | `carId` | integer |
| Redis | - | (직접 캐싱 안 됨) | - |
| Firebase | - | (저장 안 됨) | - |

## 상태값 매핑

### 배차 상태 (Allocation Status)

| 의미 | MySQL `ALLOCATION.STATUS` | ES `driver.allocationStatus` | Firebase `resv.status` |
|------|--------------------------|------------------------------|----------------------|
| 결제 전 | `00` | - | - |
| 정상/확정 | `정상` | (배차 할당 상태) | - |
| 기사 출발 | `10` | `10` | `10` |
| 출발지 도착 | `20` | `20` | `20` |
| 고객 탑승 | `30` | `30` | `30` |
| 결제 성공 | `40S` | `40S` | `40S` |
| 운행 완료 | `50` | - (배차 해제) | - (노드 삭제) |
| 고객 취소 | `55` | - | - |
| 미탑승 | `50N` | - | - |
| 삭제 | `삭제` | - | - |

> **핵심 차이:** MySQL은 전체 라이프사이클 보존, ES/Firebase는 활성 배차만 유지.
> 운행 완료(`50`) 이후 ES `driver` 인덱스에서 `allocationId`가 null로 변경되고, Firebase `resv` 노드는 삭제됨.

### 기사 근무 상태 (Driver Work Status)

| 의미 | MySQL `DRIVER.WORK_STATUS` | ES `driver.drivingStatus` |
|------|---------------------------|--------------------------|
| 인수 전 | `TAKEOVER_BEFORE` | `DEFAULT` |
| 근무 시작 | `BEGIN_WORK` | (해당 없음) |
| 콜 대기 | `CALL_COMMUTE` | `DEFAULT` |
| 콜 중지 | `CALL_STOP` | `DEFAULT` |
| 운행 중 | - | `DRIVING` |
| 근무 종료 | `END_WORK` | `DEFAULT` |
| 인수 후 | `TAKEOVER_AFTER` | (해당 없음) |

> **핵심 차이:** MySQL `WORK_STATUS`는 근무 라이프사이클, ES `drivingStatus`는 실시간 운행 여부.
> 둘은 1:1 대응이 아니며, MySQL이 출근(`CALL_COMMUTE`)인데 ES가 `DRIVING`이면 정상(운행 중).

### 기사 출퇴근 상태

| 의미 | MySQL `DRIVER.COMMUTE_STATUS` | MySQL `DRIVER.CALL_STATUS` |
|------|------------------------------|---------------------------|
| 출근 + 콜 수신 | `Y` | `Y` |
| 출근 + 콜 미수신 | `Y` | `N` |
| 퇴근 | `N` | `N` |

## 데이터 도메인별 소스 매핑

### 대시보드 데이터

| 데이터 항목 | Redis | MySQL | ES |
|------------|-------|-------|-----|
| 일별/주별/월별 배차 건수 | `dashboard:{cc}:TYPE3` → `summary` | `ALLOCATION` 집계 | `allocation` 집계 |
| 시간대별 배차 현황 | `dashboard:{cc}:TYPE3` → `charts.hourly` | `ALLOCATION` 시간대 집계 | - |
| 사용자별 대시보드 | `dashboard:{cc}:TYPE1:{wl}:{uid}:{isApp}` | `ALLOCATION` + `WHITE_LIST` 필터 | - |
| 배차 완료/취소/미탑승 분류 | TYPE3 → `charts.daily` 내 분류 | `ALLOCATION.STATUS` 그룹 집계 | - |

### 요금 데이터

| 데이터 항목 | Redis | MySQL |
|------------|-------|-------|
| 거리 기반 요금 | `fares:{cc}:distance:{s}:{e}:{cmid}` | `FARE` (COMPANY_CODE + CAR_MODEL_ID) |
| 공유 요금 | `fares:{cc}:distance:{s}:{e}:{cmid}:shared` | `FARE` (CAR_TYPE 조건 추가) |

### 좌표/경로 데이터

| 데이터 항목 | Redis | ES |
|------------|-------|-----|
| 배차 좌표 캐시 | `allocations-coordinates:{cc}:{allocId}` | `actual-allocation-path` (allocationId) |
| 예측 경로 | - | `predicated-allocation-path` (allocationId) |
| 기사 실시간 위치 | - | `driver-location_{date}` (id) |

### 기사/배차 실시간 상태

| 데이터 항목 | MySQL | ES | Firebase |
|------------|-------|-----|----------|
| 기사 운행 상태 | `DRIVER.WORK_STATUS` | `driver.drivingStatus` | `driving/driver_{id}/resv/status` |
| 현재 배차 ID | `ALLOCATION` (STATUS 필터) | `driver.allocationId` | `driving/driver_{id}/resv/allocId` |
| 콜 요청 상태 | `CALL_REQ` | `allocation` | `calling/user_{userId}/allocId_{id}` |

### 매출 데이터

| 데이터 항목 | Redis | MySQL |
|------------|-------|-------|
| 법인별 매출 요약 | `operational-analytics:{cc}:revenue` | `FARE_HISTORY` 집계 (COMPANY_CODE) |

## 캐시 신선도 기준

| Redis 키 패턴 | 갱신 주기 | TTL | 정상 범위 | 비고 |
|---------------|----------|-----|----------|------|
| `dashboard:*:TYPE3` | ~1시간 | 10368000s (~4개월) | `lastUpdatedAt` 1시간 이내 | 회사 전체 대시보드 |
| `dashboard:*:TYPE1:*` | 사용자 요청 시 | -1 (영구) | 확인 불가 (갱신 시각 없는 경우 있음) | 개인별 대시보드 |
| `operational-analytics:*:revenue` | ~1시간 | 10368000s | `lastUpdatedAt` 1시간 이내 | 매출 통계 |
| `fares:*` | 요금 변경 시 | -1 (영구) | TTL=-1이면 수동 확인 필요 | 요금 캐시 |
| `allocations-coordinates:*` | 운행 중 실시간 | 604800s (7일) | 운행 중: 수 분 이내 | 좌표 캐시 |
| `work-schedules:*` | 스케줄 변경 시 | 다양 | - | 근무 스케줄 |
| `flights:*` | 항공편 업데이트 시 | 다양 | - | 항공편 정보 |
| `currency:*` | 환율 변동 시 | 다양 | - | 환율 정보 |

### 신선도 판단 로직

```
if TTL == -2:
    → 🔴 만료됨 (expired)
elif TTL == -1:
    → lastUpdatedAt 필드 확인
        → 있으면: 갱신 주기와 비교
        → 없으면: 🟡 확인 필요 (수동 검증)
elif TTL > 0:
    → lastUpdatedAt + 갱신 주기 비교
        → 주기 내: 🟢 정상
        → 주기 초과: 🔴 갱신 지연
```
