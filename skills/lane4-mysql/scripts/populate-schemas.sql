-- LANE4 핵심 테이블 스키마 조회 스크립트
-- Claude Code에서 lane4-mysql MCP를 통해 실행하여 core-schemas.md를 업데이트한다.

-- 1. 핵심 테이블 목록 확인
SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
                     'ALLOCATION', 'CALL_REQ', 'DRIVER', 'DRIVER_SCHEDULE',
                     'CAR', 'CAR_MODEL', 'COMP', 'EMPLOYEE', 'DEPARTMENT',
                     'SVC_USER', 'CLIENT', 'CUSTOMER',
                     'FARE', 'FARE_HISTORY', 'PAY_TRX',
                     'CPN', 'CPN_PUB',
                     'WHITE_LIST', 'REGION',
                     'CD_GRP', 'CD_DTL'
    )
ORDER BY TABLE_NAME;

-- 2. 핵심 테이블 컬럼 상세 (한 번에 조회)
SELECT TABLE_NAME,
       COLUMN_NAME,
       COLUMN_TYPE,
       COLUMN_KEY,
       IS_NULLABLE,
       COLUMN_DEFAULT,
       COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
                     'ALLOCATION', 'CALL_REQ', 'DRIVER', 'DRIVER_SCHEDULE',
                     'CAR', 'CAR_MODEL', 'COMP', 'EMPLOYEE', 'DEPARTMENT',
                     'SVC_USER', 'CLIENT', 'CUSTOMER',
                     'FARE', 'FARE_HISTORY', 'PAY_TRX',
                     'CPN', 'CPN_PUB',
                     'WHITE_LIST', 'REGION',
                     'CD_GRP', 'CD_DTL'
    )
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- 3. FK 관계 조회
SELECT TABLE_NAME,
       COLUMN_NAME,
       REFERENCED_TABLE_NAME,
       REFERENCED_COLUMN_NAME,
       CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND TABLE_NAME IN (
                     'ALLOCATION', 'CALL_REQ', 'DRIVER', 'DRIVER_SCHEDULE',
                     'CAR', 'CAR_MODEL', 'COMP', 'EMPLOYEE', 'DEPARTMENT',
                     'SVC_USER', 'CLIENT', 'CUSTOMER',
                     'FARE', 'FARE_HISTORY', 'PAY_TRX',
                     'CPN', 'CPN_PUB',
                     'WHITE_LIST', 'REGION',
                     'CD_GRP', 'CD_DTL'
    )
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 4. 자주 쓰는 공통코드 그룹 조회
SELECT GRP_CD, GRP_NM
FROM CD_GRP
WHERE USE_YN = 'Y'
ORDER BY GRP_CD LIMIT 50;
