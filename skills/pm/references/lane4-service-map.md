# Lane4 서비스 맵 (PM 지식 베이스)

> 이 문서는 PM 에이전트가 **lane4 모노레포 전체 동작을 이해**하기 위한 베이크인 지식이다.
> 21개 프로젝트를 실제 정독하여 추출(2026-06-01). 기능 요청이 들어오면 PM은 먼저 이 맵으로
> "어느 도메인 / 어느 프로젝트(들) / 어떤 프로젝트 간 흐름"이 관련되는지 판단한다.
> 코드 세부는 시간이 지나면 변하므로, **디스패치 전 실제 코드 재확인**은 BE/FE 에이전트의 몫이다.

---

## 0. 한눈에 보는 아키텍처

```
[모바일]  lane4-app-user(승객앱·RN)        lane4-app-driver(기사앱·RN)
            │                                   │
[웹]      lane4-web(게스트웹)  lane4-admin(어드민웹)  lane4-biz(법인어드민웹)
            │                    │                   │
[BFF/API] lane4-guest-api    lane4-admin-api      lane4-partner-api
          lane4-app-api      lane4-driver-api     lane4-web-api(빈 껍데기·미사용)
            │
[엔진]    lane4-allocation-api(배차엔진·Redis RPC)
[관제]    lane4-monitoring-api(Socket.io+ES+Firebase)
[알림]    lane4-notification-api(템플릿) → lane4-notification-server(발송워커, RabbitMQ)
[배치]    lane4-scheduler(@nestjs/schedule, 16개 도메인 cron)
[외부연동] lane4-emirates-api(Gmail파싱)  lane4-klook-api(Klook/Creatrip/DragonPass)
[레거시]  lane4_backend(Spring Boot+MyBatis)   lane4-achakey(크롤링 어댑터·거의死)
[공통]    lane4-backend-library(npm priv pkg: NotificationUtils/TaskType/enum/DateTimeUtils)
[문서]    lane4-docs(비즈니스+도메인 문서 허브)
```

**데이터 소스**: MySQL(LANE4 스키마, master-slave) · Redis(레거시+신규 **이중 인스턴스**) ·
Elasticsearch(위치/실경로/셔틀 시계열) · Firebase RTDB(user/driver 2개) · RabbitMQ(알림) ·
Kafka(`local.*` 토픽, 관제 동기화) · AWS(S3/SQS/Secrets Manager)

---

## 1. 비즈니스 도메인 지도 (lane4-docs 기반)

| 도메인 | 정의 | 주 구현 프로젝트 | 핵심 상태/개념 |
|--------|------|----------------|---------------|
| **배차/예약** | 고객 요청→기사 할당까지 생성·상태관리 | allocation-api(엔진), app/guest/partner/admin/driver-api | 생성→할당→시작→운행중→완료 / 셔틀·DRT·차터 |
| **요금(Fare)** | 서비스/법인별 차등 산출·할인·이력 | partner·guest·app·admin-api, scheduler | ServiceFinder 패턴(기본/예외/폴백/고정/수기/할인), 법인요금 우선 |
| **결제(Payment)** | 수납(수기+일반)·취소·PG연동 | admin(수기)·partner(링크)·guest(빌링키)·app-api(KCP) | READY→COMPLETE/FAIL/CANCEL/PARTIAL_CANCEL |
| **기사 출퇴근** | 출근→차량인수→콜→퇴근, 자동출퇴근 | driver-api, admin-api, scheduler | TAKEOVER_BEFORE→TAKEOVER_AFTER→BEGIN_WORK→(CALL_COMMUTE↔CALL_STOP)→END_WORK |
| **기프트카드** | 선불할인수단 발행→사용→환불 | admin(발행)·guest-api(등록/사용) | ISSUED→REGISTERED→USED/EXPIRED/REVOKED |
| **차량구분** | 상주/비상주/외부(요금영향) | admin·partner-api | RESIDENTIAL(저)→NON_RESIDENTIAL(중)→EXTERNAL(고) |
| **안심번호** | 050 가상번호 매핑(승객↔기사) | admin-api, scheduler(5분 자동회수), SK SafeN | AVAILABLE↔ASSIGNED, DRIVER/USER 구분 |
| **정산/경비** | 영수증/과태료 OCR+LLM 검수 | admin(검수)·driver-api(업로드)·scheduler(추출) | 업로드→자동추출→검수대기→검수완료→정산 |
| **대시보드** | 법인 예약/배차/운행 통계 | partner-api, biz | Strategy 패턴 TYPE1/2/3 |
| **알림** | 카카오알림톡/FCM/SMS/메일/Slack | notification-api(템플릿)→notification-server(발송) | TaskType별 채널 라우팅 |
| **모니터링/관제** | 실시간 위치·상태 추적 | monitoring-api(Socket.io), admin·partner-api, biz | 위치 ES 시계열, 업무상태별 로깅 스킵 |
| **운행/특수** | DRT·셔틀·차터 | app-api(DRT)·driver-api(셔틀)·allocation-api(차터) | — |

