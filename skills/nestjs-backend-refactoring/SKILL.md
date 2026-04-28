---
name: nestjs-backend-refactoring
description: >
  NestJS 백엔드 코드 리팩토링 스킬. 코드리뷰와 리팩토링 수행을 모두 지원한다.
  사용자가 "리팩토링", "refactoring", "코드 정리", "패턴 통일", "코드 개선", "구조 개선",
  "코드리뷰", "code review" 등을 요청하거나,
  NestJS 백엔드 코드의 품질/구조에 대한 개선이 필요한 맥락에서 반드시 이 스킬을 사용한다.
  컨트롤러, 서비스, 모듈, 가드, 인터셉터, 파이프, DTO, 엔티티 등 NestJS 전반의 리팩토링을 다룬다.
---

# NestJS Backend Refactoring

## 목적

NestJS 백엔드 프로젝트의 코드를 분석하여 일관된 패턴으로 리팩토링한다.
여러 프로젝트에 걸쳐 동일한 코딩 컨벤션과 아키텍처 패턴을 적용하여 코드 품질과 유지보수성을 높인다.

## 동작 모드

### 모드 1: 코드리뷰
대상 코드를 분석하여 리팩토링 포인트를 식별하고 **리뷰 리포트**를 제공한다. 코드를 직접 수정하지 않는다.

### 모드 2: 리팩토링 수행
리팩토링 규칙에 따라 실제 코드를 수정한다. 사용자가 명시적으로 리팩토링을 요청했을 때 수행한다.

사용자가 "리뷰", "확인", "분석" 등을 요청하면 → 모드 1
사용자가 "리팩토링해줘", "수정", "개선해줘" 등을 요청하면 → 모드 2

---

## 워크플로우

### 공통: 대상 식별 및 분석

1. **대상 식별** - 사용자가 지정한 파일/모듈/도메인 확인. 미지정 시 현재 작업 컨텍스트에서 파악.
2. **현재 코드 분석** - 대상 코드를 읽고 아래 항목을 파악:
   - 파일 구조 및 네이밍
   - 의존성 주입 패턴
   - 에러 처리 방식
   - DTO/Validation 패턴
   - 데이터베이스 접근 패턴
   - 비즈니스 로직 분리 수준

### 모드 1 - 코드리뷰 워크플로우

```
[대상 식별] → [코드 분석] → [규칙 대비 평가] → [리뷰 리포트 출력]
```

리뷰 리포트 형식:
```markdown
## 코드리뷰 결과: {대상}

### 위반 사항
| # | 규칙 | 파일:라인 | 현재 코드 요약 | 권장 수정 |
|---|------|----------|--------------|----------|

### 양호한 부분
- ...

### 리팩토링 우선순위
1. (높음) ...
2. (중간) ...
3. (낮음) ...
```

### 모드 2 - 리팩토링 워크플로우

```
[대상 식별] → [코드 분석] → [리팩토링 계획 제시] → [사용자 확인] → [적용] → [검증]
```

적용 원칙:
- 한 번에 하나의 규칙/패턴만 적용
- 기능 변경 없이 구조만 개선 (행동 보존 리팩토링)
- 변경 범위를 최소화
- 적용 후 빌드 확인 (`npm run build` 또는 `tsc --noEmit`)

---

## 리팩토링 규칙

### R1: 컨트롤러 책임 분리

컨트롤러는 HTTP 요청/응답 처리만 담당한다. 비즈니스 로직뿐 아니라 **요청 타입에 따른 디스패치 분기**도 서비스 레이어로 위임한다. 컨트롤러에 `if/else`가 생기면 대부분의 경우 서비스의 진입점(dispatcher) 메서드를 만들어 흡수할 수 있다.

**안티패턴 1 (비즈니스 로직 노출):**
```typescript
@Post()
async create(@Body() dto: CreateDto) {
  const validated = await this.validate(dto);
  const result = await this.repository.save(validated);
  await this.notificationService.send(result);
  return result;
}
```

**리팩토링:**
```typescript
@Post()
async create(@Body() dto: CreateDto) {
  return this.service.create(dto);
}
```

**안티패턴 2 (컨트롤러에 타입 분기):**
```typescript
@Post('/allocations/oneway/simple')
async createOnewaySimple(@Body() request: CreateSimpleAllocationRequest) {
  if (request.allocationType === SimpleAllocationType.CREATE) {
    return this.lockingMonitoringAllocationService.createOnewayAllocation(employee, request);
  }
  if (request.allocationType === SimpleAllocationType.ALLOCATE) {
    return this.monitoringAllocationService.allocateOnewayAllocation(employee, request);
  }
  return this.monitoringAllocationService.updateOnewayAllocation(employee, request.allocationId, request);
}
```

