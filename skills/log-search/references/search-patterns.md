# 자주 쓰는 로그 검색 패턴

## DB (HTTP_LOG) 검색 패턴

### 1. 특정 시간대 에러 조회
```sql
SELECT REQUEST_URL, RESPONSE_STATUS, CREATED_AT, DURATION_MS
FROM HTTP_LOG
WHERE CREATED_AT BETWEEN '2024-01-15 10:00:00' AND '2024-01-15 11:00:00'
  AND RESPONSE_STATUS >= 400
ORDER BY CREATED_AT DESC
LIMIT 100;
```

### 2. 특정 API 엔드포인트 조회
```sql
SELECT REQUEST_METHOD, RESPONSE_STATUS, CREATED_AT, DURATION_MS
FROM HTTP_LOG
WHERE REQUEST_URL LIKE '%/api/allocation%'
  AND CREATED_AT >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY CREATED_AT DESC
LIMIT 100;
```

### 3. 느린 API 조회 (응답 시간 기준)
```sql
SELECT REQUEST_URL, REQUEST_METHOD, DURATION_MS, CREATED_AT
FROM HTTP_LOG
WHERE DURATION_MS > 3000
  AND CREATED_AT >= DATE_SUB(NOW(), INTERVAL 1 DAY)
ORDER BY DURATION_MS DESC
LIMIT 50;
```

### 4. 상태코드별 집계
```sql
SELECT RESPONSE_STATUS, COUNT(*) AS cnt
FROM HTTP_LOG
WHERE CREATED_AT >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
GROUP BY RESPONSE_STATUS
ORDER BY cnt DESC;
```

### 5. 특정 사용자 요청 이력
```sql
SELECT REQUEST_URL, REQUEST_METHOD, RESPONSE_STATUS, CREATED_AT
FROM HTTP_LOG
WHERE USER_ID = '{user_id}'
  AND CREATED_AT >= DATE_SUB(NOW(), INTERVAL 1 DAY)
ORDER BY CREATED_AT DESC
LIMIT 100;
```

## ES 검색 패턴

### 1. 기사 위치 조회
```json
{
  "index": "driver-location-*",
  "query": {
    "bool": {
      "must": [
        { "term": { "driver_id": "{driver_id}" } },
        { "range": { "timestamp": { "gte": "now-1h" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }],
  "size": 100
}
```

### 2. 배차 실경로 조회
```json
{
  "index": "allocation-route-*",
  "query": {
    "term": { "allocation_id": "{allocation_id}" }
  },
  "sort": [{ "timestamp": "asc" }],
  "size": 1000
}
```

### 3. 배차 상태 변경 이력
```json
{
  "index": "allocation-status-*",
  "query": {
    "bool": {
      "must": [
        { "term": { "allocation_id": "{allocation_id}" } }
      ]
    }
  },
  "sort": [{ "changed_at": "asc" }]
}
```

### 4. 에러 로그 검색
```json
{
  "index": "error-log-*",
  "query": {
    "bool": {
      "must": [
        { "match": { "error_message": "{keyword}" } },
        { "range": { "timestamp": { "gte": "now-1h" } } }
      ]
    }
  },
  "sort": [{ "timestamp": "desc" }],
  "size": 50
}
```

### 5. ES|QL 에러 집계
```
FROM error-log-*
| WHERE timestamp >= NOW() - 1 hour
| STATS count = COUNT(*) BY error_message
| SORT count DESC
| LIMIT 20
```

## 검색 팁

- **시간 범위**: 항상 시간 범위를 지정. 넓은 범위는 성능 저하
- **인덱스 패턴**: 날짜 기반 인덱스는 필요한 날짜만 지정
- **결과 크기**: size/LIMIT을 적절히 설정 (기본 100)
- **필드 선택**: 필요한 필드만 _source에 지정하여 네트워크 부하 감소
