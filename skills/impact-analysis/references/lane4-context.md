# Lane4 Codebase Context (Baked-in Facts)

이 문서는 `impact-analysis` 스킬이 사용하는 lane4 코드베이스의 사실 모음이다. 2026-04 시점 분석 기준이며 코드가 변하면 갱신해야 한다.

## 워크스페이스 구조

루트: `/Users/ojieun/IdeaProjects/`

### Backend APIs (NestJS, 14개)
- `lane4-admin-api` — 어드민 API (REST + MyBatis XML)
- `lane4-app-api` — 사용자 앱 API (REST)
- `lane4-driver-api` — 기사 앱 API (REST, Kafka producer 다수)
- `lane4-allocation-api` — **Redis microservice** (`@MessagePattern`), HTTP 8080은 별도
- `lane4-monitoring-api` — 관제 (Kafka consumer)
- `lane4-notification-api` — 알림 (RabbitMQ 사용)
- `lane4-notification-server` — 알림 워커
- `lane4-scheduler` — 배치
- `lane4-guest-api`, `lane4-partner-api` — 게스트/파트너
- `lane4-emirates-api`, `lane4-klook-api` — 외부 연동
- `lane4-web-api` — 웹 BFF
- `lane4_backend` — 레거시

### Frontend (Next.js, 3개)
- `lane4-admin`, `lane4-web`, `lane4-biz`

### Mobile (React Native, 2개)
- `lane4-app-driver`, `lane4-app-user`

### 공유 (2개)
- `lane4-backend-library` — npm: `@lane4company/lane4-backend-library`
- `lane4-achakey`

## lane4-backend-library Public API

**Package**: `@lane4company/lane4-backend-library`
**Build**: TS source → CommonJS + .d.ts at `dist/src/`
**Entry**: `src/index.ts` (top-level barrel만, 서브모듈 export 없음)

### 10개 named exports

| Export | 종류 | 파일 |
|--------|-----|-----|
| `TMapUtils` | class | `src/tmap/t-map.utils.ts` |
| `DateTimeUtils` | class (~90 static methods) | `src/datetime/date.time.utils.ts` |
| `NotificationUtils` | class (RabbitMQ dispatcher) | `src/notification/notification.utils.ts` |
| `FlightAwareUtils` | class | `src/flight_aware/flight.aware.utils.ts` |
| `OpenAIUtils` | class | `src/openai/open.ai.utils.ts` |
| `FirebaseModule` | NestJS Module | `src/firebase/firebase.module.ts` |
| `TaskType` | enum (100+ values) | `src/notification/domain/task.type.ts` |
| `ProjectType` | enum (USER/DRIVER/GUEST/PARTNER/ADMIN/MONITORING/PARSING/BRAND/SCHEDULER) | `src/commons/enum/project.type.ts` |
| `ServiceType` | enum (ONEWAY/TWOWAY/RENT/AIR/GOLF/SECTION/SHUTTLE/ETC) | `src/commons/enum/service.type.ts` |
| `SlackChannelType` | enum (~35 values) | `src/notification/domain/slack.channel.type.ts` |

### Consumer import 패턴
```typescript
// 표준 (안정)
import { DateTimeUtils, ProjectType, ServiceType } from '@lane4company/lane4-backend-library';

// fragile — deep import (사용 자제)
import { TMapAddress } from '@lane4company/lane4-backend-library/dist/src/tmap/route/...';
```

## Backend API 패턴

### 디렉토리 (NestJS DDD)
```
src/
├── domains/<domain>/
│   ├── presentation/    # *.controller.ts
│   ├── application/     # *.service.ts + dto/
│   ├── domain/          # entity, repository interface
│   └── infrastructure/  # external integrations
├── entities/            # 공유 TypeORM 엔티티 (lane4-driver-api 기준 112+)
├── commons/redis|cache|kafka|exceptions/
├── auth/
├── lib/
│   └── mapper/*.xml     # ⚠ MyBatis XML (lane4-admin-api에 다수)
└── main.ts
```

