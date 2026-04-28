# 코드 분석 패턴

기술 스택별 코드에서 정보를 추출하는 패턴.

## 백엔드 (NestJS / TypeORM)

### Entity 분석

```typescript
// 추출 대상
@Entity('coupons')
export class CouponEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'enum', enum: CouponStatus })
  status: CouponStatus;  // → 상태 enum 추출

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  discountAmount: number;  // → 필드 타입, 제약조건 추출

  @ManyToOne(() => UserEntity)
  user: UserEntity;  // → 관계 추출
}
```

**추출 정보:**
- 테이블명, 컬럼 타입/제약조건
- enum 값 (상태 흐름에 사용)
- 관계 (1:N, N:M 등) → 의존 도메인 파악

### Controller 분석

```typescript
// 추출 대상
@Controller('coupons')
@UseGuards(AuthGuard)  // → 인증 필요 여부
export class CouponController {
  
  @Post()
  @HttpCode(201)
  async create(@Body() dto: CreateCouponDto): Promise<CouponResponseDto> {}
  // → POST /coupons, 요청/응답 DTO

  @Get(':id')
  @UseInterceptors(CacheInterceptor)  // → 캐싱 정책
  async findOne(@Param('id') id: number) {}
}
```

**추출 정보:**
- HTTP 메서드, 경로, 상태 코드
- Guard (인증/인가)
- Interceptor (캐싱, 로깅)
- 요청/응답 DTO

### Service 비즈니스 로직 추출

```typescript
// 비즈니스 규칙 패턴
async applyCoupon(couponId: number, orderId: number) {
  // 규칙 1: 쿠폰 유효성 검사
  if (coupon.status !== CouponStatus.ISSUED) {
    throw new BadRequestException('사용할 수 없는 쿠폰입니다');
  }

  // 규칙 2: 최소 주문 금액 검사
  if (order.totalAmount < coupon.minOrderAmount) {
    throw new BadRequestException('최소 주문 금액을 충족하지 않습니다');
  }

  // 규칙 3: 중복 사용 검사
  const usedCount = await this.couponUsageRepo.count({ couponId });
  if (usedCount >= coupon.maxUsageCount) {
    throw new ConflictException('사용 횟수를 초과했습니다');
  }
}
```

**추출 패턴:**
- `if` 조건문 → 비즈니스 규칙
- `throw new *Exception` → 에러 케이스
- 숫자 상수 → 정책값 (최소 금액, 최대 횟수 등)

### DTO Validation 추출

```typescript
export class CreateCouponDto {
  @IsString()
  @MinLength(4)
  @MaxLength(20)
  code: string;  // → 4~20자 문자열

  @IsNumber()
  @Min(1000)
  @Max(100000)
  discountAmount: number;  // → 1,000~100,000 범위

  @IsOptional()
  @IsDate()
  expiresAt?: Date;  // → 선택적 필드
}
```

**추출 정보:**
- 필수/선택 필드
- Validation 규칙 (길이, 범위, 형식)

---

## 프론트엔드 (React / NextJS)

### API 호출 추출

```typescript
// src/api/coupon.ts
export const couponApi = {
  // → GET /api/coupons
  getList: () => api.get<CouponListResponse>('/api/coupons'),
  
  // → POST /api/coupons/:id/apply
  apply: (id: number, orderId: number) => 
    api.post<ApplyResponse>(`/api/coupons/${id}/apply`, { orderId }),
};
```

**추출 정보:**
- API 엔드포인트 목록
- 요청/응답 타입

### 상태 관리 추출

```typescript
// Recoil/Zustand/Redux
const couponState = atom({
  key: 'couponState',
  default: {
    selectedCoupon: null,
    appliedCoupons: [],  // → 클라이언트 상태
    isLoading: false,
  },
});
```

**추출 정보:**
- 클라이언트 전용 상태
- 로딩/에러 상태 관리 방식

