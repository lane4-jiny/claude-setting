---
name: lane4-redis
description: >
  LANE4 Redis 캐시 자연어 조회 및 데이터 분석 스킬.
  lane4-redis MCP 서버를 통해 Redis에 접근하여 캐시 데이터를 조회·분석한다.
  이 스킬은 다음 상황에서 반드시 사용한다:
  - 대시보드, 요금, 좌표, 항공편, 환율, 스케줄, 안심번호 등 캐시 데이터 조회
  - "캐시 확인해줘", "대시보드 데이터 조회", "Redis 키 검색" 등 요청
  - 캐시 만료, 불일치, 갱신 관련 이슈 진단
  - DB 데이터와 캐시 데이터 비교가 필요할 때
  Redis, 캐시, 캐시 조회, 캐시 삭제, 캐시 갱신 등의 키워드가 포함되면 이 스킬을 적극 활용할 것.
  "대시보드 데이터가 이상해요", "캐시가 안 맞아요" 등 캐시 관련 이슈 질문에도 트리거한다.
---

# lane4-redis 스킬

LANE4 서비스의 Redis 캐시 데이터를 자연어로 조회·분석하기 위한 스킬이다.
lane4-redis MCP 서버 도구를 통해 Redis에 접근하며, 캐시 키 구조·도메인 매핑·데이터 해석 가이드를 제공한다.

---

## 다른 데이터 스킬과의 역할 분담

| 구분 | lane4-mysql | lane4-es | lane4-redis (이 스킬) | lane4-firebase |
|------|-------------|----------|----------------------|----------------|
| 대상 | 마스터 데이터, 트랜잭션 | 실시간 위치, 시계열 로그 | 캐시, 세션, 상태 풀 | 앱 실시간 상태, 점검/버전 |
| 데이터 성격 | 정규화 관계형 | 비정규화 문서/이벤트 | 키-값 캐시, JSON | RTDB 계층형 문서 |
| 주요 쿼리 | JOIN, GROUP BY, 집계 | geo 검색, 시계열 집계 | 키 패턴 스캔, 해시 조회 | 경로 기반 get/set |
| 예시 | "이번 달 법인별 매출" | "기사 실시간 위치" | "대시보드 캐시 확인" | "앱 점검 모드 확인" |

Redis는 **캐시 계층**을 담당한다. 원본(source of truth)은 MySQL이므로, 캐시와 원본 불일치가 의심될 때는 lane4-mysql 스킬과 연계하여 비교한다.

---

## 핵심 원칙

1. **READ ONLY (절대 규칙)** — 이 스킬은 **조회 전용**이다. 어떤 상황에서도 쓰기/수정/삭제 도구를 실행하지 않는다. 사용자가 요청하더라도 거부하고, 직접 Redis CLI나 어드민 도구를 사용하도록 안내한다.
2. **Non-blocking 스캔** — 대량 키 스캔 시 `scan_keys` 또는 `scan_all_keys`를 사용한다. `KEYS *` 명령은 절대 사용하지 않는다.
3. **JSON 파싱 필수** — 캐시 데이터의 `values` 필드는 JSON 문자열이다. 반드시 파싱한 후 해석한다.
4. **TTL 인식** — TTL이 -1인 키는 영구 캐시로, 수동 관리 대상임을 안내한다.
5. **스킬 연계** — DB 원본과의 불일치 감지 시 lane4-mysql 연계를 제안한다.
6. **도메인 접두사 필수** — `scan_all_keys("*")` 같은 무차별 스캔을 자제하고, 항상 도메인 접두사를 포함한 패턴을 사용한다.

---

## 워크플로우

```
[자연어 질의] → [도메인 식별] → [키 패턴 결정] → [MCP 도구 선택] → [데이터 조회] → [결과 해석/요약]
```

### Step 1: 도메인 식별

질의에서 도메인 키워드를 추출한다 (대시보드, 요금, 배차좌표, 항공편, 환율, 안심번호, 스케줄, 매출 등).
→ `references/key-map.md` 참조하여 관련 키 패턴을 결정한다.