**리팩토링 (서비스 디스패처로 흡수):**
```typescript
// service
public async handleOnewaySimpleAllocation(employee: AuthenticatedUser, request: CreateSimpleAllocationRequest) {
  if (request.allocationType === SimpleAllocationType.CREATE) return this.createOnewayAllocation(employee, request);
  if (request.allocationType === SimpleAllocationType.ALLOCATE) return this.monitoringAllocationService.allocateOnewayAllocation(employee, request);
  return this.monitoringAllocationService.updateOnewayAllocation(employee, request.allocationId, request as UpdateSimpleAllocationRequest);
}

// controller
@Post('/allocations/oneway/simple')
async createOnewaySimple(@Body() request: CreateSimpleAllocationRequest) {
  return this.lockingMonitoringAllocationService.handleOnewaySimpleAllocation(employee, request);
}
```

디스패처를 서비스로 옮기면 컨트롤러의 의존성 주입 목록도 줄어든다(여러 서비스를 직접 주입하지 않고 하나만 주입).

### R2: 서비스 레이어 구조

서비스는 하나의 도메인에 집중한다. 서비스 간 의존이 필요하면 주입하되, 순환 의존을 피한다.

### R3: DTO 패턴

- 요청/응답 DTO를 분리한다
- class-validator 데코레이터로 유효성 검증
- class-transformer의 @Exclude(), @Expose()로 응답 직렬화

### R4: 에러 처리

- 비즈니스 예외는 커스텀 Exception으로 정의
- HTTP 상태 코드는 컨트롤러 레벨에서만 결정
- 서비스에서는 도메인 예외를 throw

### R5: 데이터베이스 접근

- Repository 패턴 또는 TypeORM/Sequelize 패턴 일관성 유지
- Raw 쿼리 사용 시 SQL Injection 방지
- 트랜잭션 처리 패턴 통일

### R6: 모듈 구조

- Feature 모듈 단위로 분리
- Shared 모듈은 공통 유틸리티만 포함
- Dynamic 모듈 패턴 활용

### R7: 엔티티 주석 중복 제거

`@Column`의 `comment` 속성에 이미 설명이 있으면, 동일한 내용의 JSDoc 주석(`/** ... */`)을 달지 않는다.
`comment` 속성이 DB 스키마에 반영되는 단일 출처(single source of truth)이므로, JSDoc으로 같은 내용을 반복하면 유지보수 부담만 늘어난다.

**안티패턴:**
```typescript
/** 배차 ID */
@Column('int', { name: 'ALLOCATION_ID', comment: '배차 ID' })
allocationId: number;
```

**리팩토링:**
```typescript
@Column('int', { name: 'ALLOCATION_ID', comment: '배차 ID' })
allocationId: number;
```

단, 클래스 레벨의 JSDoc(`/** 실시간 예약 알림 엔티티 */` 등)은 유지한다. 엔티티 전체의 역할을 설명하는 주석은 `comment`와 다른 목적이기 때문이다.

### R8: 인라인 객체 리터럴을 DTO static 팩토리로 추출

게이트웨이, 서비스 등에서 emit이나 메서드 호출 시 인라인 객체 리터럴을 직접 작성하지 않는다.
동일 구조의 객체가 여러 곳에서 반복되면 DTO 클래스의 `static` 팩토리 메서드(`of~`)로 추출한다.
이렇게 하면 데이터 구조가 한 곳에서 관리되고, 호출부가 간결해진다.

**안티패턴:**
```typescript
this.server.to(room).emit('reservation-notification', {
  action: 'CREATE',
  allocationId: message.allocationId,
  companyCode: message.companyCode,
  title: message.title,
  contents: message.contents,
});
```

**리팩토링:**
```typescript
// DTO 클래스
export class NotifyReservationNotificationRequest {
  action: ReservationNotificationAction;
  allocationId: number;
  companyCode?: string;
  // ...

  public static ofCreated(message: ReservationNotificationMessage) {
    const request = new NotifyReservationNotificationRequest();
    request.action = ReservationNotificationAction.CREATE;
    request.allocationId = message.allocationId;
    request.companyCode = message.companyCode;
    // ...
    return request;
  }
}

// 호출부
this.server.to(room).emit('reservation-notification', NotifyReservationNotificationRequest.ofCreated(message));
```

팩토리 메서드 네이밍: `of` + 동작/상태 (예: `ofCreated`, `ofRemoved`, `ofCanceled`)

### R9: 하드코딩 문자열을 enum 상수로 대체

액션 타입, 상태값 등 고정된 문자열을 코드에 직접 쓰지 않는다. enum으로 정의하고 상수를 참조한다.
타입 안전성을 확보하고, 오타로 인한 런타임 버그를 방지한다.

