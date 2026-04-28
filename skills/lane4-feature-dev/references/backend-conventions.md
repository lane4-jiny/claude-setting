# Lane4 Backend Conventions (NestJS)

대상 프로젝트: `lane4-*-api` (11개), `lane4-scheduler`, `lane4-notification-server`, `lane4_backend`

## 디렉토리 레이아웃 (DDD)

```
src/
├── domains/
│   └── <domain>/
│       ├── presentation/
│       │   └── *.controller.ts          # 라우팅
│       ├── application/
│       │   ├── *.service.ts             # 유스케이스
│       │   └── dto/
│       │       ├── *.request.ts         # 요청 DTO
│       │       └── *.response.ts        # 응답 DTO
│       ├── domain/
│       │   ├── *.repository.ts          # 리포지토리 (인터페이스)
│       │   └── *.ts                     # 도메인 모델 (선택)
│       └── infrastructure/              # 외부 연동 (있으면)
├── entities/                            # 공유 TypeORM 엔티티 (lane4-driver-api에 다수)
├── commons/
│   ├── redis/, newRedis/, cache/        # ⚠️ lane4-driver-api는 3개 인스턴스
│   ├── kafka/
│   │   └── infrastructure/
│   │       ├── *.producer.ts
│   │       └── *.consumer.ts
│   ├── exceptions/
│   └── logging/
├── auth/                                # JwtAuthGuard, decorators
├── lib/
│   └── mapper/*.xml                     # ⚠️ MyBatis raw SQL (lane4-admin-api 위주)
└── main.ts
```

## 네이밍 컨벤션

| 항목 | 패턴 | 예시 |
|-----|------|------|
| 컨트롤러 파일 | `<verb>.<domain>.controller.ts` 또는 `<domain>.controller.ts` | `update.work.status.controller.ts`, `auth.controller.ts` |
| 서비스 파일 | `<verb>.<domain>.service.ts` 또는 `<domain>.service.ts` | `find.allocation.service.ts` |
| Request DTO | `*.request.ts` (또는 `*.dto.ts` 일부 잔존) | `find.driver.cars.request.ts` |
| Response DTO | `*.response.ts` | `find.driver.cars.response.ts` |
| Repository | `<domain>.repository.ts` | `driver.repository.ts` |
| 엔티티 클래스 | PascalCase, snake_case 테이블명 | `class Driver` → `@Entity('DRIVER')` |
| 컨트롤러 클래스 | PascalCase + `Controller` | `class FindAllocationController` |
| 메서드명 | camelCase, 동사 + 명사 | `findAllocation`, `updateWorkStatus` |

## 컨트롤러 패턴

### 일반 REST (lane4-driver-api, lane4-admin-api 등)
```typescript
@ApiTags('drivers')
@Controller('drivers')
export class FindDriverController {
  constructor(private readonly findDriverService: FindDriverService) {}

  @Get('/:id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '기사 상세 조회' })
  async findOne(@Param('id') id: number): Promise<FindDriverResponse> {
    return this.findDriverService.findOne(id);
  }
}
```

- 글로벌 prefix: `/api` (main.ts에서 `app.setGlobalPrefix('api')`)
- 권한: `@UseGuards(JwtAuthGuard)` 또는 `@Public()` (auth/decorators)
- 어드민 권한: `@RoleGuards()` 합성 데코레이터 (admin-api)
- Swagger: `@ApiTags`, `@ApiOperation`, `@ApiBearerAuth` - 스웨거는 정의용으로만 사용한다.

### Microservice (lane4-allocation-api 전용)
```typescript
@Controller()
export class CreateGolfAllocationController {
  @MessagePattern('create_allocation_golf')
  async handle(@Payload() dto: CreateGolfAllocationRequest, @Ctx() ctx: RedisContext) {
    return this.service.create(dto);
  }
}
```

## 서비스 패턴

```typescript
@Injectable()
export class FindAllocationService {
  constructor(
    @Inject('AllocationRepository') private readonly repo: AllocationRepository,
    private readonly customRedisService: CustomRedisService,
  ) {}

  async findOne(id: number): Promise<FindAllocationResponse> {
    const cached = await this.customRedisService.get(...);
    if (cached) return cached;
    const entity = await this.repo.findById(id);
    return FindAllocationResponse.from(entity);
  }
}
```

- `@Injectable()` 필수
- DI는 생성자 인자로 — 필드 주입 사용 금지
- Repository 인터페이스는 `domain/`, 구현은 `infrastructure/` 또는 application 레이어 안에 위치

## DTO 패턴

```typescript
// request
export class FindDriverRequest {
  @ApiProperty({ description: '검색어' })
  @IsString()
  @IsOptional()
  keyword?: string;

  @ApiProperty({ description: '페이지', default: 1 })
  @IsInt()
  @Min(1)
  @Type(() => Number)
  page: number = 1;
}

// response
export class FindDriverResponse {
  @ApiProperty()
  id: number;

  @ApiProperty()
  name: string;

  static from(entity: Driver): FindDriverResponse {
    const dto = new FindDriverResponse();
    dto.id = entity.id;
    dto.name = entity.name;
    return dto;
  }
}
```

- `class-validator` 데코레이터로 validation
- Response DTO는 `static from()` 팩토리 메서드 (엔티티 → DTO 변환)
- `@ApiProperty()` Swagger 문서화

## 응답 envelope

NestJS 글로벌 인터셉터가 자동으로 `{ code, data, result }` 래핑한다고 가정. 컨트롤러는 `data` 부분만 반환.

