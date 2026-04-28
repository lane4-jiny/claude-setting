# Lane4 프로젝트 코딩 컨벤션

## 파일/디렉토리 구조

### 모듈 구조
```
src/
  module-name/
    module-name.module.ts
    module-name.controller.ts
    module-name.service.ts
    module-name.repository.ts
    dto/
      create-module-name.dto.ts
      update-module-name.dto.ts
      module-name.response.ts
    entities/
      module-name.entity.ts
```

### 기능 단위 분리 패턴
```
src/
  allocation/
    find-allocation/
      find-allocation.controller.ts
      find-allocation.service.ts
      find-allocation.repository.ts
      find-allocation.response.ts
    create-allocation/
      create-allocation.controller.ts
      create-allocation.service.ts
```

## 네이밍 규칙

### 파일명
- kebab-case 사용: `find-allocation.service.ts`
- 역할 접미사 필수: `.controller.ts`, `.service.ts`, `.repository.ts`, `.dto.ts`, `.entity.ts`, `.response.ts`

### 클래스명
- PascalCase 사용
- Controller: `FindAllocationController`
- Service: `FindAllocationService`
- Repository: `FindAllocationRepository`
- DTO: `CreateAllocationDto`
- Entity: `AllocationEntity` 또는 `Allocation`
- Response: `FindAllocationResponse`

### 변수/메서드명
- camelCase 사용
- 동사 + 명사 형태: `findAllocation`, `createCallReq`
- Boolean: is/has/can 접두사: `isActive`, `hasPermission`

### DB 컬럼 (Entity)
- 테이블별로 UPPER_SNAKE_CASE 또는 lower_snake_case 혼용 (레거시)
- 새 컬럼 추가시 기존 테이블의 컨벤션을 따름

## 코드 패턴

### API 응답 형식
- 성공: Response DTO를 통해 구조화된 응답
- 에러: HttpException 계열 사용

### 트랜잭션 처리
- 다중 INSERT/UPDATE는 반드시 트랜잭션 사용
- QueryRunner 또는 @Transactional 데코레이터

### Guard 사용
- JWT 인증: `@UseGuards(JwtAuthGuard)`
- 역할 기반: `@Roles()` + `RolesGuard`
- API별 Guard 설정 필수 (public API 제외)

### DTO 검증
- class-validator + class-transformer 사용
- 모든 입력 DTO에 검증 데코레이터 필수
- ValidationPipe 글로벌 설정

### Repository 패턴
- TypeORM Repository 또는 QueryBuilder 사용
- 복잡한 쿼리는 QueryBuilder로 작성
- Raw Query 사용시 파라미터 바인딩 필수

## 공통 규칙

- console.log 금지 → Logger 사용
- any 타입 사용 최소화
- 매직 넘버 금지 → 상수 또는 enum 사용
- 비동기 함수는 async/await 사용
- 불필요한 주석 금지 (코드가 자명하게)
- import 정렬: 외부 모듈 → 내부 모듈 → 상대경로