### 라우팅
- 글로벌 prefix `/api`
- 컨트롤러: `@Controller('drivers')` + `@Get('/:id')` 등
- 버전: 명시 없음 (legacy `version: 2` 쿼리 파라미터 일부 잔존, lane4-app-driver `driver.service.ts`에 TODO 주석)

### DTO
- 위치: `src/domains/<domain>/application/dto/` 또는 `src/<module>/dto/`
- 네이밍: `*.request.ts`, `*.response.ts`, 일부 `*.dto.ts`

### lane4-allocation-api 예외
- `Transport.REDIS` microservice (`main.ts`)
- HTTP가 아닌 `@MessagePattern('create_allocation_golf')` 같은 메시지 라우팅
- 별도 HTTP 서버는 8080 포트 (`HttpModule`)

## Inter-Service Communication

### Kafka (주력)
- 토픽 컨벤션: `local.<service>.<event>` (예: `local.driver.begin-driving`, `local.monitoring.send-monitoring-notification`)
- Producer: `*.producer.ts` 파일에서 `this.kafka.emit('topic', JSON.stringify(message))`
- Consumer: `*Consumer.ts` 또는 `consumer.subscribe({ topic: '...' })`
- 베이스: `KafkaBaseProducer` (lane4-admin-api/src/commons/kafka/...)