### Step 2: 키 패턴 결정 & 키 탐색

- `scan_all_keys(pattern)` 으로 관련 키 목록을 조회한다.
- 키가 많으면 `scan_keys(pattern, count)` 으로 점진적 탐색한다.
- 키 패턴이 불명확하면 `references/key-map.md`의 도메인별 키 패턴 맵을 참조한다.

### Step 3: 데이터 조회

- `type(key)` 으로 데이터 타입을 확인한다.
- 타입에 따라 아래 도구 매핑표를 참고하여 적절한 조회 도구를 선택한다.
- JSON 필드 해석이 필요하면 `references/data-schemas.md`를 참조한다.

### Step 4: 결과 해석/요약

- JSON 데이터를 사람이 읽기 쉬운 테이블/요약으로 변환한다.
- TTL 정보를 포함하여 캐시 유효성을 안내한다.
- DB 원본과의 검증이 필요하면 lane4-mysql 스킬 연계를 제안한다.
- 다른 데이터 소스와의 연계가 필요하면 `references/cross-reference.md`를 참조한다.

---

## 도구 매핑표 (조회 전용)

| Redis 타입 | 사용 가능한 조회 도구 | 비고 |
|-----------|-------------------|------|
| `string` | `get` | 단순 캐시값 (환율 등) |
| `hash` | `hgetall`, `hget`, `hexists` | 대시보드, 매출 등 대부분의 캐시 |
| `list` | `lrange`, `llen` | 순서가 있는 데이터 |
| `set` | `smembers` | 안심번호 풀 등 |
| `zset` | `zrange` | 스코어 기반 정렬 |
| `stream` | `xrange` | 이벤트 스트림 |
| `json` | `json_get` | JSON 구조 데이터 |

### 사용 금지 도구 (절대 실행 불가)

아래 도구는 이 스킬에서 **어떤 상황에서도 실행하지 않는다**. 사용자가 요청하더라도 거부한다.

- **쓰기**: `set`, `hset`, `sadd`, `lpush`, `rpush`, `zadd`, `xadd`, `json_set`
- **삭제**: `delete`, `hdel`, `srem`, `zrem`, `lpop`, `rpop`, `xdel`, `json_del`
- **변경**: `rename`, `expire`
- **Pub/Sub 발행**: `publish`

> 쓰기/삭제가 필요한 경우: "이 작업은 lane4-redis 스킬의 조회 전용 정책으로 수행할 수 없습니다. Redis CLI 또는 어드민 도구를 직접 사용해 주세요." 라고 안내한다.

---

## 자연어 → 명령 변환 예시

| 자연어 질문 | 도구 | 실행 |
|------------|------|------|
| "gmcc 대시보드 캐시 확인" | `scan_all_keys` → `hgetall` | `scan_all_keys("dashboard:gmcc:*")` → `hgetall(key)` |
| "안심번호 풀 현황 조회" | `smembers` | `smembers("safe-number:used")`, `smembers("safe-number:unused")` |
| "에미레이츠 요금 캐시 확인" | `scan_all_keys` → `type` → 조회 | `scan_all_keys("fares:emirates:*")` |
| "배차 12345 좌표 캐시" | `scan_all_keys` → `hgetall` | `scan_all_keys("allocations-coordinates:*:12345")` |
| "대시보드 캐시 갱신 안 됨" | `hgetall` | `lastUpdatedAt` 필드 확인 → TTL 점검 |
| "오늘 환율 캐시 확인" | `get` | `get("currency:USD")` 등 |
| "Redis 전체 키 수" | `dbsize` | `dbsize()` |
| "캐시 키 삭제해줘" | ❌ 사용 불가 | 조회 전용 정책으로 거부. Redis CLI 직접 사용 안내 |
| "대시보드 캐시 vs DB 비교" | `hgetall` + lane4-mysql | Redis 조회 후 lane4-mysql로 DB 원본 비교 |

