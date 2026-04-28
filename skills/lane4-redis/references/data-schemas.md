# Redis 캐시 데이터 스키마

주요 캐시 데이터의 JSON 구조를 정리한 문서이다.
Redis hash의 `values` 필드는 JSON 문자열로 저장되므로, 반드시 파싱한 후 해석해야 한다.

---

## 공통 패턴: JSON-in-Hash

LANE4의 Redis 캐시는 대부분 hash 타입이며, 다음과 같은 공통 구조를 가진다:

```
Hash Key: dashboard:gmcc:TYPE3
Hash Fields:
  - "lastUpdatedAt" : "2026-02-27 16:06:53"     (문자열)
  - "expiration"    : "2025-12-02 08:30:32"      (문자열, 일부 키)
  - "values"        : '{"result":true,"data":{...}}'  (JSON 문자열 ← 반드시 파싱)
```

`values` 필드를 그대로 읽으면 이스케이프된 JSON 문자열이다. 파싱하여 구조화된 데이터로 변환한 뒤 해석한다.

---

## 1. TYPE1 — 사용자별 배차현황 대시보드

**키 패턴:** `dashboard:{companyCode}:TYPE1:{whiteListId}:{userId}:{isApp}`

```json
{
  "expiration": "2025-12-02 08:30:32",
  "values": {
    "result": true,
    "data": {
      "type": "TYPE1",
      "period": {
        "daily": {
          "allocationCount": 141,
          "completedAllocationCount": 129,
          "signText": "down|up",
          "rate": 48
        },
        "weekly": {
          "allocationCount": 0,
          "completedAllocationCount": 0,
          "signText": "down|up",
          "rate": 0
        },
        "monthly": {
          "allocationCount": 0,
          "completedAllocationCount": 0,
          "signText": "down|up",
          "rate": 0
        },
        "total": {
          "allocationCount": 79451,
          "completedAllocationCount": 77501,
          "signText": null,
          "rate": null
        }
      },
      "allocationCount": [
        { "type": "편도", "value": 79037 }
      ],
      "weeklyAllocationCountInfo": [
        {
          "date": "2025.12.01",
          "type": "예약 배차 수|운행 완료 수",
          "value": 270
        }
      ]
    }
  }
}
```

**필드 해석:**

| 필드 | 설명 |
|------|------|
| `period.daily.allocationCount` | 일간 예약 배차 수 |
| `period.daily.completedAllocationCount` | 일간 운행 완료 수 |
| `period.daily.signText` | 전일 대비 증감 방향 (`down` / `up`) |
| `period.daily.rate` | 전일 대비 변동률 (%) |
| `period.weekly` / `monthly` | 주간/월간 동일 구조 |
| `period.total.allocationCount` | 누적 전체 배차 수 |
| `period.total.completedAllocationCount` | 누적 운행 완료 수 |
| `allocationCount[].type` | 배차 유형 (편도, 왕복 등) |
| `allocationCount[].value` | 해당 유형의 배차 수 |
| `weeklyAllocationCountInfo` | 주간 일별 배차/완료 추이 |

---

## 2. TYPE3 — 법인 전체 배차통계

**키 패턴:** `dashboard:{companyCode}:TYPE3`

```json
{
  "lastUpdatedAt": "2026-02-27 16:06:53",
  "values": {
    "meta": { "type": "TYPE3" },
    "summary": {
      "totalSummary": {
        "daily": {
          "current": 203,
          "previous": 442,
          "changePercent": 54,
          "changeSign": "-|+"
        },
        "weekly": { },
        "monthly": { }
      },
      "sameTimeSummary": { }
    },
    "charts": {
      "daily": [{
        "label": "02-27(금)",
        "totalCount": 221,
        "completedCount": 200,
        "cancelledCount": 18,
        "notBoardedCount": 3
      }],
      "weekly": [{
        "label": "02-23~03-01",
        "totalCount": 0,
        "completedCount": 0,
        "cancelledCount": 0,
        "notBoardedCount": 0
      }],
      "monthly": [{
        "label": "2026-02",
        "totalCount": 0,
        "completedCount": 0,
        "cancelledCount": 0,
        "notBoardedCount": 0
      }],
      "hourly": [{
        "label": "00:00",
        "totalCount": 25,
        "completedCount": 24,
        "cancelledCount": 1,
        "notBoardedCount": 0,
        "date": "2026-02-20"
      }]
    }
  }
}
```

