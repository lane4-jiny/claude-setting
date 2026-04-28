# 트러블슈팅 가이드

이슈 유형별 탐색 전략과 MCP 도구 활용 기준을 정의한다.

## 이슈 유형별 탐색 전략

### API 에러 (500, 400 등)
1. 에러 메시지/스택트레이스에서 발생 클래스 특정
2. 해당 Controller → Service → Repository 순으로 추적
3. DTO의 class-validator 데코레이터, ValidationPipe 검증 확인
4. GlobalHttpExceptionHandler / GlobalExceptionHandler 에러 로그 확인
5. 필요 시 lane4-mysql로 HTTP_LOG 테이블 조회하여 실제 요청/응답 확인

### 데이터 정합성 이슈
1. lane4-mysql로 실제 데이터 상태 조회 (ALLOCATION, CALL_REQ, PAY_TRX 등)
2. 데이터를 생성/수정하는 Service 로직 역추적
3. queryRunner 트랜잭션 범위 확인 (startTransaction/commit/rollback)
4. DB와 Firebase 간 데이터 싱크 확인
5. 관련 스케줄러(@nestjs/schedule)가 있다면 배치 로직도 확인

### 결제 이슈
1. 결제 방식 확인: Toss(guest-api), PortOne(admin-api/guest-api), KCP(app-api)
2. 결제 상태 전이 추적: '00'(결제전) → '정상'(탑승전)
3. PG 콜백/confirm API 호출 여부 확인 (클라이언트 주도 방식 주의)
4. PAY_TRX, PG_REQ, PG_RES 테이블로 결제 기록 대조
5. completePayment() 호출 경로와 트랜잭션 범위 확인

### 연동 이슈 (PG, Firebase, Redis, Kafka 등)
1. 연동 클라이언트 설정 확인 (.env, infrastructure/ 폴더)
2. 요청/응답 DTO와 매핑 로직 확인
3. 에러 핸들링 로직 확인 (try-catch, rollback)
4. Kafka: consumer/producer 설정, 토픽 확인
5. elasticsearch MCP로 연동 에러 로그 조회

### 화면/UI 이슈
1. 프론트 프로젝트 특정 (lane4-admin, lane4-biz, lane4-web)
2. 프론트 apis/ 폴더에서 호출하는 API 엔드포인트 특정
3. API 응답 데이터와 화면 렌더링 로직 비교
4. 상태 관리 확인: admin(Context), biz(Zustand), web(Redux Toolkit)
5. 네트워크 요청 순서 및 race condition 확인

### 인증/인가 이슈
1. 프로젝트별 JWT 토큰 Payload 구조 확인 (architecture.md 참조)
2. JwtStrategy.validate() → Employee/User 검증 로직 추적
3. @Roles() 데코레이터와 RolesGuard 권한 매핑 확인
4. @Public() 또는 @SkipAuth() 설정 누락 여부
5. 소셜 로그인 시 외부 서비스 토큰 유효성 확인

### 실시간/소켓 이슈
1. lane4-monitoring-api의 Socket.IO Gateway 확인
2. Kafka 메시지 수신/발행 확인
3. Redis pub/sub 또는 캐시 상태 확인
4. 클라이언트(lane4-biz) Socket.IO 연결 상태 확인

## MCP 활용 기준

| 상황 | 사용할 MCP | 확인 사항 |
|------|-----------|----------|
| 데이터 값이 이상할 때 | lane4-mysql | ALLOCATION, CALL_REQ, PAY_TRX 등 실제 레코드 조회 |
| HTTP 요청 로그 확인 | lane4-mysql | HTTP_LOG 테이블에서 요청/응답 이력 확인 |
| 캐시 관련 이슈 | redis MCP | 캐시 키 존재 여부, TTL, 저장된 값 |
| 에러 로그 검색, 기사 상태 변경 로그 검색, 기사 위치 정보 검색, 실경로 검색 | elasticsearch MCP | 에러 로그 검색, 인덱스 매핑 확인 |
| 푸시/알림/배차상태 | firebase MCP | FCM 토큰, 배차 상태 데이터 확인 |

## 이슈 접수 시 필수 확인 정보

사용자에게 다음 정보가 부족하면 추가로 요청한다:

- **에러 메시지/로그**: 스택트레이스 또는 에러 코드
- **발생 환경**: 개발(dev) / 운영(prod)
- **발생 시점**: 언제부터 발생했는지, 특정 시점 이후인지
- **재현 조건**: 특정 사용자/데이터/조건에서만 발생하는지
- **영향 범위**: 전체 사용자 vs 특정 사용자/법인
- **관련 프로젝트**: 어드민/법인어드민/웹/앱/기사앱 중 어디서 발생했는지
