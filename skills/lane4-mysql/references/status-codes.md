# LANE4 상태값 / Enum / 공통코드 레퍼런스

쿼리에서 WHERE 조건이나 CASE 문에 자주 사용되는 상태값과 enum 목록이다.

> **최종 업데이트**: 2026-02-19 (실제 DB 데이터 분포 기반)

---

## ALLOCATION (배차) 상태

배차의 라이프사이클을 나타내는 핵심 상태값. **Default: `정상`**

| STATUS | 설명 | 비고 | 실데이터 비중 |
|--------|------|------|-------------|
| `00` | 결제 전 | 초기 상태 | 0.15% |
| `정상` | 출발 전 | 배차 확정 (= NORMAL) | 6.08% |
| `10` | 기사 출발 | | 극소 |
| `20` | 출발지 도착 | | 극소 |
| `30` | 고객 탑승 | | 극소 |
| `40S` | 결제 성공 | | 극소 |
| `50` | 운행 완료 | **정상 종료** | **77.33%** |
| `55` | 고객 취소 | | 13.94% |
| `50N` | 미탑승 | No-show | 2.52% |
| `삭제` | 삭제 | 소프트 삭제 | 극소 |

**자주 쓰는 필터:**

```sql
-- 운행 완료건만
WHERE a.STATUS = '50'

-- 진행중 (배차 확정 ~ 탑승)
WHERE a.STATUS IN ('정상', '10', '20', '30')

-- 취소/미탑승
WHERE a.STATUS IN ('55', '50N')

-- 유효 배차 (삭제 제외)
WHERE a.STATUS != '삭제'

-- 결제 관련
WHERE a.STATUS IN ('40S', '50')
```

### ALLOCATION.ALLOC_TYPE (배차 유형)

| ALLOC_TYPE | 설명 | 비중 |
|------------|------|------|
| `구독` | 구독 배차 | **97.8%** |
| `일반` | 일반 배차 (Default) | 2.2% |

### ALLOCATION.EK_STATUS (에미레이트 상태)

| EK_STATUS | 설명 |
|-----------|------|
| `NORMAL` | 정상 |
| `HOLD` | 보류 |

---

## CALL_REQ (호출 요청)

### STATUS

| STATUS | 설명 |
|--------|------|
| `정상` | 정상 (99.99%) |
| `삭제` | 삭제 |

### SERVICE_TYPE (서비스 유형) - 핵심 분류

| SERVICE_TYPE | 설명 | 비중 |
|--------------|------|------|
| `AIR` | 공항 | **51.8%** |
| `ONEWAY` | 편도 | 32.3% |
| `SECTION` | 구간 | 8.7% |
| `RENT` | 렌트 | 2.0% |
| `ETC` | 기타 (배차) | 1.7% |
| `TWOWAY` | 왕복 | 0.9% |
| `GOLF` | 골프 | 0.3% |
| `SHUTTLE` | 셔틀 | 0.1% |
| NULL | 미분류 (레거시) | 2.2% |

### CALL_TP (호출 타입)

| CALL_TP | 설명 | 비중 |
|---------|------|------|
| `대절` | 대절 | **53.2%** |
| `예약` | 예약 | 45.3% |
| `실시간` | 즉시 호출 | 1.3% |
| (빈문자열) | 미분류 | 0.1% |

### SUB_TYPE (서비스 서브유형)

| SUB_TYPE | 설명 | 비고 |
|----------|------|------|
| `departure` | 출발 (공항 -> 목적지) | AIR 서비스에서 사용 |
| `arrival` | 도착 (출발지 -> 공항) | AIR 서비스에서 사용 |
| `DISPATCH` | 배차 | ETC 서비스에서 사용 |
| (빈문자열) | 미분류 | |

### rent_type (렌트 유형)

| rent_type | 설명 |
|-----------|------|
| `AIR` | 공항 렌트 |
| `GOLF` | 골프 렌트 |

### COMPANY_PAYMENT_TYPE (결제 유형)

