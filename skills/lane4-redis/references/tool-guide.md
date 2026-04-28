# MCP 도구 사용 가이드

lane4-redis MCP 서버에서 제공하는 도구의 카테고리별 정리와 시나리오별 사용 패턴을 정리한 문서이다.

---

## 1. 도구 카테고리별 정리

### 탐색 (가장 자주 사용)

| 도구 | 시그니처 | 용도 | 비고 |
|------|---------|------|------|
| `scan_all_keys` | `scan_all_keys(pattern)` | 패턴 매칭 키 전체 조회 | 도메인 접두사 필수 |
| `scan_keys` | `scan_keys(pattern, count, cursor)` | 점진적 키 탐색 | 대량 키 대응, cursor 기반 |
| `type` | `type(key)` | 키의 데이터 타입 확인 | 조회 도구 선택 전 필수 확인 |
| `dbsize` | `dbsize()` | 전체 키 수 조회 | 서버 상태 파악용 |

**탐색 시 주의사항:**
- `scan_all_keys("*")` 같은 무차별 스캔은 자제한다. 항상 도메인 접두사를 포함한다.
- 키가 매우 많을 것으로 예상되면 `scan_keys(pattern, count=100)` 으로 점진적 탐색한다.
- `type(key)` 결과를 확인한 후 적절한 조회 도구를 선택한다.

### Hash 조작 (대시보드, 매출 등 주요 캐시)

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `hgetall` | `hgetall(name)` | 해시 전체 필드 조회 |
| `hget` | `hget(name, key)` | 특정 필드만 조회 |
| `hexists` | `hexists(name, key)` | 필드 존재 여부 확인 |
| `hset` | `hset(name, key, value, expire_seconds?)` | 필드 설정 ⚠️ |
| `hdel` | `hdel(name, key)` | 필드 삭제 ⚠️ |

**Hash 조회 팁:**
- 대시보드, 매출 등 대부분의 캐시가 hash 타입이다.
- `hgetall`은 전체 필드를 가져오므로 데이터 구조 파악에 좋다.
- 특정 필드만 필요하면 `hget(name, "values")` 또는 `hget(name, "lastUpdatedAt")` 사용.
- `values` 필드는 JSON 문자열이므로 파싱이 필요하다.

### String 조작

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `get` | `get(key)` | 문자열 값 조회 |
| `set` | `set(key, value, expire_seconds?)` | 문자열 값 설정 ⚠️ |

### Set 조작 (안심번호 풀 등)

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `smembers` | `smembers(name)` | 셋 전체 멤버 조회 |
| `sadd` | `sadd(name, value)` | 멤버 추가 ⚠️ |
| `srem` | `srem(name, value)` | 멤버 제거 ⚠️ |

### List 조작

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `lrange` | `lrange(name, start, stop)` | 리스트 범위 조회 |
| `llen` | `llen(name)` | 리스트 길이 |
| `lpush` | `lpush(name, value)` | 왼쪽 삽입 ⚠️ |
| `rpush` | `rpush(name, value)` | 오른쪽 삽입 ⚠️ |

### Sorted Set 조작

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `zrange` | `zrange(name, start, stop)` | 정렬된 범위 조회 |
| `zadd` | `zadd(name, score, value)` | 멤버 추가 ⚠️ |
| `zrem` | `zrem(name, value)` | 멤버 제거 ⚠️ |

### Stream 조작

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `xrange` | `xrange(name, min, max)` | 스트림 범위 조회 |
| `xadd` | `xadd(name, fields)` | 스트림 항목 추가 ⚠️ |

### JSON 조작

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `json_get` | `json_get(key, path?)` | JSON 경로 조회 |
| `json_set` | `json_set(key, path, value)` | JSON 경로 설정 ⚠️ |

### 키 관리