### 조건부 렌더링에서 비즈니스 로직 추출

```tsx
// 프론트엔드 전용 비즈니스 로직
{coupon.expiresAt && isAfter(new Date(), coupon.expiresAt) && (
  <Badge color="red">만료됨</Badge>  // → 만료 표시 로직
)}

{appliedCoupons.length >= 3 && (
  <Alert>쿠폰은 최대 3개까지 적용 가능합니다</Alert>  // → 최대 적용 개수
)}

{order.totalAmount < coupon.minOrderAmount && (
  <Text color="gray">
    {coupon.minOrderAmount - order.totalAmount}원 더 주문하면 사용 가능
  </Text>  // → 남은 금액 안내 (프론트 전용 UX)
)}
```

**추출 정보:**
- 프론트엔드에서 추가된 비즈니스 규칙
- UX 향상을 위한 추가 로직

### 에러 핸들링 추출

```typescript
try {
  await couponApi.apply(couponId, orderId);
} catch (error) {
  if (error.code === 'COUPON_EXPIRED') {
    toast.error('쿠폰이 만료되었습니다');
  } else if (error.code === 'MIN_ORDER_AMOUNT') {
    toast.error('최소 주문 금액을 충족하지 않습니다');
  } else if (error.code === 'ALREADY_USED') {
    // 백엔드에 없는 에러 코드! → 크로스-프로젝트 불일치
    toast.error('이미 사용한 쿠폰입니다');
  }
}
```

**추출 정보:**
- 처리하는 에러 코드 목록
- 백엔드와 불일치하는 에러 코드

---

## 모바일 (React Native)

### 웹과 동일한 패턴 + 추가 분석

```typescript
// 오프라인 처리
const applyCoupon = async (couponId: number) => {
  if (!isConnected) {
    // 오프라인 큐에 저장 (모바일 전용)
    await offlineQueue.add({ action: 'APPLY_COUPON', couponId });
    return;
  }
  // ...
};

// 플랫폼별 분기
const renderCouponCard = () => {
  if (Platform.OS === 'ios') {
    // iOS 전용 UI
  } else {
    // Android 전용 UI
  }
};
```

**추가 추출 정보:**
- 오프라인 처리 로직
- 플랫폼별 분기 (iOS/Android)
- 딥링크 처리
- 푸시 알림 연동

---

## 크로스-프로젝트 대조 패턴

### 1. API 엔드포인트 대조

```
백엔드 Controller에서 추출한 엔드포인트:
- POST /coupons
- GET /coupons
- GET /coupons/:id
- POST /coupons/:id/apply

프론트엔드 API 호출:
- POST /coupons ✓
- GET /coupons ✓
- GET /coupons/:id ✓
- POST /coupons/:id/apply ✓
- DELETE /coupons/:id ✗ (백엔드에 없음!) → 문서화
```

### 2. 에러 코드 대조

```
백엔드 Exception에서 추출:
- COUPON_NOT_FOUND
- COUPON_EXPIRED
- MIN_ORDER_NOT_MET

프론트엔드 에러 핸들링:
- COUPON_NOT_FOUND ✓
- COUPON_EXPIRED ✓
- MIN_ORDER_NOT_MET ✓
- ALREADY_USED ✗ (백엔드에 없음!) → 문서화
```

### 3. 상태값 대조

```
백엔드 Enum:
enum CouponStatus {
  ISSUED = 'ISSUED',
  USED = 'USED',
  EXPIRED = 'EXPIRED',
}

프론트엔드 상수:
const COUPON_STATUS = {
  ISSUED: 'ISSUED',
  USED: 'USED',
  EXPIRED: 'EXPIRED',
  CANCELLED: 'CANCELLED',  // ✗ 백엔드에 없음!
};
```

### 4. Validation 규칙 대조

```
백엔드 DTO:
- code: 4~20자

프론트엔드 Form:
- code: 1~50자  // ✗ 불일치!
```
