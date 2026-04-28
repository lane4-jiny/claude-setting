# lane4-es 쿼리 패턴

카테고리별 자주 사용하는 ES|QL 및 Query DSL 쿼리 템플릿 모음.

## 목차

1. [기사 위치/상태](#1-기사-위치상태)
2. [배차 경로](#2-배차-경로)
3. [차량 이력](#3-차량-이력)
4. [셔틀](#4-셔틀)
5. [지역/목적지](#5-지역목적지)
6. [배차 상태 알림](#6-배차-상태-알림)
7. [시계열 집계](#7-시계열-집계)
8. [인덱스 관리/확인](#8-인덱스-관리확인)

---

## 1. 기사 위치/상태

### 현재 운행 중인 기사 목록 (esql)

```
FROM driver
| WHERE drivingStatus == "DRIVING"
| KEEP id, name, carNumber, companyCode, destination, allocationId
| SORT name
| LIMIT 100
```

### 특정 법인 기사 목록 (esql)

```
FROM driver
| WHERE companyCode == "gmcc"
| KEEP id, name, carNumber, drivingStatus, allocationStatus
| SORT name
| LIMIT 100
```

### 특정 기사 오늘 위치 이력 (esql)

> 인덱스명의 날짜를 오늘 날짜로 치환하여 사용한다.

```
FROM driver-location_2026-02-27
| WHERE name == "홍길동"
| SORT timestamp DESC
| KEEP id, name, location, timestamp, workStatus
| LIMIT 100
```

### 반경 내 기사 검색 (search — Query DSL)

> 강남역(37.4979, 127.0276) 반경 3km 이내 기사.

```json
{
  "index": "driver-location_2026-02-27",
  "body": {
    "query": {
      "bool": {
        "must": [
          {
            "geo_distance": {
              "distance": "3km",
              "location": {
                "lat": 37.4979,
                "lon": 127.0276
              }
            }
          }
        ]
      }
    },
    "sort": [
      {
        "_geo_distance": {
          "location": { "lat": 37.4979, "lon": 127.0276 },
          "order": "asc",
          "unit": "km"
        }
      }
    ],
    "size": 50,
    "_source": ["id", "name", "location", "timestamp", "workStatus"]
  }
}
```

### 특정 기사의 시간대별 위치 추적 (search — Query DSL)

> 기사 ID 42번의 14시~16시 위치.

```json
{
  "index": "driver-location_2026-02-27",
  "body": {
    "query": {
      "bool": {
        "must": [
          { "term": { "id": 42 } },
          {
            "range": {
              "timestamp": {
                "gte": "2026-02-27T14:00:00",
                "lte": "2026-02-27T16:00:00"
              }
            }
          }
        ]
      }
    },
    "sort": [{ "timestamp": "asc" }],
    "size": 500,
    "_source": ["id", "name", "location", "timestamp"]
  }
}
```

---

## 2. 배차 경로

### 배차 실제 경로 조회 (search — Query DSL)

> ⚠️ 대용량 인덱스 — allocationId + 시간 범위 + size 제한 필수.

```json
{
  "index": "actual-allocation-path",
  "body": {
    "query": {
      "bool": {
        "must": [
          { "term": { "allocationId": 12345 } }
        ]
      }
    },
    "sort": [{ "timestamp": "asc" }],
    "size": 100,
    "_source": ["allocationId", "location", "timestamp"]
  }
}
```

### 배차 예측 경로 조회 (search — Query DSL)

```json
{
  "index": "predicated-allocation-path",
  "body": {
    "query": {
      "term": { "allocationId": 12345 }
    },
    "sort": [{ "timestamp": "asc" }],
    "size": 100,
    "_source": ["allocationId", "locations", "timestamp"]
  }
}
```

### 실제 vs 예측 경로 비교 흐름

1. `actual-allocation-path`에서 `allocationId`로 실제 경로 좌표 조회
2. `predicated-allocation-path`에서 동일 `allocationId`로 예측 경로 좌표 조회
3. 두 결과의 좌표 시퀀스를 대조하여 경로 이탈 구간 분석

### 배차별 GPS 궤적 조회 (search — Query DSL, nested)

> `allocation_location`의 `coordinates`는 nested 타입.

```json
{
  "index": "allocation_location",
  "body": {
    "query": {
      "bool": {
        "must": [
          { "term": { "driver_id": "DRV_123" } },
          {
            "range": {
              "timestamp": {
                "gte": "2026-02-27 00:00:00",
                "lte": "2026-02-27 23:59:59"
              }
            }
          }
        ]
      }
    },
    "sort": [{ "timestamp": "asc" }],
    "size": 50,
    "_source": ["driver_id", "timestamp", "coordinates"]
  }
}
```

---

## 3. 차량 이력

### 특정 차량 오늘 운행 기록 (esql)

```
FROM car-history_2026-02-27
| WHERE carId == 101
| SORT timestamp DESC
| KEEP carId, carNumber, carAlias, drivingStatus, departure, destination, timestamp
| LIMIT 50
```

### 법인별 차량 운행 현황 (esql)

```
FROM car-history_2026-02-27
| WHERE carCompanyCode == "gmcc"
| STATS count = COUNT(*) BY drivingStatus
```

### 특정 차량 번호로 이력 검색 (esql)

```
FROM car-history_2026-02-27
| WHERE carNumber == "서울 12가 3456"
| SORT timestamp DESC
| KEEP allocationId, carId, carNumber, drivingStatus, departure, destination, timestamp
| LIMIT 50
```

---

## 4. 셔틀

### 이번 주 셔틀 상태 변경 이력 (esql)

```
FROM shuttle-status-history_2026-02-*
| WHERE createdAt >= "2026-02-24T00:00:00"
| SORT createdAt DESC
| KEEP shuttleStatus, shuttleLineAllocationId, allocationId, sequence, location, createdAt
| LIMIT 100
```

### 특정 셔틀 노선의 정류장별 도착 이력 (search — Query DSL)

```json
{
  "index": "shuttle-status-history_2026-02-27",
  "body": {
    "query": {
      "term": { "shuttleLineAllocationId": 567 }
    },
    "sort": [{ "sequence": "asc" }, { "createdAt": "asc" }],
    "size": 50
  }
}
```

---

## 5. 지역/목적지

### 행정구역 검색 — 지역명 (esql)

```
FROM region
| WHERE sidoName == "서울특별시" AND sigunguName == "강남구"
| KEEP regionCode, regionName, sidoName, sigunguName, emdName, centerPoint, depth
| LIMIT 50
```

### 좌표 → 행정구역 매핑 (search — geo_shape)

> 특정 좌표가 어떤 행정구역에 속하는지 확인.

```json
{
  "index": "region",
  "body": {
    "query": {
      "geo_shape": {
        "geometry": {
          "shape": {
            "type": "point",
            "coordinates": [127.0276, 37.4979]
          },
          "relation": "intersects"
        }
      }
    },
    "_source": ["regionCode", "regionName", "sidoName", "sigunguName", "emdName"]
  }
}
```

주의: GeoJSON 좌표 순서는 **[경도, 위도]** (lon, lat).

### 목적지 텍스트 검색 (esql)

```
FROM destinations
| WHERE shortAddress LIKE "*인천공항*"
| KEEP alias, shortAddress, longAddress, latitude, longitude
| LIMIT 20
```

### 목적지 벡터 유사도 검색 (search — kNN)

> 임베딩 벡터를 사용한 시맨틱 검색. 벡터 값은 외부에서 생성하여 전달.

```json
{
  "index": "destinations",
  "body": {
    "knn": {
      "field": "vector",
      "query_vector": [0.12, -0.34, ...],
      "k": 10,
      "num_candidates": 50
    },
    "_source": ["alias", "shortAddress", "longAddress", "latitude", "longitude"]
  }
}
```

---

## 6. 배차 상태 알림

### 특정 배차의 리마인드 이력 (esql)

```
FROM allocation-status-update-reminder-history
| WHERE allocationId == 12345
| SORT createdAt DESC
| KEEP allocationId, driverId, currentStatus, requestedStatus, distance, createdAt
| LIMIT 50
```

### 상태 미전환 건 조회 (esql)

> `currentStatus`와 `requestedStatus`가 다른 건.

```
FROM allocation-status-update-reminder-history
| WHERE currentStatus != requestedStatus
| SORT createdAt DESC
| KEEP allocationId, driverId, currentStatus, requestedStatus, distance, createdAt
| LIMIT 100
```

---

## 7. 시계열 집계

### 시간대별 기사 위치 수집 건수 (esql)

```
FROM driver-location_2026-02-27
| STATS count = COUNT(*) BY BUCKET(timestamp, 1 hour)
| SORT `BUCKET(timestamp, 1 hour)`
```

### 법인별 운행 기사 수 (esql)

```
FROM driver
| WHERE drivingStatus == "DRIVING"
| STATS count = COUNT(*) BY companyCode
```

### 일별 차량 가동 건수 (search — date_histogram)

```json
{
  "index": "car-history_2026-02-*",
  "body": {
    "size": 0,
    "aggs": {
      "daily_count": {
        "date_histogram": {
          "field": "timestamp",
          "calendar_interval": "day"
        },
        "aggs": {
          "unique_cars": {
            "cardinality": {
              "field": "carId"
            }
          }
        }
      }
    }
  }
}
```

---

## 8. 인덱스 관리/확인

### 인덱스 목록 확인

도구: `list_indices`
사용 시점: 어떤 인덱스가 존재하는지 확인할 때

### 인덱스 매핑 확인

도구: `get_mappings`
파라미터: 인덱스명 (예: `driver`, `driver-location_2026-02-27`)
사용 시점: 필드명이나 타입이 불확실할 때

### 샤드 상태 확인

도구: `get_shards`
사용 시점: 인프라/클러스터 상태를 점검할 때
