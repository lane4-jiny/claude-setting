# LANE4 핵심 테이블 스키마

핵심 테이블의 실제 컬럼 정보다. 쿼리 작성 시 정확한 컬럼명과 타입을 참조한다.

> **최종 업데이트**: 2026-02-19 (실제 DB SHOW COLUMNS 기반)

## 네이밍 규칙 주의

LANE4 DB는 **두 가지 네이밍 규칙이 혼재**한다:

| 규칙 | 대상 테이블 | 예시 |
|------|-----------|------|
| **UPPER_SNAKE** (레거시) | ALLOCATION, CALL_REQ, DRIVER, CAR, SVC_USER, PAY_TRX, CPN 등 | `ALLOC_ID`, `DRV_NM`, `REG_DT` |
| **lower_snake** (신규) | EMPLOYEE, DEPARTMENT, CLIENT, FARE_HISTORY, FARE 등 | `id`, `company_code`, `created_at` |

**특히 주의할 컬럼:**
- EMPLOYEE: PK가 `id` (EMPLOYEE_ID 아님), FK가 `company_code` (COMP_CD 아님)
- DEPARTMENT: PK가 `id`, FK가 `company_code`
- FARE_HISTORY: FK가 `ALLOCATION_ID` (ALLOC_ID 아님), 금액 컬럼이 `*_AMOUNT` 패턴
- CLIENT: PK가 `ID`, FK가 `COMPANY_CODE`
- FARE: PK가 `ID`, FK가 `COMPANY_CODE`

---

## ALLOCATION (배차)

LANE4 DB의 **중심 엔티티**. 모든 배차 운행 건을 관리한다.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| ALLOC_ID | int | NO | PK | 배차 ID (auto_increment) |
| CALL_ID | int | NO | MUL | 호출요청 ID -> CALL_REQ |
| CALL_ID_SEQ | smallint | NO | | 호출 순번 (왕복 등) |
| DRV_ID | int | YES | MUL | 기사 ID -> DRIVER |
| CAR_ID | int | YES | MUL | 차량 ID -> CAR |
| car_model_id | int | YES | | 차종 ID -> CAR_MODEL |
| CPN_PUB_ID | int | YES | MUL | 쿠폰발행 ID -> CPN_PUB |
| SUBS_ID | int | YES | MUL | 구독 ID -> SUBSCRIPTION |
| SUBS_ALIAS | varchar(100) | YES | | 구독 별칭 |
| ALLOC_TYPE | varchar(20) | YES | MUL | 배차유형 (`구독`/`일반`) |
| STATUS | varchar(20) | NO | MUL | 배차 상태 (Default: `정상`) |
| ALLOC_DT | date | YES | MUL | 배차 날짜 |
| ALLOC_TIME | time | YES | | 배차 시간 |
| END_TIME | time | YES | | 종료 시간 |
| **탑승지 정보** | | | | |
| BOARDING_ADDR_SHORT | varchar(255) | YES | | 탑승지 짧은 주소 |
| BOARDING_ADDR_LONG | varchar(255) | YES | | 탑승지 긴 주소 |
| BOARDING_ADDR_DETAIL | varchar(200) | YES | | 탑승지 상세 주소 |
| BOARDING_ADDR_JIBUN | varchar(255) | YES | | 탑승지 지번 주소 |
| BOARDING_LATI | decimal(10,8) | YES | | 탑승지 위도 |
| BOARDING_LONG | decimal(11,8) | YES | | 탑승지 경도 |
| **하차지 정보** | | | | |
| ALIGHT_ADDR_SHORT | varchar(255) | YES | | 하차지 짧은 주소 |
| ALIGHT_ADDR_LONG | varchar(255) | YES | | 하차지 긴 주소 |
| ALIGHT_ADDR_DETAIL | varchar(200) | YES | | 하차지 상세 주소 |
| ALIGHT_ADDR_JIBUN | varchar(255) | YES | | 하차지 지번 주소 |
| ALIGHT_LATI | decimal(10,8) | YES | | 하차지 위도 |
| ALIGHT_LONG | decimal(11,8) | YES | | 하차지 경도 |
| **금액 정보** | | | | |
| DRIVING_AMT | decimal(15,0) | YES | | 운행 금액 |
| REAL_RESV_AMT | decimal(15,0) | YES | | 실제 예약 금액 |
| ADD_FEE | decimal(15,0) | NO | | 추가 요금 |
| ADD_FEE_TYPE | varchar(20) | YES | | 추가 요금 유형 |
| TOLL_AMT | decimal(15,0) | NO | | 통행료 |
| SVC_AMT | decimal(15,0) | NO | | 서비스 금액 |
| WAIT_AMT | decimal(15,0) | NO | | 대기 금액 |
| PENALTY_AMT | decimal(15,0) | YES | | 위약금 |
| REFUND_AMT | decimal(15,0) | YES | | 환불 금액 |
| CPN_AMT | decimal(15,0) | YES | | 쿠폰 할인 금액 |
| CARD_DISCOUNT_AMT | decimal(15,0) | YES | | 카드 할인 금액 |
| PAY_AMT | decimal(15,0) | YES | | 결제 금액 |
| NET_AMT | decimal(15,0) | YES | | 순 금액 |
| CHANGE_AMT | decimal(15,0) | YES | | 변경 금액 |
| **운행 정보** | | | | |
| DISTANCE | int | YES | | 운행 거리 (m) |
| START_LATI | decimal(10,8) | YES | | 출발 위도 |
| START_LONG | decimal(11,8) | YES | | 출발 경도 |
| START_DIST | decimal(10,2) | YES | | 출발 거리 |
| END_DIST | decimal(10,2) | YES | | 도착 거리 |
| FLIGHT_NO | varchar(20) | YES | | 항공편명 |
| FLIGHT_DATE | date | YES | | 항공편 날짜 |
| BAGGAGE_CNT | tinyint | YES | | 수화물 수 |
| **평가** | | | | |
| EVAL_SCORE | tinyint | YES | | 평가 점수 |
| EVAL_DETAIL | varchar(255) | YES | | 평가 상세 |
| EVAL_MEMO | varchar(255) | YES | | 평가 메모 |
| EVAL_USER | int | YES | | 평가 사용자 |
| **취소/변경** | | | | |
| CANCEL_REASON | varchar(255) | YES | | 취소 사유 |
| CANCEL_DT | datetime | YES | | 취소 일시 |
| MODIFY_REASON | varchar(255) | YES | | 변경 사유 |
| **기타** | | | | |
| SAFE_NO | varchar(20) | YES | | 안심번호 |
| CALL_MEMO_ID | int | YES | MUL | 호출 메모 ID |
| SEAT_NO | varchar(10) | YES | | 좌석 번호 |
| RIDE_NO | varchar(20) | YES | | 탑승 번호 |
| TICKET_NUMBER | varchar(20) | YES | | 티켓 번호 |
| PROTOCOL_ID | varchar(50) | YES | MUL | 프로토콜 ID |
| SORT_IDX | int | YES | | 정렬 인덱스 |
| INTERNAL_MEMO | varchar(200) | YES | | 내부 메모 |
| DRIVER_MEMO | varchar(1000) | YES | | 기사 메모 |
| VIEW_YN | char(1) | YES | | 노출 여부 (Default: `Y`) |
| IS_DESTINATION_PENDING | char(1) | YES | | 도착지 미정 여부 |
| IS_DEPARTURE_PENDING | char(1) | YES | | 출발지 미정 여부 |
| ALCOHOL_TESTED | char(1) | YES | | 음주 측정 여부 |
| USE_ESCORT_SERVICE | char(1) | YES | | 에스코트 서비스 사용 여부 |
| COORDINATES | json | YES | | 좌표 정보 (JSON) |
| WAIT_STATUS | varchar(20) | YES | | 대기 상태 |
| CAR_HISTORY_ID | bigint | YES | MUL | 차량 이력 ID |
| promotion_id | int | YES | MUL | 프로모션 ID |
| card_promotion_id | int | YES | MUL | 카드 프로모션 ID |
| **번역 (다국어)** | | | | |
| TRANSLATION_TYPE | varchar(5) | YES | | 번역 유형 |
| BOARDING_ADDR_SHORT_T | varchar(100) | YES | | 탑승지 짧은 주소 (번역) |
| BOARDING_ADDR_LONG_T | varchar(200) | YES | | 탑승지 긴 주소 (번역) |
| BOARDING_ADDR_DETAIL_T | varchar(100) | YES | | 탑승지 상세 주소 (번역) |
| ALIGHT_ADDR_SHORT_T | varchar(100) | YES | | 하차지 짧은 주소 (번역) |
| ALIGHT_ADDR_LONG_T | varchar(200) | YES | | 하차지 긴 주소 (번역) |
| ALIGHT_ADDR_DETAIL_T | varchar(100) | YES | | 하차지 상세 주소 (번역) |
| **에미레이트 연동** | | | | |
| EK_CONFIRM | char(1) | YES | | EK 확인 여부 (Default: `N`) |
| EK_STATUS | enum | NO | | EK 상태 (`NORMAL`/`HOLD`) |
| EK_DRIVER_WORKING | char(1) | YES | | EK 기사 근무 여부 |
| **공통** | | | | |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |

---

## CALL_REQ (호출 요청)

고객이 호출/예약을 생성할 때 만들어지는 요청 정보. 배차의 시작점.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| CALL_ID | int | NO | PK | 호출 ID (auto_increment) |
| SERVICE_TYPE | varchar(20) | YES | | 서비스유형 (`AIR`/`ONEWAY`/`SECTION`/`TWOWAY`/`RENT`/`GOLF`/`SHUTTLE`/`ETC`) |
| SUB_TYPE | varchar(20) | YES | | 서브유형 (`departure`/`arrival`/`DISPATCH`) |
| CALL_TP | varchar(20) | NO | | 호출타입 (`대절`/`예약`/`실시간`) |
| rent_type | varchar(20) | YES | | 렌트유형 (`AIR`/`GOLF`) |
| CALL_DATE | date | YES | | 호출 날짜 |
| CALL_TIME | time | NO | | 호출 시간 |
| **출발지** | | | | |
| DEPARTURE_SHORT | varchar(100) | YES | | 출발지 짧은 주소 |
| DEPARTURE_LONG | varchar(200) | YES | | 출발지 긴 주소 |
| DEPARTURE_DETAIL | varchar(200) | YES | | 출발지 상세 주소 |
| DEPARTURE_JIBUN | varchar(255) | YES | | 출발지 지번 주소 |
| DEPT_LATI | decimal(10,8) | YES | | 출발지 위도 |
| DEPT_LONG | decimal(11,8) | YES | | 출발지 경도 |
| **도착지** | | | | |
| DESTINATION_SHORT | varchar(100) | YES | | 도착지 짧은 주소 |
| DESTINATION_LONG | varchar(200) | YES | | 도착지 긴 주소 |
| DESTINATION_DETAIL | varchar(200) | YES | | 도착지 상세 주소 |
| DESTINATION_JIBUN | varchar(255) | YES | | 도착지 지번 주소 |
| DEST_LATI | decimal(10,8) | YES | | 도착지 위도 |
| DEST_LONG | decimal(11,8) | YES | | 도착지 경도 |
| **최종 도착지** | | | | |
| FINAL_DESTINATION_SHORT | varchar(100) | YES | | 최종 도착지 짧은 주소 |
| FINAL_DESTINATION_LONG | varchar(200) | YES | | 최종 도착지 긴 주소 |
| FINAL_DESTINATION_DETAIL | varchar(200) | YES | | 최종 도착지 상세 주소 |
| FINAL_DESTINATION_JIBUN | varchar(255) | YES | | 최종 도착지 지번 |
| FINAL_LATI | decimal(10,8) | YES | | 최종 도착지 위도 |
| FINAL_LONG | decimal(11,8) | YES | | 최종 도착지 경도 |
| **요금 정보** | | | | |
| EXP_FARE | decimal(15,0) | YES | | 예상 요금 |
| EXP_DISTANCE | int | YES | | 예상 거리 |
| EXP_TIME | int | YES | | 예상 시간 |
| EXP_FARE_RTN | decimal(15,0) | YES | | 복귀 예상 요금 |
| EXP_DISTANCE_RTN | int | YES | | 복귀 예상 거리 |
| EXP_TIME_RTN | int | YES | | 복귀 예상 시간 |
| ORG_AMT | decimal(15,0) | YES | | 원래 금액 |
| ORG_AMT_RTN | decimal(15,0) | YES | | 복귀 원래 금액 |
| RESV_AMT_ID | int | YES | | 예약 금액 ID |
| RESV_AMT | decimal(15,0) | YES | | 예약 금액 |
| SERVICE_AMT | decimal(15,0) | YES | | 서비스 금액 |
| AMOUNT_ID | int | NO | MUL | 금액 ID -> AMOUNT |
| AMOUNT_AMT | decimal(15,0) | YES | | 금액 |
| **탑승자 정보** | | | | |
| NUMBER_PASSENGERS | int | YES | | 탑승 인원 |
| PASSENGER_NM | varchar(100) | YES | | 탑승자명 |
| PASSENGER_TEL | varchar(20) | YES | | 탑승자 전화번호 |
| PASSENGER_NATIONALITY | varchar(100) | YES | | 탑승자 국적 |
| PASSENGER_NUMBER | varchar(20) | YES | | 탑승자 번호 |
| PASSENGER_EMAIL | varchar(100) | YES | | 탑승자 이메일 |
| PASSENGER_TYPE | enum | YES | | 탑승자유형 (`SELF`/`OTHER`) |
| **예약 반복** | | | | |
| REPEAT_TP | varchar(20) | YES | | 반복 유형 |
| REPEAT_SDATE | date | YES | | 반복 시작일 |
| REPEAT_EDATE | date | YES | | 반복 종료일 |
| **결제/회원** | | | | |
| COMPANY_PAYMENT_TYPE | enum | YES | | 결제유형 (`COMPANY_PAYMENT`/`CUSTOMER_PAYMENT`/`ON_SITE_PAYMENT`) |
| SIMPLE_CALL_TYPE | enum | YES | | 호출유형 (`IMMEDIATE`/`SCHEDULED`) |
| PROJECT_TYPE | enum | YES | | 호출채널 (`USER`/`DRIVER`/`GUEST`/`PARTNER`/`ADMIN`/`PARSING`) |
| MEMBER_YN | varchar(1) | YES | | 회원 여부 (Default: `Y`) |
| **FK** | | | | |
| USER_ID | int | YES | MUL | 사용자 ID -> SVC_USER |
| EMPLOYEE_ID | int | YES | MUL | 임직원 ID -> EMPLOYEE |
| department_id | int | YES | MUL | 부서 ID -> DEPARTMENT |
| CARD_ID | int | YES | MUL | 카드 ID -> CREDIT_CARD |
| CPN_PUB_ID | int | YES | | 쿠폰발행 ID -> CPN_PUB |
| COMP_CD | varchar(20) | YES | MUL | 법인코드 -> COMP |
| CALL_MEMO_ID | int | YES | MUL | 메모 ID |
| **기타** | | | | |
| ROUND_TRIP | varchar(20) | NO | | 왕복 여부 (Default: `N`) |
| WAIT_TIME | int | YES | | 대기 시간 |
| CHARTER_TIME | int | YES | | 전세 시간 |
| CANCEL_REASON | varchar(1000) | YES | | 취소 사유 |
| CANCEL_TYPE | varchar(100) | YES | | 취소 유형 |
| PICKETING_MEMO | varchar(1000) | YES | | 피케팅 메모 |
| BIZ_N | varchar(20) | YES | | 비즈니스 번호 |
| REMARK | varchar(4000) | YES | | 비고 |
| RESERVATION_TEXT | text | YES | | 예약 텍스트 |
| ETC | json | YES | | 기타 정보 (JSON) |
| EXT_TOKEN | varchar(50) | YES | | 외부 토큰 |
| VIEW_YN | char(1) | NO | | 노출 여부 (Default: `Y`) |
| **번역 (다국어)** | | | | |
| DEPARTURE_SHORT_T ~ FINAL_DESTINATION_DETAIL_T | varchar | YES | | 번역 주소 (_T 접미사) |
| **공통** | | | | |
| STATUS | varchar(20) | NO | | 상태 (Default: `정상`) |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |

