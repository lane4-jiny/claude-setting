# Lane4 이슈 진단 패턴

> 자주 발생하는 이슈 유형별 빠른 진단 경로

---

## 배차(Allocation) 이슈

### 배차 생성 실패
1. allocation-api: TB_DATE_POLICY 예약 가능일자 정책 확인
2. 요금 계산: fare 도메인 → AMOUNT 테이블
3. 서비스 지역 검증: service_region 도메인
4. 차량 가용성: car 도메인 → CAR 테이블
5. 로그: Sentry + Slack 알림 채널

### 배차 상태 미전환 (NORMAL → END 미진행)
1. scheduler: checkStatus (1시간 주기) → Slack 알림
2. DB: ALLOC_STATUS_HIST 확인
3. driver-api: Kafka `begin-driving` 이벤트 발행 여부
4. monitoring-api: 위치 수신 여부

### 배차 자동생성 실패 (Emirates/Klook)
1. emirates-api: Gmail API OAuth 토큰, PARSING 테이블(isComplete)
2. klook-api: Gmail API(Klook) / Puppeteer 쿠키 만료(Creatrip)
3. 주소 번역: ADDRESS_TRANSLATION 테이블
4. TMap 주소 변환 실패 여부

---

## 결제 이슈

### 결제 실패
1. PG 응답: PAY_TRX, PG_REQ, PG_RES 테이블
2. 빌링키: CREDIT_CARD 테이블
3. 쿠폰 적용: CPN_REQ 테이블
4. PG별 확인: Toss(guest-api), PortOne(guest-api,app-api), KCP(admin-api,app-api,lane4_backend)

### 결제 취소/환불 실패
1. PAY_CAN_TRX 테이블 상태
2. PG_CAN_REQ, PG_CAN_RES 테이블
3. PG 게이트웨이 직접 조회 (관리자 콘솔)

---

## 알림 이슈

### 알림 미발송
1. DB: NOTIFICATION_HISTORY (STATUS: P=대기, S=성공, E=오류)
2. RabbitMQ: requestQueue, errorQueue 상태
3. notification-server 로그 (Sentry)
4. Redis 중복방지 키 (60초 TTL)
5. Aligo SMS 잔액 (scheduler 1시간 주기 확인)

### 채널별 진단
- **Kakao AlimTalk**: 템플릿 코드 불일치 → notification-api TaskType 매핑 확인
- **SMS**: Aligo 잔액 부족 또는 수신 번호 유효성
- **Push**: FCM 토큰 만료 → PUSH_TRX 테이블, Firebase 콘솔
- **Email**: SES 반송(bounce) → AWS SES 콘솔

---

## 관제 이슈

### 기사 위치 미수신
1. app-driver: Background Geolocation 설정/권한
2. monitoring-api: WebSocket /drivers 연결 상태
3. Kafka: `driver-location` 토픽 메시지 유무
4. Redis: `{driver}:location` 키 확인
5. Elasticsearch: 인덱싱 상태
6. scheduler: 5분 이상 미수신 시 Slack 알림

### 관제 패널 데이터 지연
1. monitoring-api: Kafka consumer lag
2. Elasticsearch 인덱싱 속도
3. WebSocket /monitoring 룸 상태 (Redis)

---

## 앱 이슈

### CodePush/강제 업데이트 실패
1. CodePush 배포 상태 (AppCenter)
2. Firebase RTDB: 버전 체크 값
3. CloudFront CDN (cdn.lane4.ai) 번들 상태

### 소셜 로그인 실패
1. OAuth 프로바이더 상태 (Kakao/Naver/Google/Apple)
2. 백엔드 auth 도메인 로그
3. JWT 토큰 발급/갱신 실패 여부

### 스마트키(BLE) 실패
1. OTORIDE API 상태
2. BLE 블루투스 연결
3. 차량 제어 권한: driver-api `/driver/cars`

---

## 인프라 이슈

### DB 커넥션 부족
1. scheduler: MySQL Sleep 300초 초과 커넥션 킬 (1분 주기) 동작 확인
2. Aurora RDS 모니터링: 커넥션 수
3. TypeORM pool 설정 확인

### Kafka 지연
1. MSK 콘솔: consumer group lag
2. monitoring-api: 11개 consumer 상태
3. producer 발행 실패 로그 (Sentry)

### Redis 장애
1. ElastiCache 모니터링
2. allocation-api: Redis RPC 응답 실패
3. driver-api: 위치 저장/Redlock 실패
4. notification-server: 중복방지 키 실패

---

## 공통 진단 도구

| 도구 | 용도 | 접근 |
|------|------|------|
| Sentry | 에러 스택트레이스 | 프로젝트별 대시보드 |
| Datadog | APM/성능 | Datadog 대시보드 |
| Slack | 운영 알림 이력 | 채널별 확인 |
| Swagger | API 테스트 | `{api-url}/api` |
| MySQL | DB 조회 | Aurora RDS master/slave |
| Redis | 캐시/세션 | ElastiCache |
| Kafka | 메시지 | MSK 콘솔 |
| RabbitMQ | 알림 큐 | Amazon MQ 콘솔 |
| Elasticsearch | 로그/위치 | Elastic Cloud |