| 도구 | 시그니처 | 용도 | 보호 수준 |
|------|---------|------|----------|
| `delete` | `delete(key)` | 키 삭제 | ⚠️ 값+TTL 확인 후 사용자 승인 필수 |
| `expire` | `expire(key, seconds)` | TTL 설정 | ⚠️ 사용자 확인 필수 |
| `rename` | `rename(old, new)` | 키 이름 변경 | ⚠️ 사용자 확인 필수 |

### 서버 정보

| 도구 | 시그니처 | 용도 |
|------|---------|------|
| `dbsize` | `dbsize()` | 전체 키 수 |
| `info` | `info()` | Redis 서버 정보 (메모리, 히트율 등) |
| `client_list` | `client_list()` | 연결된 클라이언트 목록 |

---

## 2. 시나리오별 조회 패턴

### 시나리오 1: 특정 법인의 대시보드 캐시 전체 조회

```
1. scan_all_keys("dashboard:gmcc:*")     → 관련 키 목록
2. type(key)                              → hash 확인
3. hgetall(key)                           → 데이터 조회
4. values 필드 JSON 파싱                    → 구조화된 데이터로 해석
```

### 시나리오 2: 안심번호 풀 현황 확인

```
1. smembers("safe-number:used")           → 사용중 번호 목록
2. smembers("safe-number:unused")         → 미사용 번호 목록
3. 각각의 멤버 수를 세어 현황 요약
```

### 시나리오 3: 특정 배차의 좌표 캐시 확인

```
1. scan_all_keys("allocations-coordinates:*:{allocationId}")  → 키 탐색
   또는 법인코드를 알면: scan_all_keys("allocations-coordinates:gmcc:{allocationId}")
2. type(key)                              → 타입 확인
3. 타입에 따라 적절한 조회 도구 사용
```

### 시나리오 4: 캐시 신선도 점검

```
1. hgetall(key)                           → lastUpdatedAt 필드 확인
2. type(key)                              → TTL 정보 확인
3. lastUpdatedAt과 현재 시각 비교
4. 갱신 주기 대비 지연 여부 판단
```

### 시나리오 5: 캐시 ↔ DB 불일치 진단

```
1. hgetall(key)                           → Redis 캐시 데이터 확인
2. values 필드 JSON 파싱                    → 캐시 값 추출
3. lane4-mysql 스킬로 DB 원본 조회           → 원본 데이터 확인
4. 캐시 값과 DB 값 비교 분석
5. 불일치 원인 추정 (갱신 지연, 로직 오류 등)
```

### 시나리오 6: 요금 캐시 전수 조사

```
1. scan_all_keys("fares:*")              → 전체 요금 캐시 키 목록
2. 법인별/구간별 그루핑
3. 각 키의 type 확인 후 적절한 조회
4. 요금 체계 요약 테이블 생성
```

### 시나리오 7: Redis 서버 상태 확인

```
1. dbsize()                              → 전체 키 수
2. info()                                → 메모리 사용량, 히트율 등
3. client_list()                         → 연결 클라이언트 수
```

---

## 3. 도구 선택 의사결정 트리

```
질의에서 키 패턴 결정
  ↓
scan_all_keys(pattern) 으로 키 목록 조회
  ↓
키가 존재하는가?
  ├─ NO → "해당 키가 존재하지 않습니다" 안내. 캐시 미생성 또는 만료 가능성.
  └─ YES → type(key) 로 타입 확인
              ↓
            타입별 분기:
              ├─ string  → get(key)
              ├─ hash    → hgetall(key) 또는 hget(key, field)
              ├─ list    → lrange(key, 0, -1) 또는 llen(key)
              ├─ set     → smembers(key)
              ├─ zset    → zrange(key, 0, -1)
              ├─ stream  → xrange(key, "-", "+")
              └─ json    → json_get(key)
              ↓
            결과 해석 (values 필드 JSON 파싱 등)
              ↓
            사람이 읽기 쉬운 형태로 요약
```