---

## DRIVER (기사)

기사 기본 정보. 레거시 UPPER_SNAKE 네이밍.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| DRV_ID | int | NO | PK | 기사 ID (auto_increment) |
| DRV_NM | varchar(100) | NO | | 기사명 |
| DRV_MOBILE | varchar(20) | YES | | 기사 전화번호 |
| DRV_EMAIL | varchar(100) | YES | | 기사 이메일 |
| DRV_PWD | varchar(100) | NO | | 비밀번호 (해시) |
| COMP_CD | varchar(20) | YES | | 소속 법인코드 -> COMP |
| LICENSE_NO | varchar(20) | YES | | 면허 번호 |
| license_id | int | YES | | 면허 ID |
| LICENSE_TYPE | varchar(20) | YES | | 면허 유형 |
| LICENSE_EXPIRE_DT | varchar(8) | YES | | 면허 만료일 |
| QUALIFICATION_NO | varchar(100) | NO | | 자격 번호 |
| **언어 능력** | | | | |
| ENG_LEVEL | varchar(20) | YES | | 영어 수준 |
| CHN_LEVEL | varchar(20) | YES | | 중국어 수준 |
| JPN_LEVEL | varchar(20) | YES | | 일본어 수준 |
| **상태** | | | | |
| STATUS | varchar(20) | NO | | 기사 상태 (`정상`/`삭제`/`중지`) |
| WORK_STATUS | varchar(100) | NO | | 근무 상태 (Default: `TAKEOVER_BEFORE`) |
| CALL_STATUS | varchar(20) | YES | | 콜 수신 상태 (Default: `N`) |
| COMMUTE_STATUS | varchar(20) | YES | | 출퇴근 상태 (`Y`/`N`) |
| CALL_STOP_REASON | varchar(100) | YES | | 콜 중지 사유 |
| **개인 정보** | | | | |
| BIRTH | varchar(8) | YES | | 생년월일 (YYYYMMDD) |
| GENDER | varchar(1) | YES | | 성별 |
| RESIDENCE | varchar(100) | YES | | 거주지 |
| MEMO | varchar(4000) | YES | | 메모 |
| **디바이스/앱** | | | | |
| OS | varchar(20) | YES | | OS |
| OS_VER | varchar(20) | YES | | OS 버전 |
| TOKEN | varchar(2000) | YES | | 푸시 토큰 |
| REFRESH_TOKEN | varchar(2000) | YES | | 리프레시 토큰 |
| REGISTRATION_ID | varchar(200) | YES | | 등록 ID |
| MOBILE_BRAND | varchar(20) | YES | | 모바일 브랜드 |
| MOBILE_MODEL | varchar(100) | YES | | 모바일 모델 |
| APP_VER_NO | varchar(20) | YES | | 앱 버전 |
| SELECTED_MAP | enum | NO | | 선택 지도 (`UNSELECTED`/`NAVER`/`KAKAO`/`TMAP`) |
| **메신저** | | | | |
| MESSENGER_TYPE | enum | YES | | 메신저 유형 (`WECHAT`/`WHATSAPP`/`LINE`/`KAKAOTALK`) |
| MESSENGER_ACCOUNT | varchar(50) | YES | | 메신저 계정 |
| **기타** | | | | |
| CARPLAT_ID | varchar(100) | YES | | 카플랫 ID |
| SAFE_NO | varchar(20) | YES | | 안심번호 |
| TRACKING_YN | varchar(100) | YES | | 추적 여부 |
| NOTI_AGREE | char(1) | NO | | 알림 동의 |
| PROFILE_FILE_ID | int | YES | | 프로필 파일 ID |
| WORK_START_DATE | date | YES | | 근무 시작일 |
| HAS_CONTRACT | char(1) | NO | | 계약 여부 (Default: `N`) |
| IS_FREELANCER | char(1) | NO | | 프리랜서 여부 (Default: `N`) |
| IDENTIFICATION_IMAGE_URL | varchar(255) | YES | | 신분증 이미지 URL |
| LAST_LOGIN_DT | datetime | YES | | 마지막 로그인 |
| **공통** | | | | |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |
| MOD_DT | datetime | YES | | 수정일시 |

