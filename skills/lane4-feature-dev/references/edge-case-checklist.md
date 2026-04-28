# Edge Case Checklist (Pre-flight Step 3)

각 항목은 "조건 → 점검" 형식. 조건이 맞으면 사용자에게 명시적으로 보고하거나 질문한다.

## Backend (NestJS) Edge Cases

### EC-B1: Redis 캐싱 추가 in lane4-driver-api
**조건**: cwd가 `lane4-driver-api` AND 새 코드가 Redis 사용
**점검**: 어느 인스턴스를 쓸지 사용자에게 질문
- `commons/redis/` (legacy ioredis, `@InjectRedis()`)
- `commons/newRedis/` (new instance)
- `commons/cache/` (cache-manager 추상화)
**기본값**: 같은 도메인의 기존 코드가 쓰는 인스턴스를 따라간다. 도메인이 새거면 질문 필수.

### EC-B2: Entity 컬럼 수정/추가
**조건**: `src/entities/*.ts` 변경 포함
**점검**:
- [ ] MyBatis XML에서 해당 컬럼/테이블 사용 여부 확인 (`find-mybatis-refs.sh`)
- [ ] Redis 캐시 키에 해당 컬럼/테이블 ID 포함 여부 (`find-cache-refs.sh`)
- [ ] 다른 백엔드가 같은 엔티티를 import하는지 (`find-callers.sh <ClassName>`)
- [ ] 마이그레이션 SQL 별도 작성 필요 (synchronize: false이므로)
**기본 동작**: 위 4개 도구를 자동 실행하여 결과 보고

### EC-B3: 신규 Kafka 이벤트
**조건**: 새 producer 추가 OR 기존 토픽 rename
**점검**:
- [ ] 토픽명이 컨벤션(`local.<domain>.<event>`) 따르는가
- [ ] consumer가 이미 있는지 (`find-kafka-refs.sh`) — 이름 충돌 방지
- [ ] 메시지 DTO 인터페이스 위치 (`commons/kafka/.../message/` 패턴)
- [ ] consumer 측 변경 동반 필요한가 (대부분 lane4-monitoring-api 또는 lane4-scheduler)

### EC-B4: 응답 envelope 사용 확인
**조건**: 새 controller 메서드 추가
**점검**: 컨트롤러는 DTO 그대로 반환 (글로벌 인터셉터가 envelope 래핑). 사용자가 직접 `{ code, data, result }`를 만들면 잘못된 패턴.
**경고**: 사용자가 명시적으로 envelope 만든 코드 작성하면 "글로벌 인터셉터가 자동 래핑하므로 DTO만 반환하세요"

### EC-B5: 공유 라이브러리 enum 사용
**조건**: 코드에서 `ServiceType`, `ProjectType`, `TaskType`, `SlackChannelType` 등 사용
**점검**:
- [ ] `@lane4company/lane4-backend-library`에서 import (deep import 금지)
- [ ] 로컬 enum 중복 정의 (`src/commons/enum/e.*.type.ts`)와 충돌 없는가
- [ ] enum 값 추가는 라이브러리 자체 수정 → 별도 PR (큰 영향)

### EC-B6: Auth Guard 누락
**조건**: 새 controller 메서드 추가
**점검**: `@UseGuards(...)` 또는 `@Public()` 명시 필요. 미명시면 기본 동작 불명확.
**기본**: 사용자에게 인증 정책 질문

### EC-B7: lane4-allocation-api는 microservice
**조건**: cwd가 `lane4-allocation-api`
**점검**: HTTP 컨트롤러 아닌 `@MessagePattern('...')` 사용. REST API 추가 시도 시 사용자에게 "이 프로젝트는 Redis microservice입니다. HTTP 8080 포트는 별도 모듈이며, 일반적으론 `@MessagePattern` 패턴을 따릅니다" 안내

### EC-B8: TypeORM 트랜잭션
**조건**: 한 서비스 메서드에서 여러 entity write
**점검**: `@Transactional()` 데코레이터 또는 `dataSource.transaction()` 사용 권장. 빠지면 부분 실패 가능.

### EC-B9: Raw SQL (MyBatis XML)
**조건**: 사용자가 복잡한 join/aggregation 요청
**점검**: TypeORM `createQueryBuilder`로 표현 가능한지 먼저 검토. 명백히 어려우면 MyBatis XML 추가 (lane4-admin-api 패턴).
**경고**: lane4-admin-api 외 프로젝트에서 MyBatis 추가는 인프라 일관성 깨짐 → 사용자 확인

### EC-B10: 알림 트리거
**조건**: 새 도메인 이벤트 발생 (배차/결제/상태 변경 등)
**점검**: 알림 보낼 필요 있는지 사용자에게 질문. 있으면:
- FCM/APNS push: `@lane4company/lane4-backend-library`의 `NotificationUtils` 또는 lane4-notification-api 호출
- 알림톡: lane4-notification-api 거쳐서
- Slack: `SlackChannelType` enum + Slack webhook