**안티패턴:**
```typescript
request.action = 'CREATE';
// 또는
if (status === 'COMPLETED') { ... }
```

**리팩토링:**
```typescript
request.action = ReservationNotificationAction.CREATE;
// 또는
if (status === AllocationStatus.COMPLETED) { ... }
```

enum이 이미 프로젝트에 존재하면 재사용하고, 없으면 적절한 위치(해당 도메인의 domain 디렉토리)에 생성한다.

### R10: 중첩 분기/반복 금지 (가독성)

`if` 안의 `if`, `for` 안의 `for`, `if` 안의 `for` 등 중첩이 2단계 이상 들어가면 가독성이 급격히 떨어진다.
중첩을 줄이는 방법:

- **Early return / Guard clause**: 조건 불만족 시 먼저 빠져나간다
- **삼항 연산자**: 단순 분기는 삼항으로 한 줄로 표현한다
- **메서드 추출**: 중첩 내부 로직을 의미 있는 이름의 메서드로 분리한다
- **Optional chaining (`?.`)**: null 체크 분기를 `?.`로 대체한다
- **함수형 체이닝**: `for-for` 이중 반복은 `filter().flatMap()` 등으로 대체한다

**안티패턴 1 (if-if 중첩):**
```typescript
if (driver) {
  allocation.Driver = driver;
  allocation.employeeId = employee.id;
  if (allocation.realtimeReservationNotification) {
    await queryRunner.manager.save(allocation.realtimeReservationNotification.allocate());
  }
}
```

**리팩토링:**
```typescript
if (driver) {
  allocation.allocate(driver, employee.id);
}

if (allocation.isRealtimeReservation()) {
  await queryRunner.manager.save(allocation.realtimeReservationNotification);
}
```

**안티패턴 2 (for-for 중첩):**
```typescript
const routeCoordinates = [];
for (const route of features) {
  for (let j = 0; j < route.geometry.coordinates.length; j++) {
    if (route.geometry.coordinates.length > 3) {
      routeCoordinates.push(route.geometry.coordinates[j]);
    }
  }
}
```

**리팩토링:**
```typescript
const routeCoordinates = features
  .filter((route) => route.geometry.coordinates.length > 3)
  .flatMap((route) => route.geometry.coordinates as number[][]);
```

### R11: 서비스 로직을 엔티티 도메인 메서드로 이동 (Rich Domain Model)

엔티티의 상태를 변경하는 로직이 서비스에 흩어져 있으면, 엔티티 자체에 도메인 메서드로 캡슐화한다.
상태 변경의 책임이 엔티티에 있으면 서비스는 흐름 제어만 담당하게 되어 코드가 명확해진다.
연관된 하위 엔티티의 상태 변경도 상위 엔티티 메서드 안에서 함께 처리하여 일관성을 보장한다.

**안티패턴 (서비스에서 상태 직접 조작):**
```typescript
// service
allocation.Driver = driver;
allocation.employeeId = employee.id;
allocation.realtimeReservationNotification?.allocate();
```

**리팩토링 (엔티티 도메인 메서드):**
```typescript
// entity
public allocate(driver: Driver, employeeId: number) {
  this.Driver = driver;
  this.employeeId = employeeId;
  this.realtimeReservationNotification?.allocate();
  return this;
}

public deallocate() {
  this.status = AllocStatus.NORMAL;
  this.Car = null;
  this.Driver = null;
  this.employeeId = null;
  this.realtimeReservationNotification?.deallocate();
  return this;
}

// service
allocation.allocate(driver, employee.id);
```

도메인 메서드는 `return this`로 체이닝을 지원하고, 메서드명은 도메인 용어(`allocate`, `deallocate`, `cancel` 등)를 사용한다.

**추가 안티패턴 (서비스 private 헬퍼가 엔티티 필드만 set):**
```typescript
// service
private setDeparture(callRequest: CallReq, departure: Place): void {
  callRequest.departureShort = departure.baseAddress;
  callRequest.departureLong = departure.fullAddress;
  callRequest.deptLati = departure.coordinate.latitude;
  callRequest.deptLong = departure.coordinate.longitude;
  // ...
}

// 호출부
this.setDeparture(callRequest, request.departure);
```

서비스의 private 헬퍼가 **엔티티 필드 할당만** 하고 있다면, 그 책임은 엔티티에 있어야 한다. 서비스에 둘 필요가 없다.

**리팩토링:**
```typescript
// entity
public setDeparture(departure: Place): this {
  this.departureShort = departure.baseAddress;
  this.departureLong = departure.fullAddress;
  this.deptLati = departure.coordinate.latitude;
  this.deptLong = departure.coordinate.longitude;
  return this;
}

// service
callRequest.setDeparture(request.departure);
```