---

## DRIVER_SCHEDULE (기사 스케줄)

기사의 일별 근무 스케줄과 배정 차량. **PK 컬럼명이 `DS_ID`** (SCHEDULE_ID 아님).

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| DS_ID | int | NO | PK | 스케줄 ID (auto_increment) |
| DRV_ID | int | NO | MUL | 기사 ID -> DRIVER |
| CAR_ID | int | YES | MUL | 차량 ID -> CAR |
| WORK_DATE | date | NO | | 근무 날짜 |
| WORK_DT_S | datetime | NO | | 근무 시작 일시 |
| WORK_DT_E | datetime | NO | | 근무 종료 일시 |
| WORK_GROUP | varchar(20) | NO | | 근무 그룹 (Default: `주간`) |
| WORK_TIME | bigint | YES | | 근무 시간 (분) |
| REST_TIME | bigint | YES | | 휴식 시간 (분) |
| DAYTIME_AMT | decimal(10,0) | NO | | 주간 금액 |
| NIGHT_AMT | decimal(10,0) | NO | | 야간 금액 |
| DAYTIME_FEE | decimal(10,0) | NO | | 주간 수수료 |
| NIGHT_FEE | decimal(10,0) | NO | | 야간 수수료 |
| COMP_CD | varchar(20) | NO | | 법인코드 (Default: `프리랜서`) |
| DB_ID | int | YES | | DB ID |
| ETC_TEL | varchar(50) | YES | | 기타 전화번호 |
| REMARK | varchar(200) | YES | | 비고 |
| CARPLAT_ORDERS_ID | varchar(100) | YES | | 카플랫 주문 ID |
| WORK_SCHEDULE_ID | bigint | YES | MUL | 근무 스케줄 ID |
| REG_DT | datetime | YES | | 등록일시 |
| MOD_DT | datetime | YES | | 수정일시 |

---

## CAR (차량)

