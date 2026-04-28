# LANE4 도메인별 테이블 맵

LANE4 DB의 180개+ 테이블 중 핵심 비즈니스 테이블을 도메인별로 분류한다.
로그/아카이브 테이블은 제외한다.

> **최종 업데이트**: 2026-02-19

---

## 배차 (Allocation) - 핵심 도메인

배차 생성~완료까지의 전체 라이프사이클을 관리하는 핵심 도메인.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| ALLOCATION | ALLOC_ID (int) | 배차 메인 (중심 엔티티) | 모든 조회의 기준 |
| ALLOCATION_HISTORY | | 배차 상태 변경 이력 | |
| ALLOCATION_NOTIFICATION | | 배차 알림 | |
| ALLOC_STATUS_HIST | | 배차 상태 히스토리 | |
| ALLOC_TARGET | | 배차 대상 | |

## 호출/예약 (Reservation)

고객의 호출 요청 및 예상 요금 정보.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| CALL_REQ | CALL_ID (int) | 호출 요청 (배차의 시작점) | SERVICE_TYPE으로 유형 구분 |
| CALL_EXP_FARE | | 호출 예상 요금 | |
| CALL_MEMO | | 호출 메모 | |

## 차량 (Car)

차량 정보 및 점검 이력.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| CAR | CAR_ID (int) | 차량 기본 정보 | |
| CAR_MODEL | CAR_MODEL_ID (int) | 차종 정보 | BRAND, MODEL_NM |
| CAR_HISTORY | | 차량 변경 이력 | |
| CAR_INSPECTION | | 차량 점검 | |
| CAR_INSPECTION_IMAGE | | 차량 점검 이미지 | |
| CAR_ALIAS | | 차량 별칭 | |

## 기사 (Driver)

기사 정보, 스케줄, 근무 이력.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| DRIVER | DRV_ID (int) | 기사 기본 정보 | WORK_STATUS로 근무상태 구분 |
| DRIVER_SCHEDULE | DS_ID (int) | 기사 스케줄 | WORK_DATE로 날짜 필터 |
| DRIVER_STATUS_HIST | | 기사 상태 이력 | |
| DRIVER_WORK_HISTORY | | 기사 근무 이력 | |
| DRIVER_GROUP | | 기사 그룹 | |
| DRIVER_GROUP_MAPPING | | 기사-그룹 매핑 | |
| DRIVER_LICENSE | | 기사 면허 | |
| DRIVER_BASELINE | | 기사 기준 정보 | |

## 법인 (Company)

법인 고객 및 임직원 관리.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| COMP | COMP_CD (varchar) | 법인 기본 정보 | 문자열 PK |
| EMPLOYEE | id (int) | 법인 임직원 | **lower_snake 네이밍** |
| DEPARTMENT | id (int) | 부서 | **lower_snake 네이밍**, 자기참조(parent_id) |
| COMPANY_CAR_MODEL | | 법인별 이용 가능 차종 | |
| COMPANY_CHARTER | | 법인 전세 설정 | |
| COMP_CHARTER | | 법인 전세 | |
| COMP_CHARTER_AIR | | 법인 공항 전세 | |
| COMP_CHARTER_GOLF | | 법인 골프 전세 | |
| COMP_WHITE_LIST | | 법인별 서비스 지역 | |

## 요금 (Fare)

요금 체계 및 운행별 요금 내역.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| FARE | ID (bigint) | 요금 기본 설정 | **lower_snake PK**, COMPANY_CODE FK |
| FARE_HISTORY | ID (bigint) | 운행별 요금 내역 | **매출 조회 핵심**, ALLOCATION_ID FK |
| FARE_HISTORY_DETAIL | | 요금 내역 상세 | |
| AMOUNT | | 금액 | |
| CHARTER | | 전세 요금 | |
| CHARTER_AIR | | 공항 전세 요금 | |
| CHARTER_CAR | | 전세 차량 요금 | |

## 결제 (Payment)

결제 트랜잭션 및 PG 연동.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| PAY_TRX | PAY_TRX_ID (int) | 결제 트랜잭션 | 결제 조회 핵심 |
| PAY_CAN_TRX | | 결제 취소 트랜잭션 | |
| PG_REQ | | PG 요청 | |
| PG_RES | | PG 응답 | |
| PG_CAN_REQ | | PG 취소 요청 | |
| PG_CAN_RES | | PG 취소 응답 | |
| CREDIT_CARD | | 신용카드 정보 | |
| PAYMENT_LINK | | 결제 링크 | |
| MANUAL_PAYMENT | | 수동 결제 | |

## 쿠폰 (Coupon)

쿠폰 정책 및 발행/사용 내역.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| CPN | CPN_ID (int) | 쿠폰 정책 | DISCOUNT_TYPE, DISCOUNT_AMT |
| CPN_PUB | CPN_PUB_ID (int) | 쿠폰 발행 (개별 쿠폰) | USE_YN으로 사용 여부 |
| CPN_REQ | | 쿠폰 요청 | |
| COUPON_PACK | | 쿠폰 팩 | |