```typescript
@Get('/:id')
async findOne(): Promise<FindDriverResponse> {
  return this.service.findOne(id);  // 인터셉터가 { code, data: response, result: true }로 래핑
}
```

## 엔티티 패턴 (TypeORM)

```typescript
@Entity('DRIVER', { schema: 'LANE4' })
export class Driver {
  @PrimaryGeneratedColumn({ name: 'DRV_ID' })
  id: number;

  @Column({ name: 'NAME', length: 50 })
  name: string;

  @Column({ name: 'STATUS', type: 'enum', enum: DriverStatus })
  status: DriverStatus;

  @CreateDateColumn({ name: 'REG_DT' })
  regDt: Date;
}
```

- 테이블명: 대문자 snake_case (`DRIVER`, `DRIVER_SCHEDULE`)
- 컬럼명: 대문자 snake_case (`DRV_ID`, `WORK_DT_S`)
- TypeScript 필드명: camelCase
- `synchronize: false` (수동 마이그레이션)

## Repository 패턴

```typescript
// domain/driver.repository.ts (인터페이스)
export interface DriverRepository {
  findById(id: number): Promise<Driver | null>;
  findActive(filter: ActiveFilter): Promise<Driver[]>;
}

// infrastructure 또는 application/driver.repository.impl.ts
@Injectable()
export class DriverRepositoryImpl implements DriverRepository {
  constructor(@InjectRepository(Driver) private readonly repo: Repository<Driver>) {}

  async findById(id: number): Promise<Driver | null> {
    return this.repo.findOne({ where: { id } });
  }
}
```

- 복잡 쿼리는 `createQueryBuilder` (raw SQL 자제)
- 다중 테이블 join이 복잡하면 MyBatis XML mapper 사용 (lane4-admin-api 패턴)

## 모듈 패턴

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([Driver])],
  controllers: [FindDriverController, UpdateDriverController],
  providers: [
    FindDriverService,
    UpdateDriverService,
    { provide: 'DriverRepository', useClass: DriverRepositoryImpl },
  ],
  exports: [FindDriverService],
})
export class DriverModule {}
```

## Kafka Producer 패턴

```typescript
@Injectable()
export class BeginDrivingProducer {
  constructor(@Inject('KAFKA_CLIENT') private readonly kafka: ClientKafka) {}

  public produce(message: BeginDrivingMessage) {
    this.kafka.emit('local.driver.begin-driving', JSON.stringify(message));
  }
}
```

- 토픽 컨벤션: `local.<domain>.<event>` (소문자 + 하이픈)
- 메시지는 `JSON.stringify`
- 베이스: `KafkaBaseProducer` 사용 가능

## Kafka Consumer 패턴

```typescript
@Injectable()
export class BeginDrivingConsumer implements OnModuleInit {
  async onModuleInit() {
    await this.consumer.connect();
    await this.consumer.subscribe({ topic: 'local.driver.begin-driving', fromBeginning: false });
    await this.consumer.run({
      eachMessage: async ({ message }) => {
        const data = JSON.parse(message.value.toString());
        await this.handle(data);
      },
    });
  }
}
```

## Redis 사용 가이드 (lane4-driver-api 듀얼/트리플)

| 인스턴스 | 위치 | 용도 |
|--------|------|------|
| `commons/redis/` | `@InjectRedis()` (ioredis) | legacy, 기사 위치/이력 |
| `commons/newRedis/` | new instance | 신규 데이터 (전환 중) |
| `commons/cache/` | `@Inject(CACHE_MANAGER)` (cache-manager) | 일반 캐시 추상화 |

**신규 캐싱 추가 시 사용자에게 어느 인스턴스인지 질문** (Pre-flight Step 3에서).

다른 백엔드 (lane4-admin-api 등): 단일 인스턴스 또는 cache-manager만 사용.

## Redis 키 패턴

- 슬롯 해시 prefix: `{domain}:*` (cluster slot 고정)
  - 예: `{driver}:location`, `{driver}:history:%s`
- 빌더: `format('...:%s', id)` 사용
- 도메인 prefix 없는 키도 가능: `operational-analytics:%s:revenue`

## 환경변수

- `dotenv`로 `main.ts`에서 로드
- 직접 `process.env.X` 또는 `ConfigService.get()` 사용
- 일부 프로젝트(lane4-allocation-api)만 typed `IRedis` 인터페이스 사용

## 공유 라이브러리 import

```typescript
import { DateTimeUtils, ProjectType, ServiceType, TaskType } from '@lane4company/lane4-backend-library';
```

- top-level barrel만 사용. deep import 금지.
- 사용 가능한 export 10개: `TMapUtils`, `DateTimeUtils`, `NotificationUtils`, `FlightAwareUtils`, `OpenAIUtils`, `FirebaseModule`, `TaskType`, `ProjectType`, `ServiceType`, `SlackChannelType`

## 인증/권한 데코레이터

```typescript
@UseGuards(JwtAuthGuard)              // 일반 사용자 인증
@UseGuards(LocalAuthGuard)             // 로컬 (login flow)
@UseGuards(OptionalJwtAuthGuard)       // optional (게스트 허용)
@Public()                              // 인증 스킵
@RoleGuards('ADMIN')                   // 어드민 권한 (admin-api 합성)
```

## 코드 스타일

- TypeScript strict mode
- 식별자: 영문 camelCase / PascalCase
- 주석: 한국어 OK (도메인 용어는 한국어 자연스러움)
- Import 정렬: 외부 → 내부 → 로컬 (자동 import organize 권장)
- 한 파일에 한 클래스 원칙
