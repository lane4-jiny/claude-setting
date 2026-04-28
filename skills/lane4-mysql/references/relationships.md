# LANE4 테이블 관계 및 JOIN 가이드

> **최종 업데이트**: 2026-02-19 (실제 DB 스키마 검증 완료)

## 핵심 관계도 (중심: ALLOCATION)

ALLOCATION(배차)이 LANE4 DB의 중심 엔티티다. 대부분의 비즈니스 조회는 ALLOCATION을 기준으로 JOIN한다.

```
CALL_REQ ──(CALL_ID)──▶ ALLOCATION ──(ALLOC_ID = ALLOCATION_ID)──▶ FARE_HISTORY
                                    ──(ALLOC_ID)──────────────────▶ PAY_TRX
                                    ──(DRV_ID)────────────────────▶ DRIVER
                                    ──(CAR_ID)────────────────────▶ CAR ──(CAR_MODEL_ID)──▶ CAR_MODEL
                                    ──(CPN_PUB_ID)────────────────▶ CPN_PUB ──(CPN_ID)──▶ CPN

CALL_REQ ──(USER_ID)────────▶ SVC_USER ──(COMP_CD)──▶ COMP
CALL_REQ ──(EMPLOYEE_ID = id)▶ EMPLOYEE ──(department_id = id)──▶ DEPARTMENT
CALL_REQ ──(COMP_CD)─────────▶ COMP
CALL_REQ ──(CARD_ID)─────────▶ CREDIT_CARD

DRIVER ──(COMP_CD)──▶ COMP
DRIVER_SCHEDULE ──(DRV_ID)──▶ DRIVER
                ──(CAR_ID)──▶ CAR

WHITE_LIST ◀──(WHITE_LIST_ID)── REGION
COMP ◀──(COMP_CD)── COMP_WHITE_LIST ──(WHITE_LIST_ID)──▶ WHITE_LIST

CD_DTL ──(GRP_CD)──▶ CD_GRP
```

## 네이밍 불일치 주의사항

**JOIN 시 반드시 확인해야 할 컬럼명 불일치:**

| 관계 | 원본 테이블 | FK 컬럼 | 대상 테이블 | PK 컬럼 | 주의 |
|------|-----------|---------|-----------|---------|------|
| 배차→요금내역 | ALLOCATION | `ALLOC_ID` | FARE_HISTORY | `ALLOCATION_ID` | **컬럼명 다름!** |
| 호출→임직원 | CALL_REQ | `EMPLOYEE_ID` | EMPLOYEE | `id` | EMPLOYEE PK가 `id` |
| 호출→부서 | CALL_REQ | `department_id` | DEPARTMENT | `id` | 양쪽 모두 소문자 |
| 임직원→부서 | EMPLOYEE | `department_id` | DEPARTMENT | `id` | 양쪽 모두 소문자 |
| 임직원→법인 | EMPLOYEE | `company_code` | COMP | `COMP_CD` | **컬럼명 다름!** |
| 부서→법인 | DEPARTMENT | `company_code` | COMP | `COMP_CD` | **컬럼명 다름!** |
| 요금내역→법인 | FARE_HISTORY | `COMPANY_CODE` | COMP | `COMP_CD` | **컬럼명 다름!** |
| 클라이언트→법인 | CLIENT | `COMPANY_CODE` | COMP | `COMP_CD` | **컬럼명 다름!** |
| 클라이언트→임직원 | CLIENT | `EMPLOYEE_ID` | EMPLOYEE | `id` | EMPLOYEE PK가 `id` |

---

## 주요 JOIN 경로

### 1. 배차 + 호출 + 기사 + 차량 (배차 현황 조회)

가장 빈번하게 사용되는 JOIN 패턴.

```sql
SELECT a.*, cr.*, d.DRV_NM, c.CAR_NO, cm.MODEL_NM
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  LEFT JOIN DRIVER d ON a.DRV_ID = d.DRV_ID
  LEFT JOIN CAR c ON a.CAR_ID = c.CAR_ID
  LEFT JOIN CAR_MODEL cm ON c.CAR_MODEL_ID = cm.CAR_MODEL_ID
```

### 2. 배차 + 요금내역 (매출 조회)

**주의**: FARE_HISTORY의 FK는 `ALLOCATION_ID` (ALLOC_ID 아님)

```sql
SELECT a.ALLOC_ID, a.STATUS, fh.*
FROM ALLOCATION a
  JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
```

### 3. 배차 + 결제 (결제 조회)

PAY_TRX는 ALLOC_ID와 CALL_ID 모두 보유.

```sql
SELECT a.ALLOC_ID, pt.*
FROM ALLOCATION a
  JOIN PAY_TRX pt ON a.ALLOC_ID = pt.ALLOC_ID
```