## 사용자 (User)

서비스 이용자 유형별 정보.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| SVC_USER | USER_ID (int) | 서비스 사용자 (앱 사용자) | COMP_CD로 법인 연결 |
| CLIENT | ID (bigint) | 클라이언트 (탑승자/수신자 등) | **UPPER + COMPANY_CODE FK** |
| CUSTOMER | | 고객 | |
| LEAVE_USER | | 탈퇴 사용자 | |

## 지역/서비스영역 (Region)

서비스 가능 지역 및 권역 설정.

| 테이블 | 설명 |
|--------|------|
| WHITE_LIST | 서비스 지역 (화이트리스트) |
| REGION | 지역 좌표 |
| ZONE | 존 |
| ZONE_SERVICE_REGION | 존-서비스지역 매핑 |
| ZONE_ZONE | 존-존 관계 |
| SERVICE_REGION | 서비스 리전 |
| COMP_WHITE_LIST | 법인별 서비스 지역 |

## 공통 (Common)

공통 코드 및 권한 관리.

| 테이블 | PK | 설명 | 비고 |
|--------|-----|------|------|
| CD_GRP | GRP_CD (varchar) | 공통 코드 그룹 | GRP_CD_NM 컬럼 |
| CD_DTL | GRP_CD + DTL_CD | 공통 코드 상세 | DTL_CD_NM, DTL_ORDER 컬럼 |
| PERMISSION | | 권한 | |
| GRANT_PERMISSION | | 권한 부여 | |

## 구독 (Subscription)

구독 상품 및 이용 내역.

| 테이블 | 설명 |
|--------|------|
| SUBSCRIPTION | 구독 |
| SUBS_EST_SUM | 구독 정산 합계 |
| SUBS_EST_BOARDING | 구독 정산 탑승 |
| SUBS_EST_DAY | 구독 정산 일별 |
| SUBS_REQ | 구독 요청 |

## 셔틀 (Shuttle)

셔틀 노선 및 예약 관리.

| 테이블 | 설명 |
|--------|------|
| SHUTTLE_LINE | 셔틀 노선 |
| SHUTTLE_CAR | 셔틀 차량 |
| SHUTTLE_STOP | 셔틀 정류장 |
| SHUTTLE_ROUTE | 셔틀 경로 |
| SHUTTLE_RESERVATION | 셔틀 예약 |

## 알림 (Notification)

푸시 알림 및 공지.

| 테이블 | 설명 |
|--------|------|
| PUSH | 푸시 설정 |
| PUSH_TRX | 푸시 트랜잭션 |
| NOTICE | 공지사항 |
| NOTIFICATION_HISTORY | 알림 이력 |

## 기프트카드 (Gift Card)

기프트카드 정책 및 거래.

| 테이블 | 설명 |
|--------|------|
| GIFT_CARD | 기프트카드 |
| GIFT_CARD_POLICY | 기프트카드 정책 |
| GIFT_CARD_PUBLISHED | 기프트카드 발행 |
| GIFT_CARD_TRANSACTION | 기프트카드 거래 |

## 프로모션 (Promotion)

프로모션 및 카드 프로모션 관리.

| 테이블 | 설명 |
|--------|------|
| PROMOTION | 프로모션 정책 |
| CARD_PROMOTION | 카드 프로모션 |

---

## 도메인 연결 가이드

사용자 질문 키워드별 참조 테이블:

| 질문 키워드 | 핵심 테이블 | 보조 테이블 |
|------------|-----------|-----------|
| 배차, 운행, 현황 | ALLOCATION | CALL_REQ, DRIVER, CAR |
| 매출, 요금, 수입 | FARE_HISTORY | ALLOCATION, COMP |
| 결제, 카드 | PAY_TRX | ALLOCATION, CREDIT_CARD |
| 기사, 스케줄, 근무 | DRIVER, DRIVER_SCHEDULE | CAR, ALLOCATION |
| 법인, 회사, 부서 | COMP, EMPLOYEE, DEPARTMENT | CALL_REQ, ALLOCATION |
| 차량, 차종 | CAR, CAR_MODEL | DRIVER_SCHEDULE |
| 쿠폰, 할인 | CPN, CPN_PUB | ALLOCATION |
| 사용자, 고객, 회원 | SVC_USER | CALL_REQ, COMP |
| 탑승자, 수신자 | CLIENT | EMPLOYEE |
| 공통코드, 코드 | CD_GRP, CD_DTL | - |
| 구독, 정산 | SUBSCRIPTION, SUBS_EST_* | ALLOCATION |
| 셔틀 | SHUTTLE_* | ALLOCATION |
| 기프트카드 | GIFT_CARD_* | SVC_USER |