**End-to-End 흐름**:
```
예약(app/partner-api) → 요금산출(Fare ServiceFinder) → 배차(allocation-api)
→ 기사배정+안심번호(admin-api) → 결제(guest/app-api+PG) → 운행시작(driver-api)
→ 실시간관제(monitoring-api+biz) → 운행완료 → 정산+경비OCR → 알림(notification-api)
```

---

## 2. 프로젝트별 카드

### Backend APIs (NestJS + TypeORM + MySQL)

**lane4-driver-api** — 기사앱 백엔드(배차/기사/차량/셔틀). Node+yarn, NestJS 9.
- 도메인: Allocation, Driver, Car, Shuttle, DriverSchedule, Flight, CarInspection. ~100 엔티티.
- Kafka 발행: `local.driver.begin-driving`, `local.monitoring.change-driver-status`, `local.monitoring.refresh-driver`, `local.monitoring.sync.elastic-search`, `log.shuttle.status.history`.
- 이중 Redis(레거시 cache-manager-ioredis + 신규 ioredis/RedisUtils). Firebase RTDB(기사위치). S3(점검사진/음성).
- gotcha: QueryRunner 트랜잭션 강제(@Transactional 금지), 기능별 service 파일 분리(find./update.), Swagger 금지, `claudedocs/{title}_sideeffect.md` 작성 의무.
- 구조: `src/domains/*`(48), `src/entities`, `src/commons/{kafka,redis,newRedis,cache,s3}`, `src/auth`.

**lane4-allocation-api** — 배차 엔진. **Redis Message RPC(@MessagePattern), HTTP 없음**(헬스체크만 8080). Node20+npm.
- RPC: `create_allocation_golf`, `find_golf_fare`, `find_date_policy`. 골프 대절 특화.
- 도메인: Allocation, Call, Fare, Policy(TB_DATE_POLICY), DriverSchedule, Charter, Coupon, Card.
- gotcha: 여기는 `@Transactional()`(cls-hooked) 사용. Secrets Manager. SMS/Slack 호출.

**lane4-admin-api** — 어드민 백오피스. NestJS 10, yarn.
- 도메인: 배차/기사/차량/결제(수기)/정산(경비·과태료)/법인/구독/쿠폰/지역요금.
- 신규는 DDD(presentation→application→domain), 레거시는 flat. **MyBatis XML(`src/lib/mapper/*.xml`)** 병행. 이중 Redis. ES(배차이력/실경로). Kafka(ES동기화).
- gotcha: RolesGuard, Pagination.of(), QueryRunner, MyBatis 변경 시 영향분석 필수.

**lane4-app-api** — 승객앱 백엔드. NestJS, npm(Alpine).
- 도메인: 예약/배차/요금(+과금)/결제(KCP)/구독(Stripe/KCP)/쿠폰/회원/법인월정산/콜/차터.
- 레거시(src 루트)+신규(src/domains DDD) 혼재. 112 엔티티. 이중 Redis(안심번호/환율/대시보드). MyBatis 일부.
- 의존: driver-api(Kafka), allocation-api(배차), notification-api(FCM/SMS).

**lane4-monitoring-api** — 관제. Socket.io + ES + Firebase. npm.
- WS 네임스페이스: `/drivers`(위치), `/monitoring` & `/allocation-monitoring`(대시보드).
- Kafka **구독**: `local.monitoring.*`(driver-location, refresh-driver, sync.driver.car, sync.elastic-search, send-monitoring-notification, silent-push-driver, reservation-notification), `local.driver.begin-driving`, `app.silent-push-user`, `log.shuttle.status.history`.
- ES 인덱스: `driver-location_YYYY-MM-DD`(일자별!), `car-history_*`, `shuttle-status-history_*`. Firebase user/driver 2개.
- gotcha: 업무상태 TAKEOVER_BEFORE/END_WORK/RETURN_AFTER면 위치로깅 스킵. Kafka 듀얼모듈(Kafka/NewKafka).

**lane4-notification-api** — 알림 템플릿. NestJS 10, TypeORM 0.3.
- `POST /template`(TaskType→템플릿 생성→NotificationHistory 저장→NotificationProfile 반환), `PATCH /notification-history/:id`(상태).
- 엔티티: AllocationNotification, NotificationHistory, Template/ProviderTemplates, Client.
- 발행처(타 API)가 RabbitMQ `Lane4NotificationExchange/request`로 요청. ProviderType: SLACK/KAKAO/SMS/PUSH/MAIL/CAFE24_SMS.
- gotcha: template만 생성, **실제 발송은 notification-server**.

