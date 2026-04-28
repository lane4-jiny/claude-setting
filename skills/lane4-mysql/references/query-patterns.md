# LANE4 자주 쓰는 쿼리 패턴

실제 운영에서 자주 요청되는 쿼리 유형별 패턴이다.
이 패턴을 기반으로 사용자 질문에 맞게 변형하여 사용한다.

> **최종 업데이트**: 2026-02-19 (실제 DB 컬럼명 검증 완료)

---

## 1. 배차 현황 조회

### 기본 배차 목록 (기간별)

```sql
SELECT
  a.ALLOC_ID,
  a.STATUS,
  a.ALLOC_DT,
  a.ALLOC_TIME,
  a.ALLOC_TYPE,
  cr.SERVICE_TYPE,
  cr.CALL_TP,
  cr.DEPARTURE_SHORT,
  cr.DESTINATION_SHORT,
  cr.SIMPLE_CALL_TYPE,
  d.DRV_NM,
  c.CAR_NO,
  cm.MODEL_NM
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  LEFT JOIN DRIVER d ON a.DRV_ID = d.DRV_ID
  LEFT JOIN CAR c ON a.CAR_ID = c.CAR_ID
  LEFT JOIN CAR_MODEL cm ON c.CAR_MODEL_ID = cm.CAR_MODEL_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS != '삭제'
ORDER BY a.ALLOC_DT DESC, a.ALLOC_TIME DESC
LIMIT 50;
```

### 배차 상태별 집계

```sql
SELECT
  a.STATUS,
  COUNT(*) AS cnt
FROM ALLOCATION a
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY a.STATUS
ORDER BY cnt DESC;
```

### 서비스 유형별 배차 현황

```sql
SELECT
  cr.SERVICE_TYPE,
  COUNT(*) AS cnt,
  SUM(CASE WHEN a.STATUS = '50' THEN 1 ELSE 0 END) AS completed,
  SUM(CASE WHEN a.STATUS = '55' THEN 1 ELSE 0 END) AS cancelled
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY cr.SERVICE_TYPE
ORDER BY cnt DESC;
```

---

## 2. 매출/요금 조회

### 기간별 매출 합계

```sql
SELECT
  SUM(fh.TOTAL_AMOUNT) AS total_revenue,
  SUM(fh.PAYMENT_AMOUNT) AS payment_revenue,
  SUM(fh.DISCOUNT_TOTAL_AMOUNT) AS total_discount,
  COUNT(*) AS trip_count,
  AVG(fh.TOTAL_AMOUNT) AS avg_fare
FROM FARE_HISTORY fh
  JOIN ALLOCATION a ON fh.ALLOCATION_ID = a.ALLOC_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50';
```

### 서비스 유형별 매출

```sql
SELECT
  fh.SERVICE_TYPE,
  SUM(fh.TOTAL_AMOUNT) AS total_revenue,
  SUM(fh.PAYMENT_AMOUNT) AS payment_revenue,
  COUNT(*) AS trip_count,
  AVG(fh.TOTAL_AMOUNT) AS avg_fare
FROM FARE_HISTORY fh
  JOIN ALLOCATION a ON fh.ALLOCATION_ID = a.ALLOC_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY fh.SERVICE_TYPE
ORDER BY total_revenue DESC;
```

### 일별 매출 추이

```sql
SELECT
  a.ALLOC_DT,
  SUM(fh.TOTAL_AMOUNT) AS daily_revenue,
  SUM(fh.PAYMENT_AMOUNT) AS daily_payment,
  COUNT(*) AS daily_trips
FROM FARE_HISTORY fh
  JOIN ALLOCATION a ON fh.ALLOCATION_ID = a.ALLOC_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY a.ALLOC_DT
ORDER BY a.ALLOC_DT;
```

### 매출 상세 항목별 분석

```sql
SELECT
  SUM(fh.DRIVING_AMOUNT) AS driving_total,
  SUM(fh.RESERVATION_AMOUNT) AS reservation_total,
  SUM(fh.TOLLGATE_AMOUNT) AS tollgate_total,
  SUM(fh.WAIT_AMOUNT) AS wait_total,
  SUM(fh.PARKING_AMOUNT) AS parking_total,
  SUM(fh.ADDITIONAL_AMOUNT) AS additional_total,
  SUM(fh.DISCOUNT_COUPON_AMOUNT) AS coupon_discount_total,
  SUM(fh.DISCOUNT_COMPANY_FIXED_AMOUNT) AS company_discount_total,
  SUM(fh.TOTAL_AMOUNT) AS grand_total
FROM FARE_HISTORY fh
  JOIN ALLOCATION a ON fh.ALLOCATION_ID = a.ALLOC_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50';
```