차량 기본 정보.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| CAR_ID | int | NO | PK | 차량 ID (auto_increment) |
| CAR_NO | varchar(100) | NO | MUL | 차량번호 |
| CAR_MODEL_ID | int | NO | MUL | 차종 ID -> CAR_MODEL |
| COMP_CD | varchar(20) | YES | | 법인코드 -> COMP |
| DEPARTMENT_ID | int | YES | | 부서 ID |
| CAR_TYPE | varchar(20) | YES | | 차량 유형 (Default: `구독`) |
| CAR_GRADE | varchar(20) | YES | | 차량 등급 |
| CAR_YEAR | varchar(20) | YES | | 연식 |
| DETAIL_NM | varchar(100) | YES | | 세부 모델명 |
| EX_COLOR | varchar(100) | YES | | 외장색 |
| IN_COLOR | varchar(100) | YES | | 내장색 |
| CC | varchar(100) | YES | | 배기량 |
| FUEL | varchar(100) | YES | | 연료 |
| KM | int | YES | | 주행거리 |
| TRANSMISSION | varchar(100) | YES | | 변속기 |
| FUEL_EFFICIENCY | varchar(100) | YES | | 연비 |
| GARAGE_ID | int | YES | MUL | 차고 ID |
| HIPASS | varchar(20) | YES | | 하이패스 |
| FUEL_CARD_NO | varchar(20) | YES | | 유류 카드 번호 |
| CAR_OPTION | varchar(100) | YES | | 차량 옵션 |
| DEVICE_ID | varchar(100) | YES | | 디바이스 ID |
| USE_ACHAKEY | varchar(100) | NO | | 아차키 사용 (Default: `Y`) |
| USABLE_ALLOC | varchar(100) | NO | | 배차 가능 여부 (Default: `Y`) |
| **렌트 정보** | | | | |
| RENTACAR_NM | varchar(50) | YES | | 렌터카 업체명 |
| RENT_START_DATE | date | YES | | 렌트 시작일 |
| RENT_END_DATE | date | YES | | 렌트 종료일 |
| RENT_PERIOD | varchar(10) | YES | | 렌트 기간 |
| **보험** | | | | |
| INSURANCE_NM | varchar(50) | YES | | 보험사명 |
| INSURANCE_NO | varchar(20) | YES | | 보험 번호 |
| INSURANCE_FILE | varchar(200) | YES | | 보험 파일 |
| **기타** | | | | |
| SUBS_ID | int | YES | | 구독 ID |
| DISCOUNT_YN | varchar(100) | YES | | 할인 여부 |
| PRODUCT_PRICE | varchar(100) | NO | | 상품 가격 |
| MILEAGE | varchar(100) | YES | | 마일리지 |
| DELIVERY_DATE | varchar(100) | YES | | 인도일 |
| REMARK | varchar(100) | YES | | 비고 |
| STATUS | varchar(20) | NO | | 상태 (`정상`/`삭제`/`종료`/`점검`) |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |

---

## CAR_MODEL (차종)

차종/모델 정보.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| CAR_MODEL_ID | int | NO | PK | 차종 ID (auto_increment) |
| BRAND | varchar(100) | NO | MUL | 브랜드 |
| MODEL_NM | varchar(100) | NO | | 모델명 |
| MODEL_S_NM | varchar(100) | YES | | 모델 약칭 |
| MODEL_NAME_EN | varchar(100) | YES | | 영문 모델명 |
| MODEL_DESC | varchar(100) | YES | | 모델 설명 |
| CAR_CLASS | varchar(100) | YES | | 차량 등급 |
| CAR_TYPE | varchar(100) | NO | | 차종 유형 |
| TYPE | varchar(100) | YES | | 타입 |
| SEAT_CNT | varchar(100) | YES | | 좌석 수 |
| RECOMMEND_CNT | char(2) | YES | | 권장 인원 |
| MAX_CNT | char(2) | YES | | 최대 인원 |
| MAXIMUM_BAGGAGE | int | YES | | 최대 수화물 |
| CAR_IMAGES | varchar(200) | YES | | 차량 이미지 |
| ORDER_NO | int | NO | | 정렬 순서 |
| IS_BEST | varchar(20) | YES | | 베스트 여부 |
| FLUCT_RATE | decimal(15,2) | YES | | 변동율 (Default: 1.00) |
| FACTORY_PRICE | varchar(100) | YES | | 출고가 |
| RELEASE_DATE | varchar(100) | YES | | 출시일 |
| IMPORTER_URL | varchar(100) | YES | | 수입사 URL |
| STATUS | varchar(20) | NO | | 상태 |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |

---

## COMP (법인)

법인 고객 기본 정보.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| COMP_CD | varchar(20) | NO | PK | 법인 코드 (문자열 PK) |
| COMP_NM | varchar(100) | NO | | 법인명 |
| BIZ_NO | varchar(20) | YES | | 사업자등록번호 |
| TYPE | varchar(20) | YES | | 유형 |
| TYPE_KOREAN | varchar(20) | YES | | 유형 (한국어) |
| ALIAS | varchar(20) | YES | | 별칭 |
| DC_RATE | decimal(5,2) | YES | | 할인율 |
| RESV_AVAIL_MIN | smallint | NO | | 예약 가능 최소 분 (Default: 180) |
| COMPANY_PAYMENT_TYPES | json | NO | | 결제 유형 목록 (JSON) |
| API_VERSION | int | NO | | API 버전 (Default: 1) |
| MEMBER_YN | enum('Y','N') | YES | | 회원 여부 |
| SHOW_YN | enum('Y','N') | YES | | 노출 여부 (Default: `N`) |
| IS_WEB_OPENED | enum('Y','N') | NO | | 웹 오픈 여부 (Default: `N`) |
| MENU | varchar(100) | YES | | 메뉴 |
| SORT_INDEX | smallint | YES | | 정렬 인덱스 |
| **주소/연락처** | | | | |
| POST_CD | varchar(20) | YES | | 우편번호 |
| ADDR1 | varchar(100) | YES | | 주소1 |
| ADDR2 | varchar(100) | YES | | 주소2 |
| TEL | varchar(20) | YES | | 전화번호 |
| FAX | varchar(20) | YES | | 팩스 |
| CONTACT_NAME | varchar(100) | YES | | 담당자명 |
| CONTACT_NUMBER | varchar(20) | YES | | 담당자 전화번호 |
| CONTACT_EMAIL | varchar(100) | YES | | 담당자 이메일 |
| **기타** | | | | |
| DOMAIN1 | varchar(100) | YES | | 도메인1 |
| DOMAIN2 | varchar(100) | YES | | 도메인2 |
| IMG | varchar(300) | YES | | 이미지 |
| STATUS | varchar(20) | YES | | 상태 (`정상`/`중지`/`삭제`) |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |
| MOD_DT | datetime | NO | | 수정일시 |

---

## EMPLOYEE (임직원)

