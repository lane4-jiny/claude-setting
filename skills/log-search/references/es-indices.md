# Elasticsearch 인덱스 목록

> **참고**: 이 문서는 elasticsearch MCP의 `list_indices`로 조회한 결과로 채워야 합니다.
> 최초 사용시 아래 명령으로 인덱스 목록을 확인하고 업데이트하세요.

## 인덱스 목록

(elasticsearch MCP `list_indices`로 조회 후 채울 것)

### 예상 인덱스 구조

| 인덱스 패턴 | 용도 | 주요 필드 |
|-------------|------|-----------|
| driver-location-* | 기사 위치 데이터 | driver_id, lat, lng, timestamp |
| allocation-route-* | 배차 실경로 | allocation_id, coordinates, timestamp |
| allocation-status-* | 배차 상태 변경 이력 | allocation_id, status, changed_at |
| app-log-* | 앱 로그 | level, message, timestamp, project |
| error-log-* | 에러 로그 | level, error_message, stack_trace, timestamp |

## 인덱스 조회 방법

1. 전체 인덱스 목록: `list_indices` 도구 사용
2. 인덱스 필드 구조: `get_mappings` 도구로 매핑 확인
3. 데이터 검색: `search` 또는 `esql` 도구 사용

## 시간 기반 인덱스

- 대부분의 로그 인덱스는 날짜별로 생성됨 (예: `app-log-2024.01.15`)
- 검색시 날짜 범위에 해당하는 인덱스 패턴 사용
- 와일드카드 패턴 지원 (예: `app-log-2024.01.*`)