**필드 해석:**

| 필드 | 설명 |
|------|------|
| `lastUpdatedAt` | 캐시 마지막 갱신 시각 (캐시 신선도 판단 기준) |
| `summary.totalSummary.daily.current` | 오늘 배차 수 |
| `summary.totalSummary.daily.previous` | 전일 배차 수 |
| `summary.totalSummary.daily.changePercent` | 전일 대비 변동률 (%) |
| `summary.totalSummary.daily.changeSign` | 증감 부호 (`-` 감소 / `+` 증가) |
| `summary.sameTimeSummary` | 동시간대 비교 (동일 구조) |
| `charts.daily[].totalCount` | 일별 전체 배차 수 |
| `charts.daily[].completedCount` | 일별 운행 완료 수 |
| `charts.daily[].cancelledCount` | 일별 취소 수 |
| `charts.daily[].notBoardedCount` | 일별 미탑승 수 |
| `charts.hourly` | 시간대별 배차 분포 |

**캐시 신선도 점검:**
- `lastUpdatedAt`이 현재 시각보다 오래되었으면 캐시 갱신이 지연된 것이다.
- TYPE3의 갱신 주기는 약 1시간 (비동기 리프레시).
- TTL은 약 4개월 (10368000초).

---

## 3. 매출분석 (operational-analytics)

**키 패턴:** `operational-analytics:{companyCode}:revenue`

```json
{
  "lastUpdatedAt": "yyyy-MM-dd HH:mm:ss",
  "values": "FindRevenueResponse JSON"
}
```

- TTL: 10368000초 (약 4개월)
- 갱신 주기: 1시간 (비동기 리프레시)
- 대상 법인: emirates, gmcc, ke

`values` 필드에는 `FindRevenueResponse` 타입의 JSON 문자열이 저장된다.
구체적인 필드 구조는 매출 분석 서비스의 응답 형태에 따른다.

---

## 4. 일반 캐시 해석 가이드

### values 필드 파싱

1. `hgetall(key)` 결과에서 `values` 필드를 가져온다.
2. JSON 문자열이므로 파싱한다.
3. 파싱된 객체에서 `result`, `data`, `meta` 등의 필드를 확인한다.

### 캐시 유효성 판단

| 필드 | 의미 | 판단 기준 |
|------|------|----------|
| `lastUpdatedAt` | 마지막 갱신 시각 | 현재 시각과 비교하여 갱신 지연 여부 판단 |
| `expiration` | 만료 시각 | 이 시각 이후의 데이터는 stale |
| TTL (type 결과에 포함) | 남은 생존 시간(초) | -1이면 영구 캐시, -2이면 만료됨 |

### 자주 발생하는 이슈 패턴

| 증상 | 원인 가능성 | 진단 방법 |
|------|-----------|----------|
| 대시보드 데이터가 안 바뀜 | 캐시 갱신 실패 | `lastUpdatedAt` 확인 |
| 캐시와 DB 불일치 | 갱신 지연 또는 갱신 로직 오류 | Redis 데이터 vs MySQL 원본 비교 (lane4-mysql 연계) |
| 키가 존재하지 않음 | 캐시 만료 또는 미생성 | `scan_all_keys` 로 관련 키 존재 여부 확인 |
| TTL이 -1 | 영구 캐시 | 수동 삭제/갱신 필요 여부 안내 |
