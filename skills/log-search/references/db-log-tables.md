# DB 로그 테이블 스키마

## HTTP_LOG

API 요청/응답 로그를 저장하는 테이블.

### 주요 컬럼 (예상 - 실제 스키마는 lane4-mysql MCP로 DESCRIBE HTTP_LOG 확인)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| ID | BIGINT | PK |
| REQUEST_URL | VARCHAR | 요청 URL |
| REQUEST_METHOD | VARCHAR | HTTP Method (GET/POST/PUT/DELETE) |
| REQUEST_BODY | TEXT | 요청 본문 |
| RESPONSE_STATUS | INT | HTTP 상태 코드 |
| RESPONSE_BODY | TEXT | 응답 본문 |
| REQUEST_IP | VARCHAR | 요청 IP |
| USER_AGENT | VARCHAR | User Agent |
| CREATED_AT | DATETIME | 생성일시 |
| DURATION_MS | INT | 응답 시간 (밀리초) |
| PROJECT | VARCHAR | 프로젝트명 |
| USER_ID | VARCHAR | 사용자 ID |

### 조회 팁
- 반드시 CREATED_AT 범위 조건 사용 (대용량 테이블)
- LIMIT 필수 (기본 100건)
- RESPONSE_STATUS로 에러 필터링 (4xx, 5xx)

> **참고**: 위 스키마는 예상 구조입니다. 최초 사용시 `DESCRIBE HTTP_LOG`로 실제 스키마를 확인하고 이 문서를 업데이트하세요.