| 값 | 설명 | 비중 |
|----|------|------|
| `COMPANY_PAYMENT` | 법인 정산 (후불) | **99.7%** |
| `CUSTOMER_PAYMENT` | 고객 결제 (선불) | 0.3% |
| `ON_SITE_PAYMENT` | 현장 결제 | 극소 |

### PASSENGER_TYPE (탑승자 유형)

| 값 | 설명 |
|----|------|
| `SELF` | 본인 탑승 |
| `OTHER` | 타인 탑승 (대리 호출) |

### PROJECT_TYPE (호출 채널)

| 값 | 설명 | 비중 |
|----|------|------|
| `PARTNER` | 파트너 | **88.9%** |
| `PARSING` | 파싱 (자동) | 7.6% |
| `ADMIN` | 관리자 | 1.8% |
| `USER` | 사용자 앱 | 1.2% |
| `GUEST` | 게스트 | 0.4% |
| `DRIVER` | 기사 앱 | 극소 |

### SIMPLE_CALL_TYPE (호출 유형)

| 값 | 설명 |
|----|------|
| `IMMEDIATE` | 즉시 호출 |
| `SCHEDULED` | 예약 호출 |

---

## DRIVER (기사) 상태

### STATUS

| STATUS | 설명 | 건수 |
|--------|------|------|
| `정상` | 정상 | 1,122 |
| `삭제` | 삭제 | 883 |
| `중지` | 중지 | 20 |

### WORK_STATUS (근무 상태)

| WORK_STATUS | 설명 | 건수 |
|-------------|------|------|
| `TAKEOVER_BEFORE` | 인수 전 (Default) | 1,236 |
| `END_WORK` | 근무 종료 | 390 |
| `CALL_COMMUTE` | 콜 출퇴근 | 316 |
| `CALL_STOP` | 콜 중지 | 65 |
| `BEGIN_WORK` | 근무 시작 | 12 |
| `TAKEOVER_AFTER` | 인수 후 | 6 |

### COMMUTE_STATUS (출퇴근 상태)

| COMMUTE_STATUS | 설명 |
|----------------|------|
| `Y` | 출근 |
| `N` | 퇴근 (Default) |

### CALL_STATUS (콜 수신 상태)

| CALL_STATUS | 설명 |
|-------------|------|
| `Y` | 콜 수신 중 |
| `N` | 콜 미수신 (Default) |

### SELECTED_MAP (선택 지도앱)

| 값 | 설명 |
|----|------|
| `UNSELECTED` | 미선택 (Default) |
| `NAVER` | 네이버 지도 |
| `KAKAO` | 카카오맵 |
| `TMAP` | 티맵 |

### MESSENGER_TYPE (메신저 유형)

| 값 | 설명 |
|----|------|
| `WECHAT` | 위챗 |
| `WHATSAPP` | 왓츠앱 |
| `LINE` | 라인 |
| `KAKAOTALK` | 카카오톡 |

---

## CAR (차량) 상태

| STATUS | 설명 | 건수 |
|--------|------|------|
| `정상` | 정상 | 996 |
| `삭제` | 삭제 | 158 |
| `종료` | 종료 | 2 |
| `점검` | 점검 | 1 |

---

## COMP (법인) 상태

| STATUS | 설명 | 건수 |
|--------|------|------|
| `정상` | 정상 | 136 |
| `중지` | 중지 | 98 |
| `삭제` | 삭제 | 14 |

---

## FARE_HISTORY (요금 내역)

### SERVICE_TYPE

CALL_REQ.SERVICE_TYPE과 동일한 enum. 실제 분포:

| SERVICE_TYPE | 건수 |
|--------------|------|
| `AIR` | 80,517 |
| `ONEWAY` | 50,801 |
| `SECTION` | 22,082 |
| `RENT` | 4,295 |
| `GOLF` | 308 |

### PRICING_TYPE (요금 산정 유형)

| 값 | 설명 |
|----|------|
| `PLAN_BASED` | 요금제 기반 |
| `CUSTOM_INPUT` | 수동 입력 |
| NULL | 레거시 (대다수) |

---

## PAY_TRX (결제 트랜잭션)

### STATUS

| STATUS | 설명 |
|--------|------|
| `정상` | 정상 (현재 유일 값) |