### 4. 호출 + 법인 + 부서 (법인별 조회)

CALL_REQ에 COMP_CD가 직접 있으므로, 법인 필터만 필요하면 EMPLOYEE JOIN 불필요.

```sql
-- 방법 1: CALL_REQ.COMP_CD 직접 사용 (간편)
SELECT co.COMP_NM, cr.*
FROM CALL_REQ cr
  JOIN COMP co ON cr.COMP_CD = co.COMP_CD

-- 방법 2: EMPLOYEE를 통한 상세 조회 (부서 정보 필요 시)
SELECT co.COMP_NM, dept.name AS dept_nm, emp.name AS emp_nm, cr.*
FROM CALL_REQ cr
  JOIN EMPLOYEE emp ON cr.EMPLOYEE_ID = emp.id
  JOIN COMP co ON emp.company_code = co.COMP_CD
  LEFT JOIN DEPARTMENT dept ON emp.department_id = dept.id
```

### 5. 기사 스케줄 + 기사 + 차량

**주의**: DRIVER_SCHEDULE의 날짜 컬럼은 `WORK_DATE` (SCHEDULE_DT 아님)

```sql
SELECT ds.*, d.DRV_NM, d.DRV_MOBILE, c.CAR_NO, cm.MODEL_NM
FROM DRIVER_SCHEDULE ds
  JOIN DRIVER d ON ds.DRV_ID = d.DRV_ID
  LEFT JOIN CAR c ON ds.CAR_ID = c.CAR_ID
  LEFT JOIN CAR_MODEL cm ON c.CAR_MODEL_ID = cm.CAR_MODEL_ID
WHERE ds.WORK_DATE = '2026-02-19'
ORDER BY d.DRV_NM
```

### 6. 쿠폰 발행 + 쿠폰 정책

```sql
SELECT cp.CPN_NM, cp.DISCOUNT_TYPE, cp.DISCOUNT_AMT, cp.DISCOUNT_RATE, pub.*
FROM CPN_PUB pub
  JOIN CPN cp ON pub.CPN_ID = cp.CPN_ID
```

### 7. 법인 + 서비스 지역

```sql
SELECT co.COMP_NM, wl.*
FROM COMP co
  JOIN COMP_WHITE_LIST cwl ON co.COMP_CD = cwl.COMP_CD
  JOIN WHITE_LIST wl ON cwl.WHITE_LIST_ID = wl.WHITE_LIST_ID
```

### 8. 공통코드 조회

**주의**: CD_DTL의 컬럼명은 `DTL_CD`, `DTL_CD_NM`, `DTL_ORDER` (CD, CD_NM, SORT_ORDER 아님)

```sql
SELECT cg.GRP_CD, cg.GRP_CD_NM, cd.DTL_CD, cd.DTL_CD_NM
FROM CD_GRP cg
  JOIN CD_DTL cd ON cg.GRP_CD = cd.GRP_CD
WHERE cg.GRP_CD = '{코드그룹}'
  AND cd.STATUS = '정상'
ORDER BY cd.DTL_ORDER
```

### 9. 배차 + 호출 + 요금내역 + 법인 (종합 매출 조회)

여러 테이블을 결합하는 복합 JOIN.

```sql
SELECT
  co.COMP_NM,
  cr.SERVICE_TYPE,
  a.ALLOC_DT,
  fh.TOTAL_AMOUNT,
  fh.PAYMENT_AMOUNT,
  d.DRV_NM
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
  LEFT JOIN COMP co ON cr.COMP_CD = co.COMP_CD
  LEFT JOIN DRIVER d ON a.DRV_ID = d.DRV_ID
WHERE a.STATUS = '50'
  AND a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
```

---

## JOIN 시 주의사항

1. **ALLOCATION ↔ DRIVER, CAR**: 배차 확정 전에는 NULL → **LEFT JOIN** 필수
2. **CALL_REQ ↔ EMPLOYEE**: 개인 고객(비법인)일 경우 NULL → **LEFT JOIN** 사용
3. **FARE_HISTORY**: 배차 완료(`STATUS = '50'`) 후에만 생성 → 미완료 배차는 JOIN 결과 없음
4. **COMP_CD 네이밍 불일치**: 테이블마다 `COMP_CD`, `company_code`, `COMPANY_CODE`로 다름
5. **ALLOCATION↔FARE_HISTORY FK 불일치**: `ALLOC_ID` = `ALLOCATION_ID`
6. **EMPLOYEE PK**: `id` (int, auto_increment) - 다른 테이블에서 `EMPLOYEE_ID`로 참조
7. **DEPARTMENT PK**: `id` - 다른 테이블에서 `department_id`로 참조
8. **STATUS 조건**: 대부분의 테이블에서 `STATUS = '정상'`으로 활성 데이터 필터링 필요