법인 소속 임직원/사용자. **lower_snake 네이밍** 사용.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| id | int | NO | PK | 임직원 ID (auto_increment) |
| login_id | varchar(20) | NO | UNI | 로그인 ID |
| name | varchar(50) | YES | | 이름 |
| english_name | varchar(20) | YES | | 영문명 |
| last_name | varchar(20) | YES | | 성 |
| first_name | varchar(20) | YES | | 이름 |
| mobile | varchar(20) | YES | | 전화번호 |
| email | varchar(100) | YES | | 이메일 |
| password | varchar(100) | NO | | 비밀번호 (해시) |
| position | varchar(50) | YES | | 직위 |
| role | enum | YES | | 역할 (`MASTER`/`COMPANY_MASTER`/`COMPANY_ADMIN`/`COMPANY_USER`/`USER`) |
| company_code | varchar(20) | NO | | 법인코드 -> COMP.COMP_CD |
| department_id | int | YES | MUL | 부서 ID -> DEPARTMENT.id |
| employee_number | varchar(20) | YES | | 사번 |
| hire_date | date | YES | | 입사일 |
| exit_date | date | YES | | 퇴사일 |
| is_locked | enum('Y','N') | YES | | 잠금 여부 |
| is_representative | enum('Y','N') | NO | | 대표자 여부 (Default: `N`) |
| refresh_token | varchar(1000) | YES | | 리프레시 토큰 |
| created_at | datetime | NO | | 등록일시 |

---

## DEPARTMENT (부서)

법인 내 부서 정보. **lower_snake 네이밍** 사용.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| id | int | NO | PK | 부서 ID (auto_increment) |
| name | varchar(50) | NO | | 부서명 |
| company_code | varchar(20) | NO | | 법인코드 -> COMP.COMP_CD |
| parent_id | int | YES | MUL | 상위 부서 ID (자기참조) |
| created_at | datetime | NO | | 등록일시 |

---

## SVC_USER (서비스 사용자)

앱을 사용하는 최종 사용자. 레거시 UPPER_SNAKE 네이밍.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| USER_ID | int | NO | PK | 사용자 ID (auto_increment) |
| USER_NM | varchar(100) | YES | | 사용자명 |
| USER_MOBILE | varchar(20) | NO | | 전화번호 |
| USER_EMAIL | varchar(100) | NO | | 이메일 |
| PWD | varchar(100) | YES | | 비밀번호 |
| BIRTHDAY | varchar(8) | YES | | 생년월일 |
| GENDER | varchar(1) | YES | | 성별 |
| COMP_CD | varchar(20) | YES | MUL | 법인코드 -> COMP |
| MEMBER_YN | varchar(20) | YES | | 회원 여부 |
| IS_FOREIGNER | enum('Y','N') | NO | | 외국인 여부 (Default: `N`) |
| COUNTRY_CODE | char(2) | YES | | 국가 코드 |
| DIAL_CODE | varchar(10) | YES | | 국제 전화번호 코드 |
| LANGUAGE | varchar(20) | YES | | 언어 |
| **인증/소셜** | | | | |
| providerType | varchar(20) | NO | | 인증 제공자 유형 |
| providerUid | varchar(200) | YES | | 인증 제공자 UID |
| AUTH_INFO | varchar(100) | YES | | 인증 정보 |
| **상태** | | | | |
| STATUS | varchar(20) | NO | | 상태 (Default: `정상`) |
| SIGNUP_DT | datetime | YES | | 가입 일시 |
| LEAVE_DT | datetime | YES | | 탈퇴 일시 |
| LEAVE_REASON | varchar(4000) | YES | | 탈퇴 사유 |
| BLOCK_DT | datetime | YES | | 차단 일시 |
| BLOCK_REASON | varchar(500) | YES | | 차단 사유 |
| LAST_LOGIN_DT | datetime | YES | | 마지막 로그인 |
| **동의** | | | | |
| SMS_AGREE | char(1) | YES | | SMS 동의 |
| PUSH_AGREE | char(1) | YES | | 푸시 동의 |
| EMAIL_AGREE | char(1) | YES | | 이메일 동의 |
| DRT_AGREE | char(1) | YES | | DRT 동의 |
| PERSONAL_INFO_AGREE | varchar(1) | YES | | 개인정보 동의 |
| EVT_DC_INFO_AGREE | varchar(1) | YES | | 이벤트/할인 동의 |
| **추천** | | | | |
| RECMD_CD | varchar(6) | YES | MUL | 추천 코드 |
| RECMD_ID | int | YES | | 추천인 ID |
| RECMD_MOBILE | varchar(20) | YES | | 추천인 전화번호 |
| **디바이스** | | | | |
| OS | varchar(20) | YES | | OS |
| OS_VER | varchar(20) | YES | | OS 버전 |
| TOKEN | varchar(2000) | YES | | 푸시 토큰 |
| REFRESH_TOKEN | varchar(2000) | YES | | 리프레시 토큰 |
| APP_VER_NO | varchar(20) | YES | | 앱 버전 |
| **공통** | | | | |
| VER_NO | int | NO | | 버전 번호 |
| REG_DT | datetime | NO | | 등록일시 |

---

## CLIENT (클라이언트)

호출 건별 관련자. **mixed 네이밍** (ID는 대문자, 나머지도 UPPER).

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| ID | bigint | NO | PK | 클라이언트 ID (auto_increment) |
| NAME | varchar(20) | YES | | 이름 |
| MOBILE | varchar(20) | NO | | 전화번호 |
| COMPANY_CODE | varchar(20) | YES | | 법인코드 -> COMP.COMP_CD |
| TYPE | enum | NO | | 유형 (`CALLER`/`SMS_RECEIVER`/`MANAGER`/`PASSENGER`) |
| EMPLOYEE_ID | int | YES | MUL | 임직원 ID -> EMPLOYEE.id |
| CREATED_AT | datetime | NO | | 등록일시 |

---

## FARE (요금)