### R12: 미사용 코드 및 모호한 시그니처 제거

리팩토링 과정에서 호출처가 사라진 메서드, 파라미터 타입이 의도와 맞지 않는 메서드(예: `number`를 받아 boolean으로만 사용)는 즉시 삭제한다. 남겨두면 혼란만 가중된다.

**안티패턴:**
```typescript
// driverId를 number로 받지만 실제로는 truthy/falsy만 판단
public updateAllocatedAtByStatus(driverId: number) {
  if (!driverId) {
    return this.deallocate();
  }
  return this.allocate();
}
```

→ 호출처에서 이미 `driver` 유무로 분기하고 있다면, 이 메서드는 삭제하고 `allocate()`/`deallocate()`를 직접 호출한다.

### R13: 중복 분기 통합

동일 조건에 대한 분기가 여러 곳에 흩어져 있으면 하나로 통합한다. 특히 `if (condition) { A }` ... `if (!condition) { B }` 패턴은 `if-else`로 합친다.

**안티패턴:**
```typescript
if (driver) {
  allocation.Driver = driver;
  allocation.employeeId = employee.id;
}

// ... 여러 줄 뒤 ...

if (!driver) {
  allocation.employeeId = null;
}
```

**리팩토링:**
```typescript
if (driver) {
  allocation.allocate(driver, employee.id);
} else {
  allocation.employeeId = null;
}
```

### R14: DTO에서 외부 API/비동기 호출 금지

DTO의 `static of()` 팩토리 메서드는 순수한 데이터 변환만 담당한다. 외부 API 호출(TMap, 결제 등)이나 비동기 작업을 DTO 안에서 수행하면 테스트가 어렵고 책임이 섞인다. 외부 데이터는 서비스에서 조회한 뒤 파라미터로 주입한다.

**안티패턴:**
```typescript
// DTO 안에서 외부 API 호출
export class FindGuestShareResponse {
  public static async of(allocation: Allocation) {
    // ...
    response.coordinates = await this.getTmapCoordinates(allocation);
    return response;
  }

  private static async getTmapCoordinates(allocation: Allocation) {
    return await TMapUtils.getRoutesPrediction(...);
  }
}
```

**리팩토링:**
```typescript
// 서비스에서 외부 데이터 조회 후 DTO에 전달
// service
const coordinates = await PathUtils.getTmapCoordinates(allocation);
return FindGuestShareResponse.of(allocation, coordinates);

// DTO - 동기 메서드, 순수 변환만
export class FindGuestShareResponse {
  public static of(allocation: Allocation, coordinates: number[][]) {
    // ...
    response.coordinates = coordinates;
    return response;
  }
}
```

### R15: 엔티티 관계 체이닝을 도메인 getter 메서드로 캡슐화

`allocation.CallReq?.passengerNm ?? allocation.CallReq?.SvcUser?.userNm` 같은 관계 체이닝이 여러 DTO/서비스에서 반복되면, 엔티티에 getter 도메인 메서드로 캡슐화한다. 접근 경로가 변경되어도 엔티티 메서드 하나만 수정하면 된다.

**안티패턴:**
```typescript
// DTO A
const name = allocation.CallReq?.passengerNm ?? allocation.CallReq?.SvcUser?.userNm;
const contact = allocation.CallReq?.passengerTel ?? allocation.CallReq?.SvcUser?.userMobile;

// DTO B (동일 로직 반복)
const passengerName = allocation.CallReq?.passengerNm ?? allocation.CallReq?.SvcUser?.userNm;
```

**리팩토링:**
```typescript
// entity
public getPassengerName() {
  return this.CallReq?.passengerNm ?? this.CallReq?.SvcUser?.userNm;
}

public getPassengerContact() {
  return this.CallReq?.passengerTel ?? this.CallReq?.SvcUser?.userMobile ?? this.CallReq?.SvcUser?.userEmail;
}

// DTO
response.customer = {
  name: allocation.getPassengerName(),
  contact: allocation.getPassengerContact(),
};
```

### R16: DTO 중복 private 메서드를 공통 Utils 클래스로 추출

여러 DTO에서 동일한 변환 로직(서비스타입 한국어 변환, 좌표 계산 등)이 private 메서드로 반복되면 `commons/utils/` 하위에 static 메서드를 가진 Utils 클래스로 추출한다. DTO는 변환 결과만 사용한다.

**안티패턴:**
```typescript
// FindGuestShareResponse
private static getServiceTypeKorean(callType: string, serviceType: ServiceType) {
  if (callType === '실시간') return '즉시호출';
  // ...
}

// FindAllocationHistoryDetailResponse (동일 로직 반복)
private static getServiceTypeKorean(callType: string, serviceType: ServiceType) {
  if (callType === '실시간') return '즉시호출';
  // ...
}
```

