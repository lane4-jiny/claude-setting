# lane4-es 인덱스 맵

인덱스를 도메인별로 분류한다. 규모와 인덱스 패턴을 함께 표기한다.

## 목차

1. [배차 도메인](#배차-도메인)
2. [기사/차량 도메인](#기사차량-도메인)
3. [셔틀 도메인](#셔틀-도메인)
4. [지역/목적지 도메인](#지역목적지-도메인)
5. [기타](#기타)
6. [인덱스 선택 가이드](#인덱스-선택-가이드)

---

## 배차 도메인

| 인덱스 | 문서 수 | 인덱스 패턴 | 역할 |
|--------|---------|------------|------|
| `allocation` | 94K | 단일 | 배차-기사-위치 매핑 (지도 표시용) |
| `allocation_location` | 18.5M | 단일 | 배차별 GPS 궤적 (시계열) |
| `actual-allocation-path` | **139M** | 단일 | 실제 이동 경로 포인트 ⚠️ **대용량** |
| `predicated-allocation-path` | 234K | 단일 | 예측 경로 (실제 경로와 비교용) |
| `allocation-status-update-reminder-history` | 35K | 단일 | 배차 상태 업데이트 리마인드 이력 |

### 배차 도메인 주의사항

- `actual-allocation-path`는 1.39억건 — **반드시** `allocationId` + 시간 범위 + `size ≤ 100` 조건 필수
- `allocation_location`은 1,860만건 — **반드시** `driver_id` + 시간 범위 + `size ≤ 100` 조건 필수
- 배차 경로 비교: `actual-allocation-path` (실제) vs `predicated-allocation-path` (예측)을 동일 `allocationId`로 대조

---

## 기사/차량 도메인

| 인덱스 | 문서 수 | 인덱스 패턴 | 역할 |
|--------|---------|------------|------|
| `driver` | 270 | 단일 | 기사 실시간 상태 (현재 배차, 차량, 운행 상태) |
| `driver-location_{YYYY-MM-DD}` | 일별 ~750K | **일별 롤링** | 기사 GPS 위치 실시간 트래킹 |
| `driver_connect_clients` | 132 | 단일 | 기사 앱 WebSocket 접속 세션 |
| `car-history_{YYYY-MM-DD}` | 일별 ~3.5K | **일별 롤링** | 차량 사용 이력 |
| `car-history_default` | - | 단일 (상시) | 차량 사용 이력 기본 인덱스 |

### 기사/차량 도메인 주의사항

- `driver-location_*`은 일별 75만건 — 특정 날짜 인덱스 지정 + 필터 조건 + `size ≤ 1000`
- `driver` 인덱스는 270건으로 소규모 — 전체 스캔 가능
- `car-history_default`는 일별 인덱스와 별도로 존재하는 상시 인덱스

### 일별 인덱스 패턴 예시

```
오늘 기사 위치:        driver-location_2026-02-27
이번 달 기사 위치:     driver-location_2026-02-*
오늘 차량 이력:        car-history_2026-02-27
```

---

## 셔틀 도메인

| 인덱스 | 문서 수 | 인덱스 패턴 | 역할 |
|--------|---------|------------|------|
| `shuttle-status-history_{YYYY-MM-DD}` | 일별 ~25 | **일별 롤링** | 셔틀 노선 상태 변경 이력 |

### 셔틀 도메인 참고

- 소규모 데이터 — 와일드카드 범위 조회 부담 적음
- 셔틀 노선의 정류장 순서(`sequence`)와 GPS 좌표(`location`) 포함

---

## 지역/목적지 도메인

| 인덱스 | 문서 수 | 인덱스 패턴 | 역할 |
|--------|---------|------------|------|
| `region` | 1,455 | 단일 | 행정구역 정보 (시도/시군구/읍면동 + 경계 geometry) |
| `destinations` | 3,270 | 단일 | 목적지 정보 (주소 + 벡터 임베딩 시맨틱 검색) |

### 지역/목적지 도메인 참고

- `region`은 `geo_shape` 필드로 행정구역 경계 폴리곤 보유 — 좌표 → 행정구역 매핑 가능
- `destinations`은 `dense_vector`(3072 dims) 필드로 kNN 시맨틱 검색 지원

---

## 기타

| 인덱스 | 문서 수 | 역할 |
|--------|---------|------|
| `voice_report_process_result` | 0 | 음성 리포트 처리 결과 (현재 미사용, 빈 인덱스) |

---

## 인덱스 선택 가이드

질문 유형별 어떤 인덱스를 먼저 확인해야 하는지 가이드:

| 질문 유형 | 1순위 인덱스 | 2순위 인덱스 |
|----------|------------|------------|
| 기사 현재 상태/목록 | `driver` | - |
| 기사 실시간 위치/이동 | `driver-location_오늘날짜` | `driver` |
| 기사 과거 위치 이력 | `driver-location_해당날짜` | - |
| 배차 실제 경로 | `actual-allocation-path` | `allocation` |
| 배차 예측 경로 | `predicated-allocation-path` | - |
| 배차 경로 비교 | `actual-allocation-path` + `predicated-allocation-path` | - |
| 배차 GPS 궤적 | `allocation_location` | `allocation` |
| 차량 사용 이력 | `car-history_해당날짜` | `car-history_default` |
| 셔틀 상태 이력 | `shuttle-status-history_해당날짜` | - |
| 행정구역/지역 검색 | `region` | - |
| 목적지 검색 (텍스트/벡터) | `destinations` | - |
| 배차 상태 알림 이력 | `allocation-status-update-reminder-history` | - |
| WebSocket 접속 확인 | `driver_connect_clients` | - |
| 반경 내 기사 검색 | `driver-location_오늘날짜` | - |
| 좌표 → 행정구역 | `region` (geo_shape) | - |
