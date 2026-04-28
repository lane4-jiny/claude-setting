# Redis 키 패턴 맵

LANE4 서비스에서 사용하는 Redis 키의 도메인별 패턴, 타입, TTL, 용도를 정리한 문서이다.
자연어 질의에서 도메인 키워드를 추출한 후, 이 문서를 참조하여 적절한 키 패턴을 결정한다.

---

## 1. 도메인별 키 패턴

### 대시보드 (dashboard)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `dashboard:{companyCode}:TYPE1:{whiteListId}:{userId}:{isApp}` | hash | 없음(-1) | 사용자별 배차현황 대시보드 |
| `dashboard:{companyCode}:TYPE3` | hash | ~4개월 (10368000초) | 법인 전체 배차통계 (일별/주별/월별/시간대별) |
| `dashboard:{companyCode}:TYPE1:{whiteListId}:{userId}:undefined` | hash | 없음(-1) | isApp 미설정 사용자 (웹 접속) |

**키 구조 상세:**
```
dashboard:{companyCode}:TYPE1:{whiteListId}:{userId}:{isApp}

- companyCode : 법인코드 (gmcc, lane4, emirates, ke 등)
- TYPE1       : 사용자별 배차현황 대시보드
- TYPE3       : 법인 전체 배차 통계
- whiteListId : 서비스 지역 ID (327, 431, 133 등)
- userId      : 사용자 로그인 ID
- isApp       : Y(앱) / undefined(웹)
```

**자연어 트리거 키워드:** 대시보드, 배차현황, 배차통계, dashboard

### 요금 (fares)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `fares:{companyCode}:distance:{startRange}:{endRange}:{carModelId}` | - | - | 거리 구간별 요금 캐시 |
| `fares:{companyCode}:distance:{startRange}:{endRange}:{carModelId}:shared` | - | - | 합승 요금 캐시 |

**자연어 트리거 키워드:** 요금, 요금표, fare, 요금 캐시, 합승 요금

### 배차좌표 (allocations-coordinates)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `allocations-coordinates:{companyCode}:{allocationId}` | - | 7일 (604800초) | 배차 경로 좌표 |

**자연어 트리거 키워드:** 배차좌표, 경로좌표, 좌표 캐시, allocation coordinates

### 기사스케줄 (work-schedules)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `work-schedules:{workScheduleId}` | - | - | 개별 스케줄 캐시 |
| `work-schedules:accepted` | - | - | 수락된 스케줄 목록 |
| `work-schedules:{workScheduleId}:views` | - | - | 스케줄 조회수 |

**자연어 트리거 키워드:** 기사 스케줄, 운행 스케줄, work schedule, 스케줄 캐시

### 안심번호 (safe-number)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `safe-number:used` | set | - | 사용중인 안심번호 풀 |
| `safe-number:unused` | set | - | 미사용 안심번호 풀 |

**자연어 트리거 키워드:** 안심번호, 안심번호 풀, safe number, 050번호

### 항공편 (flights)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `flights:{date}:{flightNumber}` | - | - | 항공편 정보 캐시 |

**자연어 트리거 키워드:** 항공편, 비행편, flight, 항공편 캐시

### 환율 (currency)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `currency:{currencyType}` | - | - | 환율 정보 |

**자연어 트리거 키워드:** 환율, currency, 환율 캐시, USD, JPY

### 매출분석 (operational-analytics)

| 키 패턴 | 타입 | TTL | 설명 |
|--------|------|-----|------|
| `operational-analytics:{companyCode}:revenue` | hash | ~4개월 (10368000초) | 매출 대시보드 캐시 |

**자연어 트리거 키워드:** 매출분석, 매출 캐시, operational analytics, 매출 대시보드

---

## 2. 법인코드 참조

| 법인코드 | 법인명 | 비고 |
|---------|--------|------|
| `gmcc` | GMCC | 주요 법인 |
| `lane4` | Lane4 | 자사 |
| `emirates` | 에미레이츠 | 항공사 제휴 |
| `ke` | 대한항공 | 항공사 제휴 |

사용자가 법인명을 한글로 말하면 위 매핑으로 법인코드를 변환하여 키 패턴에 적용한다.
예: "에미레이츠 대시보드 캐시" → `dashboard:emirates:*`

---

## 3. 키워드 → 키 패턴 빠른 참조

| 사용자 키워드 | 키 패턴 |
|-------------|---------|
| 대시보드, 배차현황 | `dashboard:{companyCode}:*` |
| 대시보드 통계, 법인 통계 | `dashboard:{companyCode}:TYPE3` |
| 사용자 대시보드 | `dashboard:{companyCode}:TYPE1:*` |
| 요금, 요금표 | `fares:{companyCode}:*` |
| 합승 요금 | `fares:{companyCode}:*:shared` |
| 배차 좌표, 경로 | `allocations-coordinates:{companyCode}:*` |
| 특정 배차 좌표 | `allocations-coordinates:*:{allocationId}` |
| 기사 스케줄 | `work-schedules:*` |
| 안심번호 | `safe-number:*` |
| 안심번호 사용현황 | `safe-number:used`, `safe-number:unused` |
| 항공편 | `flights:*` |
| 특정 날짜 항공편 | `flights:{date}:*` |
| 환율 | `currency:*` |
| 매출, 매출분석 | `operational-analytics:{companyCode}:revenue` |
| 전체 키 수 | `dbsize()` 사용 |