### RabbitMQ (알림 전용)
- `NOTIFICATION_MQ_URL` (amqps://) — `lane4-notification-api`
- Kafka와 분리됨

### Redis microservice
- `lane4-allocation-api`만 RPC 스타일 (`@MessagePattern`)

## TypeORM / DB

- 엔티티: `src/entities/` — `lane4-driver-api`에 가장 많고 다른 프로젝트가 공유
- `synchronize: false` — 스키마는 외부 관리
- 마이그레이션 폴더 없음
- **Raw SQL은 MyBatis XML에서만** (`lane4-admin-api/src/lib/mapper/*.xml`)
- Repository는 `createQueryBuilder` 위주

## Redis / 캐시

### lane4-driver-api는 인스턴스 3개 ⚠️
- `commons/redis/` — `@InjectRedis()` ioredis legacy
- `commons/newRedis/` — new instance
- `commons/cache/` — `@Inject(CACHE_MANAGER)` cache-manager 추상화

### 키 패턴 (lane4-driver-api `commons/redis/custom.redis.service.ts`)
- 슬롯 해시 prefix: `{driver}:*` (cluster slot 고정)
- 예시:
  - `{driver}:location` — geolocation sorted set
  - `{driver}:history:%s` (driverScheduleId)
  - `{driver}:geohash:%s` (driverId)
  - `{driver}:call:dispatch:%s` (callId)
  - `{driver}:location:monitoring`
  - `DRIVER_%s` (driverId)
- 빌더: 각 도메인의 private method, 중앙 레지스트리 없음

### lane4-admin-api
- `@nestjs/cache-manager` 사용
- `operational-analytics:%s:revenue` 같은 hash key (`hmset`)

## Frontend 패턴

### lane4-web/admin/biz 공통
- HTTP: Axios 1.7~1.9, custom wrapper
  - `lane4-web/utils/Axios.ts` (GET/POST/PUT/PATCH/DELETE/FILE)
  - `lane4-admin/utils/AxiosV2.ts`, `lane4-biz/utils/AxiosV2.ts` (+ EXCEL, FILE_PATCH)
- Base URL: `process.env.NEXT_PUBLIC_API_URL` (단일 게이트웨이로 가정)
- 응답 envelope: `{ code: number|null, data: T, result: boolean }`
- 서비스 클래스: `apis/<domain>/<domain>.service.ts` — `static async login(params)` 형태
- 타입: `apis/<domain>/<domain>.type.ts` — **프로젝트별 중복 정의** (공유 패키지 없음)
- 상태: TanStack React Query v5 (`entities/<domain>/<domain>.queries.ts`, `*.mutation.ts`)

### API path 검색 패턴
서비스 메서드 안에 인라인 문자열로 들어감:
```typescript
return Axios.POST<LoginDto>({ url: 'auth/login', params }).then((res) => res.data);
```
또는 path-helper 상수:
```typescript
// utils/helper/UrlHelp.ts
{ AUTH_LOGIN_URL: 'auth/login', ... }
```

## Mobile 패턴

### lane4-app-driver / lane4-app-user
- React Native 0.73~0.81
- HTTP: Axios 0.21
- Base URL **두 개**:
  - `Config.API_URL` (legacy, 예: `https://api.lane4.ai/api/`) — 파일 업로드 등 일부
  - `Config.API_V2_URL` (new, 예: `https://driver-api.lane4.ai/`) — 대부분
- 환경: `.env.development`, `.env.production` (`APP_MODE` 분기)
- API path: 인라인 문자열 (`url: 'driver/begin-work'`)
- 또는 `src/constants/api.ts`의 상수 (`AUTH_LOGIN: 'auth/login'`)
- 상태: Redux + Redux-Saga + React Query v5

### CodePush
- BraveMobile + S3 + CloudFront
- 채널: development, production
- 앱 시작 시 `PATCH driver/app-version` with `{ appVerNo, codePushNo }`
- Release history: `https://cdn.lane4.ai/codePush/lane4-driver/{channel}/android/{appVersion}.json`
- **JS 변경은 앱스토어 리뷰 없이 즉시 반영** → 백엔드 배포 후 모바일 핫업데이트 동시 진행 가능

## 환경변수 컨벤션

공통:
- DB: `DB_MASTER_HOST`, `DB_SLAVE_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`
- Redis: `REDIS_HOST`, `REDIS_PORT`, `NEW_REDIS_HOST` (lane4-driver-api 듀얼)
- JWT: `JWT_ACCESS_TOKEN_SECRET`, `JWT_ACCESS_TOKEN_EXPIRATION_TIME`
- Firebase: `FIREBASE_DRIVER_DATABASE_URL`, `FIREBASE_USER_DATABASE_URL`
- Firebase paths: `FIREBASE_DRIVER_PATH=real/driving/`, `FIREBASE_USER_PATH=real/calling/`
- Kafka: `KAFKA_BROKERS`
- AWS: `AWS_S3_BUCKET`, `AWS_SQS_DRIVER_QUEUEURL`, `AWS_SQS_USER_QUEUEURL`

타입 안전성:
- lane4-allocation-api: typed `IRedis` interface (`CustomConfigModule`)
- lane4-admin-api: 직접 `process.env` (typing 없음) — 변경 시 정적 분석 어려움

## Hot Zones (광범위 영향)

| 위치 | 영향 |
|------|-----|
| `lane4-backend-library/src/commons/enum/service.type.ts` | 모든 백엔드 + 일부 FE 영향 |
| `lane4-driver-api/src/entities/*.ts` (스키마 변경) | 모든 백엔드 + MyBatis XML + Redis 캐시 키 |
| Kafka 토픽 이름 변경 | 양방향 grep 필요 (producer + consumer) |
| `lane4-backend-library`의 `DateTimeUtils.<method>` 시그니처 | 200+ 호출처 |
| Firebase RTDB 경로 (`.env`의 `FIREBASE_*_PATH`) | 양쪽 driver-api + admin-api 동기화 |
| `Config.API_URL` vs `Config.API_V2_URL` (모바일) | 파일 업로드 vs 일반 API 분기 |

## Edge Cases (도구가 놓치는 영역)

1. MyBatis XML raw SQL — `find-mybatis-refs.sh` 사용
2. 동적 enum 접근 (`Enum[varName]`) — find-callers는 enum 멤버명 grep, 하지만 동적 접근은 enum 이름으로 grep 권장
3. Kafka 토픽 하드코딩 — 토픽 정확한 문자열 매칭만 (`.` 포함)
4. lane4-driver-api 듀얼 Redis — `commons/redis/` + `commons/newRedis/` + `commons/cache/` 모두 점검
5. 프로젝트 간 entity 직접 import (가능성) — 엔티티 클래스명으로 추가 grep
6. CodePush 핫업데이트 vs 네이티브 빌드 경계 — JS 변경 vs 네이티브 모듈 구분
7. 모바일 dual base URL — `Config.API_URL` 사용처 별도 검색
8. 로컬 enum 중복 (lane4-admin-api `src/commons/enum/e.*.type.ts`) — 공유 enum 변경 시 동시 점검