**lane4-notification-server** — 발송 워커. RabbitMQ 구독(@golevelup). MySQL 없음(API에 PATCH로 상태만).
- Notifier: Slack/Sms(Aligo)/KakaoAlim(Aligo)/Push(SQS→FCM)/Mail(Nodemailer)/Cafe24Sms.
- gotcha: fire-and-forget, Redis 중복방지(keyIndex TTL60s, checkDuplicationTasks만), keyIndex 검증(checkKeyIndexMatchedTasks), 실패시 ErrorExchange+Slack.

**lane4-scheduler** — 배치. @nestjs/schedule, yarn. TZ Asia/Seoul.
- 주요 cron: optimization(커넥션킬/안심번호회수), translation(주소번역 OpenAI), notification(설문/리마인더), flight(공항스크래핑 5분), exchange_rate(환율 1h), coupon(미사용 롤백 자정), report(통계 Slack), work_schedule(근무리마인더), shuttle(정기생성), driver(미반납 RETURN_BEFORE 감지), expense_document(영수증 LLM), fare(전일 정합성 1시), etc_receipt(하이패스).
- gotcha: dev 환경 조건부 스킵, 재시도 없음(실패시 로그만), 쿠폰롤백 queryRunner.

**lane4-guest-api** — 게스트 채널(비회원 공항/기프트카드/차터). NestJS 10.2, npm.
- 도메인: 비회원 공항예약(KE 항공연동), 기프트카드, 차터(air/car/golf), 결제(Toss/PortOne), 요금.
- gotcha: **KE 항공 zone 매칭 필수**, 기프트카드 TokenGuard, Currency 인터셉터. lane4-web의 주 API.

**lane4-partner-api** — 파트너/법인 채널. NestJS 10.1, yarn.
- 도메인: 법인 예약(실시간/정기/Emirates엑셀/재차), 직원/법인, 경로분석·최적화, AI 요금추천(Embedding/OpenAI), 콜메모, 대시보드.
- Kafka(실시간 예약알림), ES(경로/배차로그), 이중 Redis, DynamoDB. KE zone 특화. biz 웹의 주 API.

**lane4-emirates-api** — 에미레이츠 Gmail 연동. NestJS 9, yarn.
- 10분 cron: Gmail OAuth2→조회→base64 디코드→CDA/CDD 정규식 파싱. 5분 cron: 파싱→배차생성.
- gotcha: OAuth refresh token 하드코딩(보안위험), strictNullChecks:false, 실패시 Slack.

**lane4-klook-api** — Klook/Creatrip/DragonPass 통합 연동. NestJS 9, **npm(package-lock)**.
- Klook(Gmail 10분), Creatrip(Puppeteer 30분), DragonPass(Puppeteer 30분, 로그인). 5분: 파싱→배차.
- gotcha: **이중 Redis 둘 다 갱신**, Puppeteer 매번 새 인스턴스+close, CrawlerLock 동시방지, Creatrip 모달 nth-child, Gmail 재시도 없음.

**lane4-web-api** — BFF 예정이었으나 **현재 빈 껍데기(미사용)**. lane4-web은 guest-api 직접 호출.

**lane4_backend** — 레거시 **Spring Boot 2.3 + MyBatis(Java11/Gradle)**. PM2/nohup 배포, Jenkins CI.
- 아직 살아있는 도메인: auth, driver, car, **subscription(최복잡)**, coupon, push(자체 FCM), pay, file, sms, memo, evaluation, park, code, amount.
- gotcha: MyBatis XML 31개(컬럼변경시 쿼리수정), Firebase 직접구현, Spring Security JWT(신규와 다름), Swagger 2.9.2.

### Frontend (Next.js Pages Router)

**lane4-admin** — 어드민 웹. Next 15(Pages) + React 19, yarn. 주 API: **admin-api**.
- 3계층: `apis/{domain}/{domain}.service.ts`(AxiosV2 래퍼) → `entities/{domain}/*.queries.ts|mutations.ts`(React Query v5 queryOptions) → `pages/{domain}/*.page.tsx`.
- 응답 envelope `{ code, data, result }`, ReservedError. NextAuth(credentials). 권한 PagePermissionCheckContainer.
- gotcha: **`.page.tsx`/`.api.ts` 확장자만 라우트**, getLayout, Tailwind+styled+twin.macro+AntD5 혼용, eslint perfectionist import 정렬, overlay-kit 모달, react-toastify.