---

## 3. 법인별 실적 조회

### 법인별 배차 건수 및 매출

```sql
SELECT
  co.COMP_CD,
  co.COMP_NM,
  COUNT(a.ALLOC_ID) AS alloc_count,
  SUM(fh.TOTAL_AMOUNT) AS total_revenue,
  SUM(fh.PAYMENT_AMOUNT) AS payment_amount
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  JOIN COMP co ON cr.COMP_CD = co.COMP_CD
  LEFT JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY co.COMP_CD, co.COMP_NM
ORDER BY total_revenue DESC;
```

### 법인 + 부서별 이용 현황

```sql
SELECT
  co.COMP_NM,
  dept.name AS dept_nm,
  COUNT(a.ALLOC_ID) AS alloc_count,
  SUM(fh.TOTAL_AMOUNT) AS total_revenue
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  JOIN EMPLOYEE emp ON cr.EMPLOYEE_ID = emp.id
  JOIN COMP co ON emp.company_code = co.COMP_CD
  LEFT JOIN DEPARTMENT dept ON emp.department_id = dept.id
  LEFT JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY co.COMP_NM, dept.name
ORDER BY co.COMP_NM, alloc_count DESC;
```

### 법인별 서비스유형 Cross 분석

```sql
SELECT
  co.COMP_NM,
  cr.SERVICE_TYPE,
  COUNT(*) AS cnt,
  SUM(fh.TOTAL_AMOUNT) AS revenue
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
  JOIN COMP co ON cr.COMP_CD = co.COMP_CD
  LEFT JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY co.COMP_NM, cr.SERVICE_TYPE
ORDER BY co.COMP_NM, revenue DESC;
```

---

## 4. 기사 관련 조회

### 기사 스케줄 조회

```sql
SELECT
  ds.DS_ID,
  ds.WORK_DATE,
  ds.WORK_DT_S,
  ds.WORK_DT_E,
  ds.WORK_GROUP,
  d.DRV_NM,
  d.DRV_MOBILE,
  c.CAR_NO,
  cm.MODEL_NM
FROM DRIVER_SCHEDULE ds
  JOIN DRIVER d ON ds.DRV_ID = d.DRV_ID
  LEFT JOIN CAR c ON ds.CAR_ID = c.CAR_ID
  LEFT JOIN CAR_MODEL cm ON c.CAR_MODEL_ID = cm.CAR_MODEL_ID
WHERE ds.WORK_DATE = '2026-02-19'
ORDER BY d.DRV_NM;
```

### 기사별 운행 실적

```sql
SELECT
  d.DRV_ID,
  d.DRV_NM,
  COUNT(a.ALLOC_ID) AS trip_count,
  SUM(fh.TOTAL_AMOUNT) AS total_revenue,
  AVG(fh.TOTAL_AMOUNT) AS avg_fare
FROM ALLOCATION a
  JOIN DRIVER d ON a.DRV_ID = d.DRV_ID
  LEFT JOIN FARE_HISTORY fh ON a.ALLOC_ID = fh.ALLOCATION_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS = '50'
GROUP BY d.DRV_ID, d.DRV_NM
ORDER BY trip_count DESC
LIMIT 20;
```

### 기사 근무 상태 현황

```sql
SELECT
  d.WORK_STATUS,
  d.COMMUTE_STATUS,
  d.CALL_STATUS,
  COUNT(*) AS cnt
FROM DRIVER d
WHERE d.STATUS = '정상'
GROUP BY d.WORK_STATUS, d.COMMUTE_STATUS, d.CALL_STATUS
ORDER BY cnt DESC;
```

### 기사별 월간 근무일수/근무시간

```sql
SELECT
  d.DRV_NM,
  COUNT(DISTINCT ds.WORK_DATE) AS work_days,
  SUM(ds.WORK_TIME) AS total_work_min,
  SUM(ds.REST_TIME) AS total_rest_min
FROM DRIVER_SCHEDULE ds
  JOIN DRIVER d ON ds.DRV_ID = d.DRV_ID
WHERE ds.WORK_DATE BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY d.DRV_ID, d.DRV_NM
ORDER BY work_days DESC;
```

---

## 5. 쿠폰 사용 현황