### PAYMENT_TYPE

| 값 | 설명 |
|----|------|
| `TOSS_PAYMENTS_PAYPAL` | 토스 페이먼츠 페이팔 |

---

## CPN (쿠폰) 관련

### DISCOUNT_TYPE

| 값 | 설명 |
|----|------|
| `RATE` | 정률 (%) |
| `FIXED` | 정액 (원) - Default |

### IS_FIRST_COME_FIRST_SERVED

| 값 | 설명 |
|----|------|
| `Y` | 선착순 |
| `N` | 일반 (Default) |

---

## CLIENT (클라이언트) 유형

| TYPE | 설명 |
|------|------|
| `CALLER` | 호출자 |
| `SMS_RECEIVER` | SMS 수신자 |
| `MANAGER` | 관리자 |
| `PASSENGER` | 탑승자 |

---

## FARE (요금) 관련

### CAR_TYPE (차량 유형)

| 값 | 설명 |
|----|------|
| `RESIDENTIAL` | 상주 |
| `NON_RESIDENTIAL` | 비상주 |
| `EXTERNAL` | 외부 |

---

## EMPLOYEE (임직원) 역할

| role | 설명 |
|------|------|
| `MASTER` | 마스터 관리자 |
| `COMPANY_MASTER` | 법인 마스터 |
| `COMPANY_ADMIN` | 법인 관리자 |
| `COMPANY_USER` | 법인 사용자 |
| `USER` | 일반 사용자 |

---

## 공통 상태 패턴

LANE4 DB의 대부분 테이블은 아래 상태값을 공유한다:

| STATUS | 설명 | 비고 |
|--------|------|------|
| `정상` | 정상/활성 | 대부분의 테이블 Default |
| `삭제` | 소프트 삭제 | 물리 삭제하지 않음 |
| `중지` | 일시 중지 | DRIVER, COMP에서 사용 |

> **주의**: ALLOCATION만 숫자 코드(`00`, `10`, `20`...)를 사용하고, 나머지는 한글 상태값(`정상`, `삭제`)을 사용한다. ALLOCATION의 `정상`은 배차 확정 상태(=출발 전)를 의미한다.

---

## 공통코드 그룹 (CD_GRP)

자주 사용되는 공통코드 그룹 목록. 상세값은 CD_DTL 테이블에서 조회한다.

| GRP_CD | GRP_CD_NM | 용도 |
|--------|-----------|------|
| `AIRPORT_TYPE` | 공항종류 | 공항 서비스 필터 |
| `CAR_BRAND` | 차량브랜드 | 차량 정보 |
| `CAR_MODEL` | 차량종류 | 차종 분류 |
| `CAR_TYPE` | 차종 | 차종 분류 |
| `CALL_CANCEL_REASON` | 호출취소사유 | 취소 사유 코드 |
| `CHANNEL` | 채널 | 유입 채널 |
| `CHARTER_TYPE` | 대절 타입 | 대절 유형 분류 |
| `CPN_TP` | 쿠폰타입 | 쿠폰 분류 |
| `DRIVER_COMP` | 기사업체 | 기사 소속 업체 |
| `EMP_STATUS` | 임직원상태 | 임직원 상태 코드 |
| `FLUCT_RATE` | 변동율 | 요금 변동 |
| `LEAVE_REASON` | 회원탈퇴사유 | 탈퇴 분류 |
| `PAY_TYPE` | 결제방법 | 결제 수단 분류 |
| `POSITION` | 직위 | 임직원 직위 |
| `RENT_COMP` | 렌트카업체 | 렌터카 업체 |
| `STATUS_TYPE` | 처리상태 | 범용 상태 |

**공통코드 조회 쿼리:**

```sql
-- 특정 코드그룹의 상세코드 목록 조회
SELECT cd.DTL_CD, cd.DTL_CD_NM, cd.VAL1, cd.VAL2
FROM CD_DTL cd
  JOIN CD_GRP cg ON cd.GRP_CD = cg.GRP_CD
WHERE cg.GRP_CD = '{코드그룹}'
  AND cd.STATUS = '정상'
ORDER BY cd.DTL_ORDER;
```
