# 에러 패턴

자주 발생하는 에러 유형과 원인 탐색 위치를 정리한다.

## API 에러

| 에러 | 주요 원인 | 탐색 위치 |
|------|----------|----------|
| 500 Internal Server Error | 미처리 예외, NPE, DB 커넥션 풀 고갈 | Controller → Service → Repository 순 추적, GlobalExceptionHandler 로그 |
| 400 Bad Request | class-validator 검증 실패, 필수값 누락 | DTO의 @IsNotEmpty, @IsString 등 데코레이터, ValidationPipe |
| 401 Unauthorized | JWT 토큰 만료, 유효하지 않은 토큰 | JwtStrategy.validate(), JwtAuthGuard |
| 403 Forbidden | 역할(Role) 부족 | RolesGuard, @Roles() 데코레이터 |
| 404 Not Found | 잘못된 URL, 삭제된 리소스 | 라우팅 설정, Repository에서 findOne 결과 null |
| 409 Conflict | 중복 요청, 동시성 이슈 | 유니크 제약조건, TypeORM QueryRunner 락 |
| Timeout | 느린 쿼리, 외부 API 지연 | TypeORM 쿼리, Axios 타임아웃 설정 |

## 데이터 이슈

| 증상 | 주요 원인 | 탐색 위치 |
|------|----------|----------|
| 데이터 불일치 | queryRunner 트랜잭션 미적용, 부분 업데이트 | queryRunner.startTransaction/commit/rollback 범위 |
| 상태 전이 실패 | 결제 콜백 미호출, 클라이언트 주도 상태 변경 누락 | completePayment(), status 변경 로직 |
| 중복 데이터 | 유니크 제약조건 미설정, 재시도 시 멱등성 미처리 | Entity 유니크 데코레이터, 중복 체크 로직 |
| 데이터 누락 | 조건 분기 오류, 상태값 불일치 | 비즈니스 로직 if/switch 분기문, enum 값 확인 |
| DB-Firebase 불일치 | DB 업데이트 후 Firebase 갱신 실패 | Firebase set/update 호출 누락 또는 에러 |

## 결제 이슈

| 증상 | 주요 원인 | 탐색 위치 |
|------|----------|----------|
| 결제 완료인데 상태 미변경 | confirm API 미호출 (클라이언트 주도 방식) | toss.service.ts verify/confirm, reservation.service.ts verifyPayment |
| 결제 금액 불일치 | 쿠폰/할인 적용 로직 오류 | Allocations.completePayment(), PayTrx 저장 로직 |
| 결제 취소 실패 | PG사 API 응답 에러 | PortOne/Toss/KCP 취소 API 호출부 |
| 이중 결제 | validateStatusesBeforePayment 통과 후 동시 요청 | Allocations.validateStatusBeforePayment(), 동시성 제어 |

## 연동 이슈

| 증상 | 주요 원인 | 탐색 위치 |
|------|----------|----------|
| PG 결제 실패 | 인증키 만료, API 스펙 변경 | toss.utils.ts, port.one.utils.ts, .env 설정값 |
| Firebase 발송 실패 | FCM 토큰 만료, 서비스 계정 키 만료 | custom-firebase 도메인, firebase-admin 설정 |
| Redis 연결 실패 | 커넥션 풀 고갈, 서버 다운 | ioredis 설정, NEW_REDIS_HOST 환경변수 |
| Kafka 메시지 누락 | 브로커 연결 실패, 토픽 미생성 | KafkaModule 설정, consumer/producer 로직 |
| Elasticsearch 검색 오류 | 인덱스 매핑 불일치, 인증 실패 | @nestjs/elasticsearch 설정, 쿼리 빌더 |
| Slack 알림 미발송 | Webhook URL 만료 | @slack/webhook 설정 |
| AWS SQS 실패 | IAM 권한 부족, 큐 URL 오류 | @aws-sdk/client-sqs 설정 |

## 인증/인가 이슈

| 증상 | 주요 원인 | 탐색 위치 |
|------|----------|----------|
| 로그인 실패 | 비밀번호 불일치, 계정 비활성화 | AuthService.signIn(), bcrypt.compare(), Employee/User 활성화 검증 |
| 토큰 갱신 실패 | Refresh Token 만료, 유효하지 않은 토큰 | JwtRefreshStrategy, JWT_REFRESH_TOKEN_SECRET |
| 권한 오류 | Role 미설정, Guard 순서 문제 | @Roles() 데코레이터, RolesGuard, authority 필드값 |
| 소셜 로그인 실패 | 소셜 서비스 토큰 만료, 연동 설정 오류 | KakaoLoginService, NaverLoginService 등 (guest-api, app-api) |
