---
name: log-search
description: DB(HTTP_LOG)와 Elasticsearch 양쪽에서 로그를 검색/분석. 사용자가 "로그", "로그 검색", "로그 조회", "에러 로그", "기사 위치", "실경로" 등을 요청할 때 사용.
---

# Log Search

DB(HTTP_LOG 테이블)와 Elasticsearch 양쪽에서 로그를 검색하고 분석한다.

## 핵심 제약사항

- 읽기 전용. 로그 데이터를 수정/삭제하지 않는다.
- 대량 조회시 반드시 시간 범위와 LIMIT 설정
- ES 인덱스 검색시 적절한 필터 사용 (전체 스캔 금지)
- 개인정보(전화번호, 이름 등)가 포함된 결과는 마스킹 처리

## 로그 소스별 용도

| 소스 | 도구 | 용도 |
|------|------|------|
| DB (HTTP_LOG) | lane4-mysql MCP | API 요청/응답 로그, HTTP 상태코드별 조회 |
| Elasticsearch | elasticsearch MCP | 기사 위치, 실경로, 상태 변경, 상세 로그 |

## DB 로그 검색 (HTTP_LOG)

### 사용 도구
- `lane4-mysql` MCP → SELECT 쿼리

### 주요 검색 패턴
- 특정 API 에러 조회 (상태코드 기반)
- 시간대별 요청량 집계
- 특정 사용자/기사의 요청 이력
- 응답 시간이 긴 요청 조회

## ES 로그 검색

### 사용 도구
- `elasticsearch` MCP → `list_indices`, `get_mappings`, `search`, `esql`

### 주요 검색 패턴
- 기사 위치 추적 (GPS 좌표)
- 실경로 조회 (배차별 이동 경로)
- 상태 변경 이력 (배차 상태 전이)
- 에러/예외 로그 검색
- 시간대별 로그 집계

## 검색 워크플로우

### 1. 요청 분석
- 사용자 요청에서 검색 대상(DB/ES) 판단
- 시간 범위, 필터 조건 추출

### 2-A. DB 로그 검색 경로
1. `references/db-log-tables.md`를 참조하여 테이블 스키마 확인
2. `references/search-patterns.md`를 참조하여 적절한 쿼리 패턴 선택
3. lane4-mysql MCP로 쿼리 실행
4. 결과 분석 및 요약

### 2-B. ES 로그 검색 경로
1. `references/es-indices.md`를 참조하여 적절한 인덱스 선택
2. elasticsearch MCP의 `get_mappings`로 필드 구조 확인 (필요시)
3. `references/search-patterns.md`를 참조하여 검색 패턴 선택
4. elasticsearch MCP의 `search` 또는 `esql`로 검색 실행
5. 결과 분석 및 요약

### 3. 결과 출력
```
## 로그 검색 결과

- 검색 소스: DB / ES
- 검색 조건: ...
- 검색 기간: ...
- 결과 건수: N건

### 주요 발견
1. ...
2. ...

### 상세 데이터
(테이블 또는 JSON 형태)
```

## 워크플로우

1. 사용자 요청에서 검색 대상, 시간 범위, 필터 조건 파악
2. `references/es-indices.md`를 참조하여 ES 인덱스 용도 확인
3. `references/db-log-tables.md`를 참조하여 DB 테이블 스키마 확인
4. `references/search-patterns.md`를 참조하여 자주 쓰는 검색 패턴 활용
5. 적절한 MCP 도구로 검색 실행
6. 결과를 분석하여 사용자에게 요약 제공

## 참조 문서

| 문서 | 용도 | 언제 읽는가 |
|------|------|-----------|
| `references/es-indices.md` | ES 인덱스 목록, 용도, 주요 필드 | ES 검색 대상 인덱스를 선택할 때 |
| `references/db-log-tables.md` | HTTP_LOG 등 DB 로그 테이블 스키마 | DB 로그 쿼리 작성할 때 |
| `references/search-patterns.md` | 자주 쓰는 검색 패턴 | 검색 쿼리를 작성할 때 |