```sql
SELECT
  cp.CPN_NM,
  cp.DISCOUNT_TYPE,
  cp.DISCOUNT_AMT,
  cp.DISCOUNT_RATE,
  COUNT(pub.CPN_PUB_ID) AS published_count,
  SUM(CASE WHEN pub.USE_YN = 'Y' THEN 1 ELSE 0 END) AS used_count,
  SUM(pub.USE_AMOUNT) AS total_discount_used
FROM CPN cp
  LEFT JOIN CPN_PUB pub ON cp.CPN_ID = pub.CPN_ID
WHERE cp.STATUS = '정상'
GROUP BY cp.CPN_ID, cp.CPN_NM, cp.DISCOUNT_TYPE, cp.DISCOUNT_AMT, cp.DISCOUNT_RATE
ORDER BY published_count DESC;
```

---

## 6. 결제 조회

### 기간별 결제 내역

```sql
SELECT
  pt.PAY_TRX_ID,
  pt.PAY_TP,
  pt.TOT_AMT,
  pt.DISC_AMT,
  pt.REAL_PAY_AMT,
  pt.PAY_DT,
  a.ALLOC_DT,
  cr.DEPARTURE_SHORT,
  cr.DESTINATION_SHORT
FROM PAY_TRX pt
  JOIN ALLOCATION a ON pt.ALLOC_ID = a.ALLOC_ID
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND pt.STATUS = '정상'
ORDER BY pt.PAY_DT DESC
LIMIT 50;
```

### 결제 합계

```sql
SELECT
  COUNT(*) AS pay_count,
  SUM(pt.TOT_AMT) AS total_amount,
  SUM(pt.DISC_AMT) AS total_discount,
  SUM(pt.REAL_PAY_AMT) AS total_paid,
  SUM(pt.VAT) AS total_vat
FROM PAY_TRX pt
  JOIN ALLOCATION a ON pt.ALLOC_ID = a.ALLOC_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND pt.STATUS = '정상';
```

---

## 7. 취소/미탑승 분석

```sql
SELECT
  a.STATUS,
  a.CANCEL_REASON,
  cr.SERVICE_TYPE,
  COUNT(*) AS cnt
FROM ALLOCATION a
  JOIN CALL_REQ cr ON a.CALL_ID = cr.CALL_ID
WHERE a.ALLOC_DT BETWEEN '2026-01-01' AND '2026-01-31'
  AND a.STATUS IN ('55', '50N')
GROUP BY a.STATUS, a.CANCEL_REASON, cr.SERVICE_TYPE
ORDER BY cnt DESC
LIMIT 20;
```

---

## 8. 유틸리티 쿼리

### 공통코드 조회

```sql
SELECT cg.GRP_CD, cg.GRP_CD_NM, cd.DTL_CD, cd.DTL_CD_NM, cd.VAL1, cd.VAL2
FROM CD_GRP cg
  JOIN CD_DTL cd ON cg.GRP_CD = cd.GRP_CD
WHERE cg.GRP_CD = '{코드그룹}'
  AND cd.STATUS = '정상'
ORDER BY cd.DTL_ORDER;
```

### 테이블 스키마 빠른 확인

```sql
SHOW COLUMNS FROM {테이블명};
```

### 테이블 데이터 건수 확인

```sql
SELECT COUNT(*) FROM {테이블명};
```

---

## 쿼리 작성 팁

1. **날짜 필터**: `ALLOC_DT`(date형)는 문자열 비교 가능. `REG_DT`(datetime형)는 DATE() 함수 사용
2. **대용량 조회**: 항상 LIMIT 붙이기. 집계가 목적이면 COUNT/SUM 먼저 실행
3. **NULL 처리**: 배차 확정 전 DRV_ID, CAR_ID는 NULL → COALESCE 또는 LEFT JOIN 사용
4. **법인 필터**: `COMP_CD`로 직접 필터링하거나, `COMP_NM LIKE '%법인명%'`으로 검색
5. **FK 컬럼명 불일치**: FARE_HISTORY 조인 시 `a.ALLOC_ID = fh.ALLOCATION_ID` 주의
6. **EMPLOYEE 조인**: `cr.EMPLOYEE_ID = emp.id` (emp.EMPLOYEE_ID 아님)
7. **상태 필터**: 대부분의 테이블은 `STATUS = '정상'`이 활성 데이터 조건
8. **금액 컬럼명**: FARE_HISTORY는 `*_AMOUNT` 패턴, ALLOCATION/PAY_TRX는 `*_AMT` 패턴
