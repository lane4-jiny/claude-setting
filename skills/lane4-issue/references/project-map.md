# Lane4 프로젝트 맵 - 상세 참조 문서

> 이슈 분석 시 프로젝트 간 관계, DB 테이블, 외부 API 연동을 확인하기 위한 참조 문서

## 목차
1. [서비스 → 프로젝트 매핑](#1-서비스--프로젝트-매핑)
2. [프론트엔드 → 백엔드 호출 관계](#2-프론트엔드--백엔드-호출-관계)
3. [백엔드 간 호출 관계](#3-백엔드-간-호출-관계)
4. [DB 테이블 구조](#4-db-테이블-구조)
5. [배차 상태 흐름](#5-배차-상태-흐름)
6. [외부 API 연동 목록](#6-외부-api-연동-목록)
7. [스케줄러 작업 목록](#7-스케줄러-작업-목록)
8. [알림 파이프라인](#8-알림-파이프라인)
9. [인증 체계](#9-인증-체계)
10. [프로젝트별 기술 상세](#10-프로젝트별-기술-상세)

---

## 1. 서비스 → 프로젝트 매핑

| 서비스 | Frontend | Backend API | 용도 |
|--------|----------|-------------|------|
| 뉴어드민 (내부) | lane4-admin | lane4-admin-api | 운영 백오피스 |
| 법인어드민 (B2B) | lane4-biz | lane4-partner-api | 법인 파트너 |
| 레인포웹 (B2B2C/B2C) | lane4-web | lane4-guest-api | 고객 웹 예약 |
| 레인포앱 (B2C) | lane4-app-user | lane4-app-api | 고객 모바일앱 |
| 기사앱 | lane4-app-driver | lane4-driver-api | 기사 배차/운행 |

### 인프라/공통 프로젝트

| 프로젝트 | 역할 | 통신 |
|---------|------|------|
| lane4-monitoring-api | 실시간 관제 | Socket.IO, Kafka |
| lane4-notification-api | 알림 템플릿+이력 | REST, RabbitMQ |
| lane4-notification-server | 알림 발송 (SMS,Push,Email,Kakao,Slack) | RabbitMQ |
| lane4-scheduler | Cron 스케줄링 | Cron, Kafka |
| lane4-allocation-api | 예약 가능일자 계산 | Redis RPC |
| lane4-backend-library | 공통 유틸 (TMap,OpenAI,FlightAware,Firebase) | npm |
| lane4_backend | 레거시 모놀리스 (Java/Spring Boot) | REST |
| lane4-emirates-api | Emirates 메일파싱 → 자동배차 | Gmail API + Cron |
| lane4-klook-api | Klook/Creatrip 크롤링 → 자동배차 | Gmail API + Puppeteer |

---

## 2. 프론트엔드 → 백엔드 호출 관계

### lane4-admin (뉴어드민)
- lane4-admin-api (admin-api.lane4.ai)
- lane4-monitoring-api (monitoring-api.lane4.ai)
- lane4-scheduler (scheduler.lane4.ai)
- WebSocket: car-control.lane4.ai

### lane4-biz (법인어드민)
- lane4-partner-api (partner-api.lane4.ai)
- lane4-monitoring-api (monitoring-api.lane4.ai)
- ananti-api.lane4.ai (특수 법인)
- WebSocket: car-control.lane4.ai

### lane4-web (고객 웹)
- lane4-guest-api (guest-api.lane4.ai)
- lane4-admin-api (결제 검증용)
- lane4-app-api (이메일/게스트 전용)
- lane4-monitoring-api (WebSocket: allocation-monitoring)

### lane4-app-user (고객 앱)
- lane4-app-api (app-api.lane4.ai)
- lane4_backend (api.lane4.ai/api/ - 레거시)
- lane4-notification-api (push-messages)
- lane4-guest-api (공유 URL)

### lane4-app-driver (기사 앱)
- lane4-driver-api (driver-api.lane4.ai)
- lane4_backend (api.lane4.ai/api/ - 레거시)
- lane4-monitoring-api (위치 전송 + WebSocket)
- lane4-notification-api (push-messages)
- OTORIDE API (스마트키 BLE)

---

## 3. 백엔드 간 호출 관계

### lane4-admin-api
- → lane4-allocation-api (Redis RPC: 예약 가능일자)
- → lane4_backend (SPRING_HOST: 결제/임시배차)
- → lane4-notification-server (RabbitMQ: 알림)
- → Kafka → lane4-monitoring-api

### lane4-partner-api
- → lane4-allocation-api (Redis RPC)
- → lane4-guest-api (결제 링크 리다이렉트)
- → lane4-notification-server (RabbitMQ)
- → Kafka → lane4-monitoring-api

### lane4-guest-api
- → lane4-allocation-api (Redis RPC)
- → lane4-notification-server (RabbitMQ)
- → Kafka → lane4-monitoring-api

### lane4-app-api
- → lane4-guest-api (예약 취소 위임)
- → lane4_backend (SPRING_HOST: 결제/임시배차)
- → Fleetune API (셔틀/DRT 배차)
- → Kafka → lane4-monitoring-api

### lane4-driver-api
- → lane4_backend (SPRING_HOST: 레거시)
- → Firebase Realtime DB (실시간 콜)
- → Kafka → lane4-monitoring-api
- → Redis (위치 추적 + Redlock)

### lane4-monitoring-api
- ← Kafka Consumer (11개 토픽): driver-location, sync-elasticsearch, refresh-driver, begin-driving, sync-driver-car, send-monitoring-notification, fcm-silent-push-driver/user, change-driver-status, save-shuttle-status-history
- → Elasticsearch (위치/차량 인덱싱)
- → Firebase FCM (사일런트 푸시)
- → Redis (룸 관리, ETA)
- WebSocket 3개: /drivers, /monitoring, /allocation-monitoring

### lane4-notification-api
- ← RabbitMQ (요청 수신)
- → MySQL (NOTIFICATION_HISTORY)
- → RabbitMQ (에러 발행)

### lane4-notification-server
- ← RabbitMQ (요청 소비)
- → notification-api (HTTP: 템플릿 조회)
- → Aligo (SMS + Kakao AlimTalk)
- → SMTP (이메일)
- → Slack Web API
- → Cafe24 SMS
- → AWS SQS → FCM (Push)
- → Redis (중복 방지: 60초 TTL)

### lane4-scheduler
- → MySQL (직접 접근)
- → Kafka Producer (refresh-driver, sync-elasticsearch)
- → Firebase FCM, Aligo SMS, OpenAI, Upstage, TMap, Slack

### lane4-emirates-api
- → Gmail API → MySQL (배차 생성) → Redis → Slack

### lane4-klook-api
- → Gmail API / Puppeteer → TMap → MySQL (배차 생성) → Slack

---

## 4. DB 테이블 구조

모든 API가 동일한 MySQL Aurora DB (LANE4)를 공유한다.

| 도메인 | 주요 테이블 | 관련 API |
|--------|------------|---------|
| 배차 | ALLOCATION, ALLOC_STATUS_HIST, ALLOC_TARGET, ALLOCATION_FILES | 전체 |
| 콜요청 | CALL_REQ, CALL_EXP_FARE, CALL_MEMO | 전체 |
| 기사 | DRIVER, DRIVER_SCHEDULE, DRIVER_STATUS_HIST, DRIVER_REST_TIME | admin, driver, partner |
| 차량 | CAR, CAR_MODEL, CAR_OPTION, CAR_ADMIN_HIST | admin, partner |
| 결제 | PAY_TRX, PAY_CAN_TRX, PG_REQ, PG_RES, CREDIT_CARD, RECEIPT | guest, app, admin |
| 고객 | SVC_USER, BOOKMARK | guest, app |
| 법인 | COMP, COMP_CHARTER, COMP_WHITE_LIST, DEPARTMENT, EMP | admin, partner |
| 구독 | SUBSCRIPTION, SUBS_PAY_HIST, SUBS_ALLOCATION_HIST | app, admin |
| 쿠폰 | CPN, CPN_PUB, CPN_REQ, CARD_PROMOTIONS | 전체 |
| 요금 | AMOUNT, FARE_HISTORY, FARE_HISTORY_DETAIL | admin, partner, guest |
| 알림 | NOTIFICATION_HISTORY, BIZ_MSG, PUSH, PUSH_TRX | notification |
| 공통코드 | CD_GRP, CD_DTL, REGION, HOLIDAY | 전체 |
| 안심번호 | SAFE_NO | admin, scheduler |
| 파싱 | PARSING | emirates |
| 주소번역 | ADDRESS_TRANSLATION, TRANSLATION_RAINBOW | emirates, klook |

---

## 5. 배차 상태 흐름

```
[생성] → NORMAL → DEPARTURE(출발) → BOARDING(탑승) → CHARGE(요금) → END(완료)
                      ↓                                        ↓
                  CANCEL(취소)                              NO_SHOW
```

---

## 6. 외부 API 연동 목록

### 지도/경로
- **TMap** (SK): 경로 예측, POI, 역지오코딩 → 전체 백엔드 (backend-library)
- **Naver Map**: 지도 표시 → 프론트엔드
- **Google Maps**: 해외 주소 → guest-api
- **Kakao Map**: 지도 표시 → admin

### 결제
- **Toss Payments**: 카드 결제 → guest-api, web
- **PortOne (iamport)**: KCP 빌링, 구독 → guest-api, app-api
- **KCP (NHN)**: 배치 결제 → admin-api, app-api, lane4_backend

### 알림/메시징
- **Firebase FCM**: Push → notification-server, monitoring, scheduler
- **Firebase RTDB**: 실시간 콜 → driver-api, monitoring
- **Aligo**: SMS + 카카오 알림톡 → notification-server, scheduler
- **Cafe24**: SMS 보조 → notification-server
- **AWS SES**: 이메일 → notification-server, guest-api
- **Slack Webhook**: 운영 알림 (8+ 채널) → 전체

### 항공/교통
- **FlightAware AeroAPI**: 항공편 추적 → backend-library
- **공항 OpenAPI**: ICN/GMP 스크래핑 → scheduler
- **Fleetune**: 셔틀/DRT → app-api

### 기타
- **OpenAI GPT-4o**: 주소 번역, OCR → scheduler, backend-library
- **Upstage**: OCR → scheduler
- **SKT SafeNo**: 안심번호 → admin-api, partner-api, scheduler
- **COOP iNumber**: 가상번호 → app-api, lane4_backend
- **OTORIDE**: BLE 스마트키 → driver-api
- **KT Alpha**: 기프티쇼 → guest-api
- **Gmail API**: 메일 수신 → emirates-api, klook-api
- **Creatrip**: Puppeteer 크롤링 → klook-api

---

## 7. 스케줄러 작업 목록 (lane4-scheduler)

| 작업 | 주기 | 설명 |
|------|------|------|
| 항공편 스크래핑 | 5분 | ICN/GMP 출도착 |
| 쿠폰 롤백 | 매일 자정 | 미사용 쿠폰 복원 |
| 예약 리마인더 | 매일 10시 | 7일 전 확인 알림 |
| 설문 알림 | 10분 | 강남구 법인 설문 |
| 에미레이츠 리마인더 | 10분 | EK항공 도착 전 알림 |
| 노쇼 알림 | 1분 | KE항공 노쇼 체크 |
| FCM 모니터링 | 10분 | 미수신 푸시 알림 |
| MySQL 커넥션 킬 | 1분 | Sleep 300초 초과 정리 |
| 안심번호 해제 | 5분 | 완료 배차 회수 |
| 미완료 배차 체크 | 1시간 | 전일 미종료 알림 |
| Achakey 모니터링 | 5분 | 스마트키 상태 |
| SMS 잔액 확인 | 1시간 | Aligo 10만원 미만 경고 |
| 주소 번역 | 1분 | Emirates OpenAI 번역 |
| 셔틀 데이터 생성 | 매일 자정 | 인천혁신 셔틀 |
| 셔틀 탑승 리마인더 | 10분 | 10분 전 알림 |
| 영수증 OCR | 5분 | 교통위반/영수증 |
| 신규가입 리포트 | 5분 | Slack 알림 |
| 토큰 갱신 실패 | 5분 | Slack 알림 |
| 근무 스케줄 알림 | 10분 | GMCC 6시간 전 |
| 요금 이력 검증 | 매일 01시 | 정합성 체크 |

---

## 8. 알림 파이프라인

```
[이벤트 발생] → [Backend API] → NotificationUtils.notify() (RabbitMQ 발행)
  → [notification-api] ← RabbitMQ: TaskType + ResourceFinder → 템플릿 → NOTIFICATION_HISTORY
  → [notification-server] ← RabbitMQ: Redis 중복체크(60초) → 발송
      ├─ Slack (내부), Kakao AlimTalk, SMS, Email, Push (SQS→FCM)
```

**주요 TaskType 카테고리**: RESERVATION, ALLOCATION, DRIVING, REMINDER, AIRLINE, PAYMENT, DMT, SURVEY, WORK_SCHEDULE (50+ 종류)

---

## 9. 인증 체계

| 클라이언트 | 인증 방식 | access 만료 | refresh 만료 |
|-----------|----------|------------|-------------|
| admin/biz (웹) | next-auth + Credentials → JWT | 1h | 7d |
| web (웹) | next-auth + OAuth + Guest | 30min | 30d |
| app-user (앱) | Social OAuth → JWT | 24h | 30d |
| app-driver (앱) | ID/PW → JWT | 24h | 30d |

- Bearer Token: `Authorization: Bearer {accessToken}`
- 커스텀 헤더: `X-Lang`, `X-Currency`, `X-Guest-Authorization`

---

## 10. 프로젝트별 기술 상세

### lane4-admin: Next.js 15, React 19, Ant Design 5, Bryntum Scheduler. 103 페이지, 28 API 도메인. Feature Flag (OpenFeature + flagd)

### lane4-biz: Next.js 15, React 19, Ant Design 5, Recharts. i18n (한/영). 45+ 법인

### lane4-web: Next.js 15, Tailwind + styled-components. 서비스타입: AIR/GOLF/RENT/ONEWAY/TWOWAY/SHUTTLE. Toss+PortOne 결제. 비회원(Guest) 예약

### lane4-app-user: React Native 0.77, Redux + Saga + React Query 혼용. CALL/렌트/골프/공항/DRT/구독

### lane4-app-driver: React Native 0.81, Redux + React Query 5. Background Geolocation, BLE 스마트키, Firebase RTDB 콜 수신. 이중 API(레거시+모던)

### lane4-admin-api: NestJS 10, TypeORM 0.2, 115 엔티티, ~64 도메인. PortOne/Toss/KCP 3중 PG. Kafka Producer

### lane4-partner-api: NestJS 10, TypeORM 0.2, 109 엔티티, 65 도메인. Ananti API, OpenAI 임베딩

### lane4-guest-api: NestJS 10, TypeORM 0.2, 110+ 엔티티, 35+ 도메인. DynamoDB(reservation-share). nestjs-i18n

### lane4-app-api: NestJS 10, TypeORM 0.2, 100+ 엔티티, 34 도메인. Fleetune DRT, COOP iNumber, KCP 배치결제

### lane4-driver-api: NestJS 9, TypeORM 0.2, 99 엔티티, 46 도메인. Redis GEOADD/GEOPOS, Redlock. 자동 출퇴근 Cron

### lane4-monitoring-api: NestJS 10, Socket.IO, Kafka 11 Consumer, Elasticsearch. 5초 브로드캐스트

### lane4-scheduler: NestJS 10, @nestjs/schedule. 24 도메인, 20+ Cron 작업

### lane4-emirates-api: NestJS 9, TypeORM 0.3. Gmail API → 60+ Regex → CDA/CDD → 배차 생성. 3단계 이메일

### lane4-klook-api: NestJS 9, Puppeteer, Cheerio. Klook(Gmail HTML파싱), Creatrip(Puppeteer GraphQL 인터셉트)

### lane4-notification-api/server: 50+ TaskType, 6채널 발송, Redis 60초 중복방지

### lane4-allocation-api: NestJS 10, Redis Transport. TB_DATE_POLICY 기반 슬롯 계산

### lane4-backend-library: TypeScript, npm. TMapUtils, OpenAIUtils, FlightAwareUtils, NotificationUtils, FirebaseModule

### lane4_backend: Java 11, Spring Boot 2.3, MyBatis. 29 XML, 104 DTO. KCP 결제(ConnectionKCP.jar), CarPlat API