**리팩토링:**
```typescript
// commons/utils/service.type.utils.ts
export class ServiceTypeUtils {
  public static toKorean(callType: string, serviceType: ServiceType): string {
    if (callType === '실시간') return '즉시호출';
    if (serviceType === ServiceType.RENT) return '시간대절';
    // ...
  }
}

// DTO에서 호출
response.serviceType = ServiceTypeUtils.toKorean(callType, serviceType);
```

### R17: Repository 직접 주입 → 도메인 모듈/서비스 분리

서비스가 타 도메인의 Repository를 직접 주입(`@InjectRepository`)하지 않는다. 해당 도메인의 모듈과 서비스를 만들어 그 서비스를 주입한다. 조회+예외 처리 같은 반복 패턴은 도메인 서비스에 `findByXxxOrThrow` 메서드로 캡슐화한다.

**안티패턴:**
```typescript
// guest.service.ts - 타 도메인 Repository 직접 주입
@Injectable()
export class GuestService {
  constructor(
    @InjectRepository(CallReq)
    private readonly callReqRepository: Repository<CallReq>,
  ) {}

  async findGuestShare(extToken: string) {
    const callReq = await this.callReqRepository.findOne({ where: { extToken } });
    if (!callReq) {
      throw new BadRequestException('유효하지 않은 토큰입니다.');
    }
    // ...
  }
}

// guest.module.ts
TypeOrmModule.forFeature([CallReq])  // 타 도메인 엔티티 직접 등록
```

**리팩토링:**
```typescript
// call_request/call_request.service.ts
@Injectable()
export class CallRequestService {
  constructor(
    @InjectRepository(CallReq)
    private readonly callReqRepository: Repository<CallReq>,
  ) {}

  public async findByExtTokenOrThrow(extToken: string): Promise<CallReq> {
    const callReq = await this.callReqRepository.findOne({ where: { extToken } });
    if (!callReq) {
      throw new BadRequestException('유효하지 않은 토큰입니다.');
    }
    return callReq;
  }
}

// call_request/call_request.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([CallReq])],
  providers: [CallRequestService],
  exports: [CallRequestService],
})
export class CallRequestModule {}

// guest.service.ts - 도메인 서비스 주입
@Injectable()
export class GuestService {
  constructor(
    private readonly callRequestService: CallRequestService,
  ) {}

  async findGuestShare(extToken: string) {
    const callReq = await this.callRequestService.findByExtTokenOrThrow(extToken);
    // ...
  }
}

// guest.module.ts
imports: [CallRequestModule]  // 도메인 모듈 import
```

### R18: 내부 구현이 동일한 다중 메서드 → 단일 메서드 + 파라미터화

이름과 내부 하드코딩 값만 다를 뿐 구현이 같은 여러 메서드/팩토리는 하나로 통합하고, 차이 부분을 파라미터로 받는다.
action/status 필드가 이미 DTO에 존재한다면 메서드 분기 자체가 중복이다.

이는 R8(인라인 객체 → DTO 팩토리 추출)의 연장이지만 방향이 반대다. R8은 **분리**, R18은 **통합**이다. 팩토리가 3개 이상으로 불어나고 내부가 서로 복붙이면 통합 신호로 본다.

**안티패턴 1 (서비스 메서드 이름만 다른 3개):**
```typescript
public create(message: ReservationNotificationMessage) {
  this.reservationNotificationProducer.produce(message);
}
public remove(message: ReservationNotificationMessage) {
  this.reservationNotificationProducer.produce(message);
}
public cancel(message: ReservationNotificationMessage) {
  this.reservationNotificationProducer.produce(message);
}
```

**리팩토링:**
```typescript
public send(message: ReservationNotificationMessage) {
  this.reservationNotificationProducer.produce(message);
}
// action 구분은 이미 message.action 필드로 전달됨
```

**안티패턴 2 (DTO 팩토리 3개가 action만 다름):**
```typescript
public static createMessage(allocationId, companyCode, allocatedCompanyCode, serviceType, ...) {
  message.action = ReservationNotificationAction.CREATE;
  // ...
}
public static removeMessage(allocationId, companyCode, allocatedCompanyCode) {
  message.action = ReservationNotificationAction.REMOVE;
  // ...
}
public static cancelMessage(allocationId, companyCode, allocatedCompanyCode) {
  message.action = ReservationNotificationAction.CANCEL;
  // ...
}
```

**리팩토링:**
```typescript
public static of(
  action: ReservationNotificationAction,
  allocationId: number,
  companyCode: string,
  allocatedCompanyCode: string,
  serviceType: ServiceType,
  title?: string,
  contents?: string,
): ReservationNotificationMessage {
  const message = new ReservationNotificationMessage();
  message.action = action;
  // ...
  return message;
}
```