요금 기본 설정/정책. **lower_snake 스타일 PK**.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| ID | bigint | NO | PK | 요금 ID (auto_increment) |
| COMPANY_CODE | varchar(50) | YES | MUL | 법인코드 -> COMP.COMP_CD |
| SERVICE_TYPE | enum | YES | | 서비스유형 (`ONEWAY`/`TWOWAY`/`AIR`/`RENT`/`GOLF`/`SECTION`/`SHUTTLE`/`ETC`) |
| REFERENCE_ID | int | NO | | 참조 ID |
| CAR_MODEL_ID | int | YES | MUL | 차종 ID -> CAR_MODEL |
| CAR_TYPE | enum | YES | | 차량유형 (`RESIDENTIAL`/`NON_RESIDENTIAL`/`EXTERNAL`) |
| SERVICE_FARE | int | NO | | 서비스 요금 |
| CAR_FARE | int | NO | | 차량 요금 |
| ADDITIONAL_DISTANCE_FARE | int | YES | | 추가 거리 요금 |
| CREATED_AT | datetime | NO | | 등록일시 |
| MODIFIED_AT | datetime | NO | | 수정일시 |

---

## FARE_HISTORY (요금 내역)

운행 건별 확정 요금 정보. **매출 분석의 핵심 테이블**. FK 컬럼명이 `ALLOCATION_ID`.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| ID | bigint | NO | PK | 요금내역 ID (auto_increment) |
| ALLOCATION_ID | int | NO | UNI | 배차 ID -> ALLOCATION.ALLOC_ID |
| COMPANY_CODE | varchar(20) | YES | | 법인코드 -> COMP.COMP_CD |
| SERVICE_TYPE | enum | NO | | 서비스유형 (`ONEWAY`/`TWOWAY`/`AIR`/`RENT`/`GOLF`/`SECTION`/`SHUTTLE`/`ETC`) |
| PRICING_TYPE | enum | YES | | 요금산정유형 (`PLAN_BASED`/`CUSTOM_INPUT`) |
| **금액 상세** | | | | |
| DRIVING_AMOUNT | int | YES | | 운행 금액 |
| CALL_AMOUNT | int | YES | | 호출 금액 |
| RESERVATION_AMOUNT | int | YES | | 예약 금액 |
| TOLLGATE_AMOUNT | int | YES | | 통행료 |
| WAIT_AMOUNT | int | YES | | 대기 금액 |
| PRODUCT_AMOUNT | int | YES | | 상품 금액 |
| CAR_CLASS_AMOUNT | int | YES | | 차등급 금액 |
| PARKING_AMOUNT | int | YES | | 주차 금액 |
| ETC_AMOUNT | int | YES | | 기타 금액 |
| ADDITIONAL_AMOUNT | int | YES | | 추가 금액 |
| **할인** | | | | |
| DISCOUNT_COMPANY_FIXED_AMOUNT | int | YES | | 법인 정액 할인 |
| DISCOUNT_COMPANY_CHARTER_AMOUNT | int | YES | | 법인 전세 할인 |
| DISCOUNT_COUPON_AMOUNT | int | YES | | 쿠폰 할인 |
| DISCOUNT_CARD_AMOUNT | int | YES | | 카드 할인 |
| DISCOUNT_GIFT_CARD_AMOUNT | int | YES | | 기프트카드 할인 |
| DISCOUNT_POINT_AMOUNT | int | YES | | 포인트 할인 |
| DISCOUNT_TOTAL_AMOUNT | int | YES | | 총 할인 금액 |
| **합계** | | | | |
| TOTAL_AMOUNT | int | YES | | 총 금액 |
| PAYMENT_AMOUNT | int | YES | | 결제 금액 |
| PENALTY_AMOUNT | int | YES | | 위약금 |
| REFUND_AMOUNT | int | YES | | 환불 금액 |
| ADDITIONAL_PAYMENT_YN | enum('Y','N') | YES | | 추가 결제 여부 |
| **기타** | | | | |
| MEMO | varchar(4000) | YES | | 메모 |
| CREATED_DATE | date | YES | | 생성 날짜 |
| CREATED_TIME | time | YES | | 생성 시간 |

---

## PAY_TRX (결제 트랜잭션)

결제 처리 트랜잭션 정보.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| PAY_TRX_ID | int | NO | PK | 결제 트랜잭션 ID (auto_increment) |
| ALLOC_ID | int | NO | MUL | 배차 ID -> ALLOCATION |
| CALL_ID | int | NO | MUL | 호출 ID -> CALL_REQ |
| PAY_TP | varchar(100) | NO | | 결제 유형 (Default: `운행`) |
| TOT_AMT | decimal(15,0) | YES | | 총 금액 |
| DISC_AMT | decimal(15,0) | YES | | 할인 금액 |
| REAL_PAY_AMT | decimal(15,0) | YES | | 실결제 금액 |
| VAT | decimal(15,0) | YES | | 부가세 |
| CARD_NO | varchar(100) | YES | MUL | 카드 번호 |
| APP_NO | varchar(20) | YES | | 승인 번호 |
| TNO | varchar(100) | YES | | PG 거래번호 |
| ORDR_IDXX | varchar(1000) | YES | | 주문 ID |
| PG_REQ_ID | int | YES | MUL | PG 요청 ID |
| RECEIPT_URL | varchar(100) | YES | | 영수증 URL |
| FAIL_CD | varchar(20) | YES | | 실패 코드 |
| PAY_DT | datetime | YES | | 결제 일시 |
| PAYMENT_TYPE | enum | YES | | 결제 수단 유형 (`TOSS_PAYMENTS_PAYPAL`) |
| PROVIDER | varchar(30) | YES | | 결제 제공자 |
| STATUS | varchar(20) | NO | | 상태 (Default: `정상`) |
| VER_NO | int | NO | | 버전 번호 |

---

## CPN (쿠폰)