## Frontend (Next.js) Edge Cases

### EC-F1: 새 API 호출 위치
**조건**: 컴포넌트가 새로운 backend endpoint 호출
**점검**:
- [ ] `apis/<domain>/<domain>.service.ts`에 static 메서드 추가 (인라인 axios 직접 호출 금지)
- [ ] 응답/요청 타입은 `apis/<domain>/<domain>.type.ts`에 정의
- [ ] 같은 도메인 파일이 없으면 새 폴더 생성

### EC-F2: 새 type 정의 시 중복 검사
**조건**: 새 DTO 타입 정의
**점검**: 같은 이름의 타입이 다른 프로젝트(lane4-web/admin/biz) 또는 같은 프로젝트 다른 곳에 이미 있는지 grep
**경고**: 중복 발견 시 "이미 X에 정의됨. 일관성 위해 그쪽 따라갈지, 별도로 갈지 결정 필요"

### EC-F3: React Query 캐시 invalidation
**조건**: 새 mutation 추가 (POST/PUT/PATCH/DELETE)
**점검**:
- [ ] mutation 성공 시 어떤 query를 invalidate할지 결정
- [ ] queryKey 일관성 (`['domain', ...sub]`) 따름
**기본**: 같은 도메인의 모든 query를 invalidate (`AuthQueries.keys.all`)

### EC-F4: react-hook-form + Zod 사용
**조건**: 새 폼 컴포넌트
**점검**: react-hook-form + zodResolver 패턴 사용. 다른 라이브러리 사용 시 사용자 확인.

### EC-F5: 동적 path (templated URL)
**조건**: 서비스 메서드 url에 백틱 템플릿 리터럴 사용
**점검**: backend의 controller route와 정확히 일치하는지 확인
- 예: 프론트 `cards/${cardId}` → backend `@Get(':id')` (path: `/api/cards/:id`)

### EC-F6: 응답 envelope 직접 처리 금지
**조건**: 새 서비스 메서드
**점검**: `.then((res) => res.data)` 패턴 사용. `res.code`, `res.result` 직접 접근하면 컨벤션 위반.
**경고**: 직접 envelope 처리 코드 작성 시 "Axios wrapper가 이미 처리하므로 .data만 추출하세요"

### EC-F7: 공통 컴포넌트 vs 페이지 컴포넌트
**조건**: 컴포넌트 추가
**점검**: 재사용성 1회면 페이지 옆, 2회 이상이면 `components/`. 사용자에게 위치 질문 권장.

### EC-F8: i18n
**조건**: 새 텍스트 (lane4-web만)
**점검**: lane4-web은 i18next-scanner 사용. 새 텍스트는 i18n 키로 분리. lane4-admin/biz는 보통 직접 한국어.

### EC-F9: Cypress E2E
**조건**: 새 페이지/플로우 추가 (lane4-web)
**점검**: `cypress/` 디렉토리에 E2E 테스트 추가 권장. 사용자에게 필요 여부 질문.

### EC-F10: 환경변수 추가
**조건**: 새 `process.env.NEXT_PUBLIC_*` 사용
**점검**:
- [ ] `.env.development`, `.env.production` 모두 추가
- [ ] `next.config.js`에 노출 등록 필요 여부
- [ ] `NEXT_PUBLIC_` prefix 필수 (브라우저 접근)

## 공통 (Backend + Frontend)

### EC-C1: 외부 시스템 변경
**조건**: Firebase, Redis, ES, Kafka 토픽 등 외부 의존성 변경
**점검**:
- [ ] .env 변경 동반 필요한가
- [ ] 운영 환경 인프라 변경(인덱스 추가, 토픽 생성) 필요한가
- [ ] 다른 프로젝트와 동기화 필요한가
**기본**: 자동 변경 금지. 사용자에게 명시적 확인 + 인프라 팀 협의 필요 안내

### EC-C2: lane4-backend-library 변경
**조건**: cwd가 `lane4-backend-library`
**점검**: 모든 백엔드가 영향. 신규 export는 안전하나 기존 export signature 변경은 무조건 impact-analysis 자동 호출.

### EC-C3: 한국어/영어 혼용
**조건**: 식별자/주석 작성 시
**점검**:
- 식별자(클래스/함수/변수): 영문 camelCase / PascalCase
- 주석: 한국어 OK (도메인 용어 자연스러움)
- 사용자 노출 텍스트: 한국어 (i18n key 또는 직접)
- 커밋 메시지: 한국어 (lane4 컨벤션)

### EC-C4: 신규 도메인 vs 기존 도메인
**조건**: 새 기능이 기존 도메인 폴더에 들어가는지 새 폴더 만드는지 모호
**점검**: 사용자에게 질문. 기본은 기존 도메인 확장 (YAGNI).