통합 시 기존 바리에이션에서 **누락되던 필드**가 드러나면 필수 파라미터로 승격한다. (예: REMOVE/CANCEL에서 빠져 있던 `serviceType`을 필수화)

### R19: 엔티티 도메인 메서드에 상태 전이 가드

엔티티의 상태를 바꾸는 도메인 메서드는 **허용되지 않는 상태 전이**를 스스로 막아야 한다. 이미 배차 완료된 예약을 다시 배차하거나, 이미 취소된 예약을 또 취소하는 등 invalid transition을 서비스 레이어 검증에만 맡기면 호출 경로가 늘어날수록 빠뜨리기 쉽다. 엔티티가 자기 invariant를 지키게 한다.

**안티패턴:**
```typescript
public allocate() {
  this.allocatedAt = new Date();
  return this;
}

public cancel() {
  this.canceledAt = new Date();
  return this;
}
```

**리팩토링:**
```typescript
public allocate() {
  if (this.isAllocated()) {
    throw new BadRequestException('이미 배차 완료된 실시간 예약입니다.');
  }
  if (this.isCancelRequested() || this.isCanceled()) {
    throw new BadRequestException('취소 또는 취소 요청된 실시간 예약은 배차할 수 없습니다.');
  }
  this.allocatedAt = new Date();
  return this;
}

public cancel() {
  if (this.isCanceled()) {
    throw new BadRequestException('이미 취소된 실시간 예약입니다.');
  }
  this.canceledAt = new Date();
  return this;
}

public isAllocated() { return !!this.allocatedAt; }
private isCanceled() { return !!this.canceledAt; }
private isCancelRequested() { return !!this.cancelRequestedAt; }
```

상태 조회용 boolean 헬퍼(`isX`)를 함께 두면 가드 조건과 서비스 쪽 분기 모두에서 재사용할 수 있다. 외부에서 참조할 필요가 없으면 `private`.

### R20: 엔티티 메서드 네이밍 컨벤션

엔티티/도메인 객체 메서드는 규칙을 통일한다.

| 목적 | 형태 | 예 |
|------|------|----|
| 정적 팩토리 | `of`, `from` | `RealtimeReservationNotification.of(...)` |
| 상태 변경 | 동사형 | `allocate()`, `cancel()`, `requestCancel()` |
| 상태 조회 | `isX`, `hasX` | `isAllocated()`, `isCanceled()` |
| 컬렉션 getter | `getX` | `getPassengerName()` |

**메서드명과 컬럼명을 일치**시키면 어떤 상태가 바뀌는지 바로 보인다. 예: 컬럼이 `cancelRequestedAt`이면 메서드는 `notifyCancel`이 아니라 `requestCancel`.

정적 팩토리 이름은 `create`보다 `of`를 선호한다. `create`는 DB에 생성하는 서비스 메서드와 혼동되고, `of`는 "이 값으로부터 만든다"라는 정적 팩토리의 의미를 바로 드러낸다.

### R21: 리포지토리 내부 중첩 함수 → private 메서드

리포지토리 메서드 안에서 `function`으로 선언한 중첩 함수로 쿼리 일부를 조립하지 않는다. `SelectQueryBuilder<T>`를 인자로 받는 **private 메서드**로 추출하여 쿼리 조립 책임을 명시적으로 분리한다.

**안티패턴:**
```typescript
public async findByAllocatedCompanyCode(allocatedCompanyCode, request) {
  const query = this.createQueryBuilder('notification')
    .innerJoinAndSelect('notification.allocation', 'allocation')
    .where('notification.allocatedCompanyCode = :allocatedCompanyCode', { allocatedCompanyCode });

  addDateCondition();
  addKeywordCondition();

  return await query.orderBy(...).getManyAndCount();

  function addDateCondition() {
    if (request.startDate) query.andWhere(...);
    if (request.endDate) query.andWhere(...);
  }
  function addKeywordCondition() {
    if (request.keyword) query.andWhere(...);
  }
}
```

**리팩토링:**
```typescript
public async findByAllocatedCompanyCode(allocatedCompanyCode, request) {
  const query = this.createQueryBuilder('notification')
    .innerJoinAndSelect('notification.allocation', 'allocation')
    .where('notification.allocatedCompanyCode = :allocatedCompanyCode', { allocatedCompanyCode });

  this.addDateCondition(query, request);
  this.addKeywordCondition(query, request);

  return await query.orderBy('notification.requestAt', 'DESC').getManyAndCount();
}

private addDateCondition(query: SelectQueryBuilder<Entity>, request: FindRequest): void {
  if (request.startDate) query.andWhere('notification.requestAt >= :startDate', { startDate: `${request.startDate} 00:00:00` });
  if (request.endDate) query.andWhere('notification.requestAt <= :endDate', { endDate: `${request.endDate} 23:59:59` });
}
```

