# lane4-es 인덱스 스키마 상세

모든 비즈니스 인덱스의 필드 매핑 정보.

## 목차

1. [배차 도메인](#1-배차-도메인)
   - [allocation](#allocation)
   - [allocation_location](#allocation_location)
   - [actual-allocation-path](#actual-allocation-path)
   - [predicated-allocation-path](#predicated-allocation-path)
   - [allocation-status-update-reminder-history](#allocation-status-update-reminder-history)
2. [기사/차량 도메인](#2-기사차량-도메인)
   - [driver](#driver)
   - [driver-location_{YYYY-MM-DD}](#driver-location_yyyy-mm-dd)
   - [driver_connect_clients](#driver_connect_clients)
   - [car-history_{YYYY-MM-DD}](#car-history_yyyy-mm-dd)
3. [셔틀 도메인](#3-셔틀-도메인)
   - [shuttle-status-history_{YYYY-MM-DD}](#shuttle-status-history_yyyy-mm-dd)
4. [지역/목적지 도메인](#4-지역목적지-도메인)
   - [region](#region)
   - [destinations](#destinations)

---

## 1. 배차 도메인

### allocation

배차-기사-위치 매핑. 실시간 배차 상태의 지도 표시용. (94,332건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `allocationLocationId` | keyword | `allocation_location` 인덱스 연결 키 |
| `driverId` | keyword | 기사 ID |
| `tmapCoordinates` | geo_point | TMap 기반 좌표 |

---

### allocation_location

배차별 GPS 궤적. 기사의 이동 경로를 시계열로 저장. (18,586,258건)

⚠️ **대용량** — `driver_id` + 시간 범위 + `size ≤ 100` 필수.

| 필드 | 타입 | 설명 |
|------|------|------|
| `driver_id` | keyword | 기사 ID |
| `timestamp` | date (`yyyy-MM-dd HH:mm:ss`) | 기록 시각 |
| `coordinates` | nested | 좌표 배열 |
| `coordinates.coordinate` | geo_point | GPS 좌표 |
| `coordinates.timestamp` | text (.keyword) | 개별 좌표 시각 |

주의: `coordinates`가 nested 타입이므로 Query DSL의 `nested` 쿼리를 사용해야 한다.

---

### actual-allocation-path

배차의 **실제 이동 경로** 포인트. 가장 대용량 인덱스. (139,148,030건)

⚠️ **최대 대용량** — `allocationId` + 시간 범위 + `size ≤ 100` **반드시** 필수.

| 필드 | 타입 | 설명 |
|------|------|------|
| `allocationId` | long | 배차 ID |
| `location` | float | GPS 좌표 |
| `timestamp` | date | 기록 시각 |

---

### predicated-allocation-path

배차의 **예측 경로**. 실제 경로(`actual-allocation-path`)와 비교 분석에 사용. (234,640건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `allocationId` | integer | 배차 ID |
| `locations` | geo_point | 예측 경로 좌표 |
| `timestamp` | date | 기록 시각 |

---

### allocation-status-update-reminder-history

기사에게 배차 상태 업데이트를 리마인드한 이력. (35,738건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `allocationId` | long | 배차 ID |
| `driverId` | long | 기사 ID |
| `currentStatus` | text (.keyword) | 현재 상태 |
| `requestedStatus` | text (.keyword) | 요청된 상태 |
| `location` | float | 위치 |
| `distance` | float | 거리 |
| `createdAt` | date | 생성 시각 |

---

## 2. 기사/차량 도메인

### driver

기사 실시간 상태. 현재 배차, 차량, 운행 상태 포함. (270건) — 소규모, 전체 스캔 가능.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | keyword | 기사 ID |
| `name` | text | 기사명 |
| `telephone` | keyword | 연락처 |
| `carId` | integer | 차량 ID |
| `carNumber` | text | 차량 번호 |
| `carGrade` | keyword | 차량 등급 (PREMIUM, EXCLUSIVE 등) |
| `companyCode` | keyword | 소속 법인코드 |
| `companyName` | text | 소속 법인명 |
| `allocationId` | integer | 현재 배차 ID (nullable) |
| `allocationStatus` | keyword | 현재 배차 상태 (nullable) |
| `drivingStatus` | keyword | 운행 상태 (DEFAULT, DRIVING 등) |
| `destination` | text | 목적지 (nullable) |
| `passengerCount` | integer | 탑승 인원 (nullable) |
| `departmentId` | integer | 부서 ID (nullable) |
| `employeeId` | integer | 직원 ID (nullable) |

**주요 필터 필드**: `drivingStatus`, `companyCode`, `carGrade`, `allocationStatus`

---

### driver-location_{YYYY-MM-DD}

기사 GPS 위치 실시간 트래킹. **일별 롤링 인덱스**. (일별 ~750,000건)

⚠️ 특정 날짜 인덱스 지정 + 필터 조건 + `size ≤ 1000` 필수.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | integer | 기사 ID |
| `name` | text | 기사명 |
| `mobile` | keyword | 휴대폰 번호 |
| `location` | geo_point | GPS 좌표 |
| `timestamp` | date | 기록 시각 |
| `carId` | integer | 차량 ID |
| `workStatus` | keyword | 근무 상태 |
| `restTime` | text | 휴식 시간 |
| `restStartDateTime` | date | 휴식 시작 시각 |

**인덱스 패턴 예시**:
- 오늘: `driver-location_2026-02-27`
- 이번 달: `driver-location_2026-02-*`
- 전체: `driver-location_*` (주의: 대량 조회 가능)

---

### driver_connect_clients

기사 앱 WebSocket 접속 세션. (132건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `socketIds` | nested | 소켓 ID 배열 |
| `socketIds.id` | keyword | 소켓 ID |

---

### car-history_{YYYY-MM-DD}

차량 사용 이력. **일별 롤링 인덱스** + `car-history_default` 기본 인덱스 병행. (일별 ~3,500건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `allocationId` | integer | 배차 ID |
| `carId` | integer | 차량 ID |
| `carNumber` | text | 차량 번호 |
| `carAlias` | text (.keyword) | 차량 별칭 |
| `carModelName` | text | 차량 모델명 |
| `carGrade` | keyword | 차량 등급 |
| `carCompanyCode` | keyword | 차량 소속 법인코드 |
| `allocationCompanyCode` | keyword | 배차 법인코드 |
| `drivingStatus` | keyword | 운행 상태 |
| `departure` | text | 출발지 |
| `destination` | text | 목적지 |
| `timestamp` | date | 기록 시각 |

---

## 3. 셔틀 도메인

### shuttle-status-history_{YYYY-MM-DD}

셔틀 노선 상태 변경 이력. **일별 롤링 인덱스**. (일별 ~25건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `shuttleStatus` | keyword | 셔틀 상태 |
| `shuttleLineAllocationId` | long | 셔틀노선 배차 ID |
| `allocationId` | keyword | 배차 ID |
| `sequence` | integer | 정류장 순서 |
| `location` | geo_point | GPS 좌표 |
| `createdAt` | date | 생성 시각 |

---

## 4. 지역/목적지 도메인

### region

행정구역 정보. 시도/시군구/읍면동 계층 + 경계 geometry. (1,455건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `regionCode` | keyword | 지역코드 |
| `regionName` | text | 지역명 |
| `sidoCode` | text | 시도 코드 |
| `sidoName` | text | 시도명 |
| `sigunguCode` | text | 시군구 코드 |
| `sigunguName` | text | 시군구명 |
| `emdCode` | text | 읍면동 코드 |
| `emdName` | text | 읍면동명 |
| `depth` | integer | 계층 깊이 |
| `centerPoint` | geo_point | 중심 좌표 |
| `geometry` | geo_shape | 경계 폴리곤 |

**활용**: 좌표 → 행정구역 매핑은 `geo_shape` 쿼리(`geo_shape` intersect)를 사용.

---

### destinations

목적지 정보. 벡터 임베딩을 통한 시맨틱 검색 지원. (3,270건)

| 필드 | 타입 | 설명 |
|------|------|------|
| `source` | keyword | 출처 |
| `sourceId` | keyword | 출처 ID |
| `userId` | keyword | 사용자 ID |
| `alias` | text (.keyword) | 별칭 |
| `shortAddress` | text (.keyword) | 짧은 주소 |
| `longAddress` | text (.keyword) | 긴 주소 |
| `jibunAddress` | text (.keyword) | 지번 주소 |
| `latitude` | float | 위도 |
| `longitude` | float | 경도 |
| `vector` | dense_vector (3072 dims) | 임베딩 벡터 |
| `timestamp` | date | 기록 시각 |

**활용**:
- 텍스트 검색: `alias`, `shortAddress`, `longAddress` 필드의 `.keyword` 서브필드 활용
- 벡터 검색: `vector` 필드로 kNN 시맨틱 유사도 검색
- 위치 기반 검색: `latitude`/`longitude`로 반경 검색 (geo_point 타입이 아니므로 range 쿼리 필요)