---

## 안전 제약사항

### 조회 전용 정책 (READ ONLY — 이 스킬의 최우선 규칙)

이 스킬은 **조회만 수행**한다. 쓰기·수정·삭제는 어떤 상황에서도 실행하지 않는다.

**사용 가능한 도구 (허용 목록):**
`scan_keys`, `scan_all_keys`, `hgetall`, `hget`, `hexists`, `get`, `smembers`, `lrange`, `llen`, `zrange`, `xrange`, `json_get`, `type`, `dbsize`, `info`, `client_list`, `get_indexes`, `get_index_info`, `get_indexed_keys_number`, `search_redis_documents`

**사용 금지 도구 (차단 목록 — 절대 실행 불가):**
- 쓰기: `set`, `hset`, `sadd`, `lpush`, `rpush`, `zadd`, `xadd`, `json_set`, `set_vector_in_hash`, `create_vector_index_hash`
- 삭제: `delete`, `hdel`, `srem`, `zrem`, `lpop`, `rpop`, `xdel`, `json_del`
- 변경: `rename`, `expire`
- Pub/Sub: `publish`, `subscribe`, `unsubscribe`

**사용자가 쓰기/삭제를 요청할 경우의 응답:**
> "lane4-redis 스킬은 조회 전용입니다. 캐시 수정/삭제는 Redis CLI 또는 어드민 도구에서 직접 수행해 주세요."

### 대량 스캔 보호

- `scan_all_keys("*")` 같은 무차별 스캔을 자제한다.
- 항상 도메인 접두사를 포함한 패턴을 사용한다 (예: `dashboard:gmcc:*`).
- 결과가 매우 많을 경우 `scan_keys(pattern, count)` 로 점진적 탐색한다.

### 민감 데이터

- Redis Host/Port 등 인프라 접속 정보는 응답에 노출하지 않는다.
- 실제 접속은 MCP 서버가 처리하므로 접속 정보가 필요하지 않다.

---

## 참조 문서 가이드

상황에 따라 아래 참조 문서를 읽어서 활용한다:

| 문서 | 경로 | 참조 시점 |
|------|------|----------|
| 키 패턴 맵 | `references/key-map.md` | 도메인 키워드로부터 Redis 키 패턴을 결정할 때 |
| 데이터 스키마 | `references/data-schemas.md` | 캐시 데이터의 JSON 구조를 해석할 때 |
| 도구 가이드 | `references/tool-guide.md` | MCP 도구 사용법 및 시나리오별 조회 패턴이 필요할 때 |
| 크로스 레퍼런스 | `references/cross-reference.md` | MySQL/ES/Firebase와 연계 조회가 필요할 때 |

---

## 코드베이스 참조

캐시 관련 코드 분석이 필요할 때 참조할 소스 파일:

| 도메인 | 소스 파일 | 키 패턴 |
|--------|----------|--------|
| Redis 인프라 | `src/commons/redis/application/redis.utils.service.ts` | - |
| 캐시 인프라 | `src/commons/cache/application/redis.cache.service.ts` | - |
| 캐시 API | `src/commons/cache/presentation/redis.cache.controller.ts` | - |
| 요금 | `src/domains/fare/application/find.fare.redis.service.ts` | `fares:*` |
| 기사스케줄 | `src/domains/work_schedule/application/redis.work.schedule.service.ts` | `work-schedules:*` |
| 배차좌표 | `src/allocation/application/redis.allocation.service.ts` | `allocations-coordinates:*` |
| 안심번호 | `src/domains/safe_number/application/redis.safe.number.service.ts` | `safe-number:*` |
| 항공편 | `src/domains/flight/infrastructure/redis.flight.repository.ts` | `flights:*` |
| 환율 | `src/domains/exchange_rate/application/find.exchange.rate.service.ts` | `currency:*` |
| 매출분석 | `src/domains/operational_analytics/application/operational.analytics.service.ts` | `operational-analytics:*` |
