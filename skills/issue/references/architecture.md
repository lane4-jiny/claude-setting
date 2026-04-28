# 아키텍처

서비스 간 호출 흐름과 주요 컴포넌트 구조를 정의한다.

## 공통 기술 스택

- **백엔드**: NestJS + TypeScript + TypeORM 0.2.x
- **DB**: MySQL (Master-Slave Replication, AWS Aurora RDS)
- **캐시**: Redis (ioredis)
- **인증**: JWT + Passport.js (Access Token + Refresh Token)
- **프론트**: Next.js 15 + React 19 + Ant Design + Tailwind CSS
- **모니터링**: Sentry + Datadog

## 전체 흐름

```
[lane4-admin]  → [lane4-admin-api]    ──┐
[lane4-biz]    → [lane4-partner-api]  ──┤
[lane4-web]    → [lane4-guest-api]    ──┼──→ [MySQL DB (Master-Slave)]
[App]          → [lane4-app-api]      ──┤         ↕
[기사앱]        → [lane4-driver-api]   ──┤    [Redis Cache]
                                        │
[lane4-monitoring-api] ←─ Socket.IO ──┘
         ↕
    [Kafka] ←→ [lane4-notification-api] → [SQS] → Push 발송

외부 서비스:
  - PG사 (Toss, PortOne, KCP)
  - Firebase (푸시, 배차 상태)
  - AWS (S3, SQS, DynamoDB, Secrets Manager)
  - Slack Webhook
  - 지도 API
```

## API 요청 처리 흐름 (모든 백엔드 공통)

```
HTTP Request
  → LoggerMiddleware (요청 로깅, RequestID)
  → RequestLoggingInterceptor (요청/응답 로깅)
  → JwtAuthGuard (JWT 토큰 검증, @Public() 시 스킵)
     → Passport JwtStrategy → EmployeeService/UserService 검증
  → RolesGuard (역할 기반 권한, @Roles() 데코레이터)
  → ValidationPipe (class-validator DTO 검증)
  → Controller (라우팅)
  → Service (비즈니스 로직)
  → Repository (TypeORM 쿼리)
  → MySQL DB
  → Response
  → GlobalHttpExceptionHandler / GlobalExceptionHandler (예외 처리)
  → SentryInterceptor (에러 추적)
```

## 프로젝트별 주요 모듈

| 모듈 | 역할 | 존재하는 프로젝트 |
|------|------|-----------------|
| allocation | 배차 처리 | admin-api, partner-api, guest-api, app-api, driver-api, monitoring-api |
| reservation | 예약 관리 | admin-api, partner-api, guest-api, app-api |
| driver | 기사 관리 | admin-api, partner-api, driver-api, monitoring-api |
| car | 차량 관리 | admin-api, partner-api, app-api, driver-api, monitoring-api |
| company | 법인 관리 | admin-api, partner-api |
| payment/toss/portone | 결제 | admin-api(PortOne), guest-api(Toss/PortOne), app-api(KCP) |
| notification | 알림/푸시 | admin-api, partner-api, notification-api |
| auth | 인증/인가 | 전체 |
| fare | 요금 관리 | admin-api, partner-api, guest-api, app-api |
| coupon | 쿠폰 | admin-api, guest-api, app-api |
| shuttle | 셔틀 | guest-api, app-api, driver-api |

## 메시징/이벤트 흐름

| 기술 | 사용 프로젝트 | 용도 |
|------|-------------|------|
| Kafka | admin-api, partner-api, app-api, driver-api, monitoring-api | ES 동기화, 드라이버 갱신, FCM 푸시 |
| RabbitMQ | notification-api | 알림 메시지 큐 |
| AWS SQS | admin-api, guest-api, app-api, notification-api | 푸시 발송, 비동기 처리 |
| Socket.IO | monitoring-api, lane4-biz | 실시간 차량관제 |

## 캐시 전략

| 대상 | 저장소 | TTL | 갱신 조건 |
|------|--------|-----|----------|
| 세션/토큰 | Redis | - | 로그인/로그아웃 |
| 배차 상태 | Firebase | - | 상태 변경 시 |

## 외부 연동

| 서비스 | 용도 | 사용 프로젝트 |
|--------|------|-------------|
| Toss Payments | 결제/환불 | guest-api |
| PortOne (아임포트) | 결제/환불 | admin-api, guest-api |
| KCP | 결제 | app-api |
| Firebase | 푸시 알림, 배차 상태 저장 | admin-api, partner-api, guest-api, driver-api, monitoring-api |
| AWS S3 | 파일 업로드 (cdn.lane4.ai) | admin-api, partner-api, notification-api |
| AWS DynamoDB | 예약 공유 | partner-api, guest-api |
| AWS Secrets Manager | 환경 설정 | partner-api, monitoring-api, notification-api |
| Elasticsearch | 검색/분석 | admin-api, partner-api, monitoring-api |
| Slack Webhook | 운영 알림 | 전체 |
| 지도 API | 경로/거리 계산 | guest-api, app-api |
| FlightAware AeroAPI | 항공편 정보 | partner-api |
| SK Telecom SAFEN | 안전번호 | partner-api |

## 인증 방식 요약

| 프로젝트 | 인증 대상 | 토큰 Payload 주요 필드 |
|---------|----------|---------------------|
| admin-api | 사원 (Employee) | userid, username, authorityNm, compCd |
| partner-api | 사원 (Employee) | empId, empNm, authority, compCd, employeeIndex |
| guest-api | 사용자 (User) | userId, authorityName, userName, compCode, lastLoginDt |
| app-api | 사용자 (User) | userId, userNm, compCd, authorityNm, drtAgree |
| driver-api | 기사 (Driver) | mobile + password 기반 |
| monitoring-api | JWT | ConfigService 동적 관리 |