부수적으로 QueryBuilder에 사용하는 컬럼명은 **camelCase(엔티티 프로퍼티명)** 로 통일한다. `UPPER_SNAKE`(DB 컬럼명) 사용 금지. 예: `'notification.allocatedAt IS NULL'` (`ALLOCATED_AT` X).

### R22: QueryBuilder OR 조건 → Brackets + 컬럼 배열

Raw SQL 문자열로 `'(col1 LIKE :kw OR col2 LIKE :kw OR ...)'` 를 쓰지 않는다. `Brackets`로 묶고 검색 컬럼을 배열로 분리하면 컬럼 추가/삭제 시 수정이 한 줄이다.

**안티패턴:**
```typescript
if (request.keyword) {
  query.andWhere(
    '(callRequest.departureShort LIKE :keyword OR callRequest.destinationShort LIKE :keyword OR callRequest.passengerNm LIKE :keyword OR callRequest.passengerTel LIKE :keyword)',
    { keyword: `%${request.keyword}%` },
  );
}
```

**리팩토링:**
```typescript
private addKeywordCondition(query: SelectQueryBuilder<Entity>, request: FindRequest): void {
  if (!request.keyword) return;

  const searchColumns = [
    'callRequest.departureShort',
    'callRequest.destinationShort',
    'callRequest.passengerNm',
    'callRequest.passengerTel',
  ];

  query.andWhere(
    new Brackets((qb) => {
      searchColumns.forEach((column) =>
        qb.orWhere(`${column} LIKE :keyword`, { keyword: `%${request.keyword}%` }),
      );
    }),
  );
}
```

### R23: `@CurrentUser` 파라미터명은 도메인에 맞게 통일

프로젝트별로 인증된 주체가 다르다. 변수명을 도메인에 맞춰 통일하면 서비스 메서드 시그니처가 의미 있게 읽힌다.

| 프로젝트 | 변수명 |
|---------|-------|
| lane4-partner-api, lane4-admin-api | `employee` |
| lane4-app-api | `user` |
| lane4-driver-api | `driver` |
| lane4-guest-api | `guest` |

**안티패턴 (partner-api에서):**
```typescript
public async findAll(@CurrentUser() user: AuthenticatedUser, @Query() request) {
  return this.service.findAll(user.compCd, request);
}
```

**리팩토링:**
```typescript
public async findAll(@CurrentUser() employee: AuthenticatedUser, @Query() request) {
  return this.service.findAll(employee.compCd, request);
}
```

기존 컨트롤러 다수가 `employee`를 쓰면 그 컨벤션을 따른다. 한 프로젝트 안에서 섞이면 리뷰 때마다 혼선이 생긴다.

### R24: 모듈 imports 배열 중복 제거

`@Module({ imports: [...] })` 배열은 파일이 커지면 같은 모듈이 **두 번 등록되는 사고**가 잦다. 기능상 문제는 없지만 노이즈이고, 리팩토링 시 알파벳/그룹 정렬을 하면서 즉시 걸러낸다.

**안티패턴:**
```typescript
@Module({
  imports: [
    // ...
    EmployeeModule,
    RecommendationModule,
    forwardRef(() => NotificationModule),
    RealtimeReservationNotificationModule,
    EmployeeModule,  // <-- 중복
  ],
})
```

모듈 추가/정리 작업이 있을 때 항상 체크한다. IDE 정렬 기능으로 알파벳 순 정렬 후 연속된 동일 모듈을 찾는 것이 가장 빠르다.

### R25: DTO 날짜 필드는 `@IsDateString`

쿼리 파라미터로 들어오는 날짜 문자열은 `@IsString`이 아니라 `@IsDateString`으로 검증한다. ISO 8601 형식을 강제하여 잘못된 날짜 입력(예: `"asdf"`, `"2025-99-99"`)이 쿼리까지 도달하는 것을 막는다.

**안티패턴:**
```typescript
@IsOptional()
@IsString()
startDate?: string;
```

**리팩토링:**
```typescript
@IsOptional()
@IsDateString()
startDate?: string;
```

### R26: 서비스 내부 마법값 → `private static readonly` + 용도 주석

서비스 메서드 여러 곳에서 참조되는 동일한 상수가 `Constants.X` 형태로 직접 사용되고 있다면, 해당 서비스 클래스 상단에 `private static readonly` 상수로 추출하고 **왜 이 값을 쓰는지** 주석으로 남긴다. 외부 `Constants`는 의미가 탈색된 값이지만, 서비스 내 상수는 그 도메인에서의 의미를 가진다.