**lane4-web** — 게스트 사용자 웹. Next 15(Pages)+React 19, Node22/yarn. 주 API: **guest-api**.
- 예약플로우 serviceType enum(AIR/GOLF/ONEWAY/TWOWAY/SHUTTLE), NextAuth v4 + 게스트토큰(`X-Guest-Authorization`).
- 동일 3계층(apis/entities). Redux Toolkit(common/guestAuth, persist) + React Query v5. react-hook-form+zod.
- gotcha: `.page.tsx`만 라우트, `/[serviceType]/...` 경로, i18n next-i18next(`_::` keySep), 다중통화 `X-Currency`, MSW 모킹.

**lane4-biz** — 법인 어드민 웹. Next 15(Pages)+Node22/yarn. API: **admin-api + monitoring-api**.
- 이중 UI: `/pages/pc/*` + `/pages/mobile/*`(반응형 분리). Socket.io(제어/모니터링). **Zustand**(Redux 미사용)+React Query v5.
- AxiosV2(모니터링 전용 CustomReservedError). Playwright E2E(`/tests`, localhost:3000). i18n, AntD+Tailwind+twin.

### Mobile (React Native) — ⚠ PM 하네스 직접 구현 범위 밖(별도 처리)

**lane4-app-user** — 승객앱. RN 0.77, yarn, CodePush. Redux+Saga+Persist + React Query v3.
- API: `src/constants/api.ts`(146 상수) + `src/Services/apiClient.ts`. 주 API: app-api. Firebase RTDB/FCM.
- gotcha: CodePush OTA(`npm run codepush:*`), 레거시 Axios.ts + 신규 AxiosV2.ts.

**lane4-app-driver** — 기사앱. RN 0.81, **yarn 4.7(berry), Node≥20**, CodePush. Redux+Saga+Persist+RQ v5.
- 화면: 인증/배차팝업(Socket.io)/출근·반납(점검·계기판)/GPS추적(ES)/스마트키(BLE)/지역검색(Naver).
- API: driver-api, allocation-api(팝업), notification-api(FCM), Firebase RTDB. inline path → 공용 상수화 권장.
- gotcha: **Node 18 빌드 함정**(engines≥20), CodePush 버전 명시, Call 리듀서 사진 persist 제외.

### 공통/레거시

**lane4-backend-library** — npm priv pkg(`npm.pkg.github.com`), v0.0.149. **백엔드 12개 API가 consumer**.
- export: **NotificationUtils**(RabbitMQ `.notify()`), **TaskType**(70+ 이벤트), ProjectType/ServiceType enum, RabbitmqConstant(EXCHANGE_NOTIFICATION/ROUTING_KEY_NOTIFY_REQUEST/EXCHANGE_ERROR), **SlackChannelType**(70+), TMapUtils/FlightAwareUtils/OpenAIUtils, DateTimeUtils(js-joda), FirebaseModule.
- gotcha: **TaskType는 계약** — 추가시 notification-server 핸들러 동기화 필수. 변경시 12개 API 전부 영향(버전 bump+재설치).

**lane4-achakey** — 아차키 외부플랫폼 Puppeteer 크롤링→MySQL 동기화 어댑터. NestJS 8, 6개월+ 미사용 레거시.

**lane4-docs** — 비즈니스(`/business`)+도메인(`/domains`) 문서 허브. 도메인 질문은 여기 우선.

---

## 3. PM이 기억할 교차 관심사 (cross-cutting gotchas)

1. **이중 Redis**: 대부분 백엔드에 레거시+신규 인스턴스 공존. 같은 키 영향 시 둘 다 갱신/조회.
2. **TaskType 계약**: 알림 추가/변경은 lane4-backend-library + notification-api + notification-server 3곳 동기화.
3. **Kafka 토픽 문자열**: `local.*` 발행(driver-api 등)↔구독(monitoring-api). 문자열 enum/상수로, grep으로 consumer 확인.
4. **MyBatis XML**: admin-api, app-api, lane4_backend는 XML 매퍼 병존 → 정적분석에서 누락 주의(컬럼변경시 XML도).
5. **트랜잭션 컨벤션 불일치**: 대부분 QueryRunner 강제(@Transactional 금지)지만 **allocation-api는 @Transactional(cls-hooked) 사용** — 프로젝트별 확인.
6. **프론트 라우트 확장자**: 3개 웹 모두 `.page.tsx`만 라우트. 새 페이지는 반드시 이 확장자.
7. **상태관리 차이**: admin=React Query+Context, web=React Query+Redux, biz=React Query+Zustand.
8. **외부연동 비결정성**: emirates/klook은 Gmail/크롤링 — 재시도 없음, 토큰/셀렉터 깨짐 잦음.
9. **레거시 생존**: subscription/coupon 일부는 lane4_backend(Spring)에만 존재 가능 → 신규 API에 없으면 레거시 확인.
10. **모바일은 별도**: app-user/app-driver는 PM 하네스 직접 구현 범위 밖. 모바일 작업이 필요하면 사용자에게 알리고 분리 처리.
