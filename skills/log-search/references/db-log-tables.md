# DB 로그 테이블 스키마

## HTTP_LOG

API 요청/응답/에러 로그를 저장하는 테이블. (실제 스키마 기준 — 2026-07-01 `DESCRIBE HTTP_LOG` 확인)

### 컬럼

| 컬럼 | 타입 | 설명 |
|------|------|------|
| ID | BIGINT (PK, auto_increment) | PK |
| LOG_TYPE | enum('REQUEST','RESPONSE','ERROR','TMAP') | 로그 종류 — 에러는 `'ERROR'` 로 구분 |
| LOG_LEVEL | enum('LOW','MIDDLE','HIGH') | 로그 레벨 |
| METHOD | varchar(10) | HTTP Method (GET/POST/PUT/PATCH/DELETE) |
| ENDPOINT | varchar(50) | 요청 경로 (예: `/allocations/471496/next`) — 50자 제한 |
| QUERY | varchar(1000) | 쿼리스트링 |
| BODY | text | 요청/응답 본문. 에러 응답도 여기에 저장 (envelope `{"result":false,"code":400,"data":{"message":"..."}}`) |
| DATA | varchar(1000) | 부가 데이터 (에러 로그에서는 보통 NULL) |
| PROJECT | enum('PARTNER','GUEST','USER','DRIVER','ADMIN','MONITORING') | 프로젝트 구분 (INDEX) |
| IP | varchar(50) | 요청 IP |
| ACCOUNT | varchar(20) | 계정 (예: `정현식(1428)`, INDEX). 미인증(401)이면 NULL |
| CREATED_AT | datetime (DEFAULT CURRENT_TIMESTAMP) | 생성일시 |
| PAIR_KEY | varchar(50) | REQUEST↔RESPONSE↔ERROR 로그를 묶는 키 (INDEX) |

### 조회 팁

- 반드시 `CREATED_AT` 범위 조건 사용 (대용량 테이블)
- LIMIT 필수 (기본 100건)
- **에러 필터링은 `RESPONSE_STATUS` 컬럼이 없다.** `LOG_TYPE = 'ERROR'` 로 거른 뒤 `BODY` 안의 `"code":4xx/5xx` 로 상태코드를 판별한다.
- HTTP 상태코드 추출 예: `BODY LIKE '%"code":500%'`
- 에러 메시지 추출 예: `SUBSTRING_INDEX(SUBSTRING_INDEX(BODY, '"message":"', -1), '"', 1)`
- 하나의 요청은 `PAIR_KEY` 로 REQUEST/RESPONSE(또는 ERROR) 로그가 짝지어짐
- `ENDPOINT` 는 50자로 잘리므로 긴 경로는 truncate 될 수 있음
- 개인정보(ACCOUNT 이름, BODY 내 전화번호 등)는 결과 출력 시 마스킹

### 자주 쓰는 쿼리

```sql
-- 특정 프로젝트 최근 에러 상태코드 분포
SELECT
  CASE
    WHEN BODY LIKE '%"code":400%' THEN '400'
    WHEN BODY LIKE '%"code":401%' THEN '401'
    WHEN BODY LIKE '%"code":500%' THEN '500'
    ELSE 'other'
  END AS code_bucket,
  COUNT(*) AS cnt
FROM HTTP_LOG
WHERE PROJECT = 'DRIVER' AND LOG_TYPE = 'ERROR'
  AND CREATED_AT >= NOW() - INTERVAL 6 HOUR
GROUP BY code_bucket ORDER BY cnt DESC;

-- 미처리 예외(500)/스택트레이스 탐지 (배포 회귀 점검)
SELECT ENDPOINT, LEFT(BODY,600) AS body, CREATED_AT, ACCOUNT
FROM HTTP_LOG
WHERE PROJECT = 'DRIVER' AND LOG_TYPE = 'ERROR'
  AND CREATED_AT >= NOW() - INTERVAL 6 HOUR
  AND (BODY LIKE '%"code":500%' OR BODY LIKE '%TypeError%'
       OR BODY LIKE '%Cannot read%' OR BODY NOT LIKE '%"result":%')
ORDER BY CREATED_AT DESC LIMIT 20;
```