**안티패턴:**
```typescript
@Injectable()
export class CreateRealtimeService {
  // ...
  // 여러 호출부에서 Constants.GMCC 직접 사용
  await this.save(RealtimeReservationNotification.of(allocation, employee.compCd, Constants.GMCC));
  // ...
  message.allocatedCompanyCode = Constants.GMCC;
}
```

**리팩토링:**
```typescript
@Injectable()
export class CreateRealtimeService {
  /// 실시간 예약의 배차를 실제로 수행하는 법인 코드 (실시간 예약은 GMCC 에서 수행)
  private static readonly ALLOCATED_COMPANY_CODE = Constants.GMCC;

  // ...
  await this.save(
    RealtimeReservationNotification.of(allocation, employee.compCd, CreateRealtimeService.ALLOCATED_COMPANY_CODE),
  );
}
```

### R27: 과도한 서비스 분리 → 응집도 기반 병합

R2(서비스 단일 도메인 집중)의 **역방향 보완**이다. 도메인별로 서비스를 나누는 것이 기본이지만, 실제로 같은 작업을 하는 두 서비스가 서로를 주입하거나 private 헬퍼를 중복 구현하고 있다면 **병합**한다. 분리만이 능사는 아니다.

판단 기준:
- 두 서비스가 같은 핵심 엔티티의 같은 라이프사이클 동작(예: "배차 취소")을 나눠 가지고 있는가?
- private 헬퍼가 서로 복붙되거나 공통 서비스를 만들어 억지로 공유하고 있는가?
- 호출 경로가 한 서비스 → 다른 서비스로만 흐르고 있는가?

셋 다 해당되면 병합 신호다.

**예시:**
- `CancelRealtimeReservationService`와 `CancelAllocationService`는 둘 다 결국 "배차를 취소"한다.
- 전자를 후자로 병합하면 `validateCancelEmployeePermission`, `handleCancellationError` 같은 헬퍼가 자연스럽게 공유된다.
- 호출부(컨트롤러)는 `CancelAllocationService` 하나만 주입하면 된다.

병합할 때 주의:
- 기존 모듈의 `providers`에서 삭제된 서비스 제거
- 병합된 서비스가 다른 모듈에서도 쓰이면 `exports` 배열에 추가
- 공개 메서드 시그니처는 유지해서 호출부 변경 범위를 최소화

### R28: 서비스 내부 반복 인라인 함수 → private 메서드 + 파라미터화

한 서비스 안의 여러 메서드에서 **동일한 인라인 `function`** 이 복붙돼 있으면 private 메서드로 합친다. 차이 부분(에러 메시지, 기본값 등)은 파라미터로 받는다.

R16은 **여러 DTO 간** 중복을 Utils 클래스로, R28은 **한 서비스 내** 중복을 private 메서드로 해결한다. 범위와 도구가 다르다.

**안티패턴:**
```typescript
public async updateExternalMemo(...) {
  try { /* ... */ }
  catch (error) {
    throw new BadRequestException(getErrorMessage(error));
  }
  function getErrorMessage(error: any) {
    return error?.response?.statusCode >= 500
      ? '메모 변경 중 오류가 발생하였습니다.'
      : error?.response?.message;
  }
}

public async updateBaggageCount(...) {
  try { /* ... */ }
  catch (error) {
    throw new BadRequestException(getErrorMessage(error));
  }
  function getErrorMessage(error: any) {
    return error?.response?.statusCode >= 500
      ? '수화물 개수 변경 중 오류가 발생하였습니다.'
      : error?.response?.message;
  }
}
// ... 같은 패턴 5개 더
```

**리팩토링:**
```typescript
public async updateExternalMemo(...) {
  try { /* ... */ }
  catch (error) {
    throw new BadRequestException(
      this.getErrorMessage(error, '메모 변경 중 오류가 발생하였습니다.'),
    );
  }
}

public async updateBaggageCount(...) {
  try { /* ... */ }
  catch (error) {
    throw new BadRequestException(
      this.getErrorMessage(error, '수화물 개수 변경 중 오류가 발생하였습니다.'),
    );
  }
}

private getErrorMessage(error: any, serverErrorMessage: string): string {
  return error?.response?.statusCode >= 500 ? serverErrorMessage : error?.response?.message;
}
```

---

## 적용 시 주의사항

- 리팩토링은 기능 변경이 아니다. 동작을 바꾸지 않는다.
- 프로젝트마다 약간의 패턴 차이가 있을 수 있다. 해당 프로젝트의 기존 컨벤션을 먼저 파악한다.
- 대규모 리팩토링은 단계별로 나누어 진행한다.
