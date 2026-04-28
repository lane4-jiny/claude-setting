# 코드 리뷰 체크리스트

## NestJS 패턴

### Controller
- [ ] 적절한 HTTP Method 사용 (GET/POST/PUT/PATCH/DELETE)
- [ ] Guard 설정 (@UseGuards)
- [ ] DTO 타입 지정 (@Body, @Query, @Param)
- [ ] Swagger 데코레이터 (@ApiOperation, @ApiResponse)
- [ ] 비즈니스 로직이 Controller에 없는지 확인
- [ ] 응답 형식 통일 (Response DTO 사용)

### Service
- [ ] 다중 쓰기 작업시 트랜잭션 처리 (@Transactional 또는 QueryRunner)
- [ ] Repository를 통한 DB 접근 (직접 쿼리 지양)
- [ ] 에러 핸들링 (적절한 HttpException 사용)
- [ ] 외부 서비스 호출시 try-catch
- [ ] 비즈니스 로직과 데이터 접근 분리

### Repository
- [ ] TypeORM QueryBuilder 또는 Repository 패턴 사용
- [ ] 조회시 필요한 컬럼만 select
- [ ] JOIN시 필요한 관계만 로드
- [ ] 페이지네이션 적용 (대량 데이터 조회시)
- [ ] WHERE 조건 누락 확인

### DTO / Entity
- [ ] class-validator 데코레이터 적용 (@IsString, @IsNumber 등)
- [ ] @IsOptional() 적절히 사용
- [ ] Entity 컬럼 타입과 DB 스키마 일치
- [ ] 민감 정보 @Exclude() 처리

## 보안

- [ ] 인증 필요 API에 Guard 설정
- [ ] 권한 체크 (역할별 접근 제어)
- [ ] SQL Injection 방어 (파라미터 바인딩)
- [ ] XSS 방어 (사용자 입력값 이스케이프)
- [ ] 비밀번호/토큰 등 민감 정보 로그 출력 금지
- [ ] .env 파일에 시크릿 관리 (하드코딩 금지)
- [ ] 파일 업로드시 확장자/크기 검증
- [ ] Rate Limiting 적용 여부

## 성능

- [ ] N+1 쿼리 패턴 확인 (반복문 내 DB 조회)
- [ ] 불필요한 eager loading 제거
- [ ] 대량 데이터 처리시 chunking/streaming
- [ ] 캐싱 적용 가능 여부
- [ ] 인덱스 활용 여부 (WHERE/ORDER BY 컬럼)
- [ ] 불필요한 await 중첩 (병렬 처리 가능한 경우)

## 에러 핸들링

- [ ] try-catch 블록 적절히 사용
- [ ] 에러 메시지에 민감 정보 미포함
- [ ] 에러 로깅 적절히 수행
- [ ] 사용자에게 의미있는 에러 응답 반환
- [ ] 외부 API 호출 실패시 fallback/retry 로직

## 테스트

- [ ] 핵심 비즈니스 로직 테스트 존재
- [ ] 엣지 케이스 테스트
- [ ] 모킹 적절히 사용
- [ ] 테스트 데이터 하드코딩 최소화