쿠폰 정책/마스터.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| CPN_ID | int | NO | PK | 쿠폰 ID (auto_increment) |
| CPN_NM | varchar(100) | NO | | 쿠폰명 |
| CPN_CONTENTS | varchar(400) | YES | | 쿠폰 내용 |
| CPN_TP | varchar(100) | YES | | 쿠폰 타입 |
| CPN_CD | varchar(100) | YES | | 쿠폰 코드 |
| DISCOUNT_TYPE | enum('RATE','FIXED') | NO | | 할인유형 (Default: `FIXED`) |
| DISCOUNT_AMT | int | NO | | 할인 금액 |
| DISCOUNT_RATE | int | YES | | 할인율 (%) |
| MAXIMUM_DISCOUNT_AMOUNT | int | YES | | 최대 할인 금액 |
| MINIMUM_PAYMENT_AMOUNT | int | YES | | 최소 결제 금액 |
| **서비스 범위** | | | | |
| service_type | varchar(20) | YES | | 서비스 유형 |
| call_type | varchar(20) | YES | | 호출 유형 (Default: `CALL,RESV,RENT`) |
| rent_type | varchar(20) | YES | | 렌트 유형 |
| **발행 설정** | | | | |
| EXP_TP | varchar(100) | NO | | 만료 유형 |
| EXP_CYCLE | int | YES | | 만료 주기 |
| PUB_SDATE | datetime | NO | | 발행 시작일 |
| PUB_EDATE | datetime | NO | | 발행 종료일 |
| USE_SDATE | date | YES | | 사용 시작일 |
| USE_EDATE | date | YES | | 사용 종료일 |
| MAX_PUB_CNT | int | YES | | 최대 발행 수량 |
| AUTO_REG_CNT | int | NO | | 자동 등록 수량 (Default: 1) |
| IS_FIRST_COME_FIRST_SERVED | enum('Y','N') | YES | | 선착순 여부 |
| **소속** | | | | |
| COMP_CD | varchar(100) | YES | | 법인코드 |
| EMP_ID | varchar(100) | YES | MUL | 등록 임직원 ID |
| MOD_ID | varchar(100) | YES | | 수정자 ID |
| promotion_id | int | YES | MUL | 프로모션 ID |
| COUPON_PACK_ID | int | YES | MUL | 쿠폰팩 ID |
| STATUS | varchar(20) | NO | | 상태 |
| VER_NO | int | NO | | 버전 |
| REG_DT | datetime | NO | | 등록일시 |
| MOD_DT | datetime | YES | | 수정일시 |

---

## CPN_PUB (쿠폰 발행)

개별 발행된 쿠폰.

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| CPN_PUB_ID | int | NO | PK | 쿠폰발행 ID (auto_increment) |
| CPN_ID | int | NO | MUL | 쿠폰 ID -> CPN |
| CPN_CD | varchar(14) | YES | | 쿠폰 코드 |
| USER_ID | int | YES | | 사용자 ID -> SVC_USER |
| USE_YN | char(1) | YES | | 사용여부 (Default: `N`) |
| USE_DT | datetime | YES | | 사용 일시 |
| USE_AMOUNT | int | YES | | 사용 금액 |
| PUB_DT | datetime | YES | | 발행 일시 |
| EXPIRE_DT | date | YES | | 만료일 |
| APPROVAL_NUMBER | varchar(100) | YES | | 승인 번호 |
| REG_DT | datetime | YES | | 등록일시 |

---

## CD_GRP (공통코드 그룹)

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| GRP_CD | varchar(20) | NO | PK | 코드 그룹 |
| GRP_CD_NM | varchar(50) | YES | | 그룹명 |
| STATUS | varchar(20) | NO | | 상태 (Default: `정상`) |
| VER_NO | int | NO | | 버전 |
| REG_DT | datetime | NO | | 등록일시 |

---

## CD_DTL (공통코드 상세)

| 컬럼 | 타입 | Null | 키 | 설명 |
|------|------|------|-----|------|
| GRP_CD | varchar(20) | NO | PK | 코드 그룹 -> CD_GRP |
| DTL_CD | varchar(20) | NO | PK | 상세 코드 |
| DTL_CD_NM | varchar(50) | YES | | 코드명 |
| VAL1 ~ VAL5 | varchar(50) | YES | | 부가값 1~5 |
| DTL_ORDER | smallint | NO | | 정렬 순서 |
| STATUS | varchar(20) | NO | | 상태 (Default: `정상`) |
| VER_NO | int | NO | | 버전 |

---

## 주요 차이점 요약 (기존 문서 대비)

| 항목 | 기존 문서 | 실제 DB |
|------|----------|---------|
| ALLOCATION PK | bigint | **int** (auto_increment) |
| ALLOCATION STATUS Default | `NORMAL` | **`정상`** (한글) |
| DRIVER_SCHEDULE PK | SCHEDULE_ID | **DS_ID** |
| DRIVER_SCHEDULE 날짜 | SCHEDULE_DT | **WORK_DATE** |
| EMPLOYEE PK | EMPLOYEE_ID | **id** (lower_snake) |
| EMPLOYEE FK(법인) | COMP_CD | **company_code** |
| DEPARTMENT PK | DEPARTMENT_ID | **id** |
| DEPARTMENT FK(법인) | COMP_CD | **company_code** |
| DEPARTMENT 부서명 | DEPT_NM | **name** |
| CLIENT PK | CLIENT_ID | **ID** |
| FARE PK | FARE_ID | **ID** |
| FARE_HISTORY PK | FARE_HISTORY_ID | **ID** |
| FARE_HISTORY FK(배차) | ALLOC_ID | **ALLOCATION_ID** |
| FARE_HISTORY 총요금 | TOTAL_FARE | **TOTAL_AMOUNT** |
| CD_GRP 그룹명 | GRP_NM | **GRP_CD_NM** |
| CD_DTL 코드 | CD | **DTL_CD** |
| CD_DTL 코드명 | CD_NM | **DTL_CD_NM** |
| CD_DTL 정렬순서 | SORT_ORDER | **DTL_ORDER** |
| CD_DTL USE_YN | 존재 | **STATUS 필드로 대체** (`정상`/`삭제`) |
