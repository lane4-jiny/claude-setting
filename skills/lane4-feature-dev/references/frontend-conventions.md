# Lane4 Frontend Conventions (Next.js + React)

대상 프로젝트: `lane4-web`, `lane4-admin`, `lane4-biz`

## 디렉토리 레이아웃

```
<project-root>/
├── apis/                          # API 호출 layer (서비스 클래스 패턴)
│   └── <domain>/
│       ├── <domain>.service.ts    # static 메서드 모음
│       └── <domain>.type.ts       # request/response DTO 인터페이스
├── entities/                      # React Query queryOptions + mutations
│   └── <domain>/
│       ├── <domain>.queries.ts    # static class with queryKey + queryOptions
│       └── <domain>.mutation.ts   # useXxx hooks (useMutation 래퍼)
├── components/                    # 공용 컴포넌트
│   └── <Group>/
│       └── <Component>/
│           └── index.tsx
├── pages/ 또는 app/               # Next.js routing (프로젝트별 다름)
├── utils/
│   ├── Axios.ts 또는 AxiosV2.ts   # HTTP 래퍼
│   ├── UserService.ts             # axios instance 설정
│   └── helper/                    # URL helper, format helper 등
├── constants/
├── hooks/                         # 공용 React hooks
└── lib/
```

## HTTP 클라이언트

### 래퍼 위치
- `lane4-web`: `utils/Axios.ts` (메서드: GET, POST, PUT, PATCH, DELETE, FILE)
- `lane4-admin`, `lane4-biz`: `utils/AxiosV2.ts` (+ EXCEL, FILE_PATCH 추가)

### Base 설정 (`utils/UserService.ts`)
```typescript
const axiosInstance = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 15000,  // lane4-web: 15s, lane4-admin: 30s
});

axiosInstance.interceptors.request.use((config) => {
  config.headers.Authorization = `Bearer ${getToken()}`;
  config.headers['X-Lang'] = ...;       // lane4-web만
  config.headers['X-Currency'] = ...;   // lane4-web만
  return config;
});
```

### 응답 envelope
```typescript
type ApiResponse<T> = {
  code: number | null;
  data: T;
  result: boolean;
};
```

서비스 메서드는 `.then((res) => res.data)`로 `data` 부분만 추출하여 반환.

## 서비스 클래스 패턴 (Static)

```typescript
// apis/auth/auth.service.ts
import { Axios } from 'utils/Axios';
import { LoginParams, LoginDto } from './auth.type';

export class AuthService {
  static async login(params: LoginParams) {
    return Axios.POST<LoginDto>({
      url: 'auth/login',
      params,
    }).then((res) => res.data);
  }

  static async getUserInfo() {
    return Axios.GET<UserInfoDto>({
      url: 'auth/userInfo',
    }).then((res) => res.data);
  }
}
```

- `static` 메서드만 사용 (인스턴스화 안 함)
- 메서드 1개 = API 1개
- URL은 인라인 문자열 또는 `utils/helper/UrlHelp.ts`의 상수 사용
- 응답 타입은 제네릭으로 명시 (`<LoginDto>`)
- 항상 `.then((res) => res.data)`로 envelope unwrap

## 타입 정의 (`<domain>.type.ts`)

```typescript
// apis/auth/auth.type.ts

// Request
export interface LoginParams {
  email?: string;
  mobile?: string;
  password: string;
}

// Response
export interface LoginDto {
  accessToken: string;
  refreshToken: string;
  user: UserDto;
}

export interface UserDto {
  id: number;
  email: string;
  // ...
}
```

- 인터페이스 사용 (type alias 보다)
- request: `*Params`, response: `*Dto`
- ⚠️ **타입 중복 정의** — 같은 타입을 lane4-web과 lane4-admin이 따로 정의함. 변경 시 양쪽 동기화.

## React Query 패턴

### Query (entities/<domain>/<domain>.queries.ts)
```typescript
import { queryOptions } from '@tanstack/react-query';
import { AuthService } from 'apis/auth/auth.service';

export class AuthQueries {
  static readonly keys = {
    all: ['auth'] as const,
    userInfo: () => [...AuthQueries.keys.all, 'userInfo'] as const,
  };

  static userInfo() {
    return queryOptions({
      queryKey: AuthQueries.keys.userInfo(),
      queryFn: () => AuthService.getUserInfo(),
    });
  }
}
```

- queryKey는 hierarchical: `['auth', 'userInfo']`
- `static class`에 `keys` 객체와 `queryOptions` 팩토리

### Mutation (entities/<domain>/<domain>.mutation.ts)
```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AuthService } from 'apis/auth/auth.service';
import { AuthQueries } from './auth.queries';

export const useLogin = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: AuthService.login,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: AuthQueries.keys.all });
    },
  });
};
```

- `useXxx` 네이밍
- 성공 시 관련 쿼리 invalidate
- mutation 함수는 service의 static 메서드 직접 참조 (`AuthService.login`)

### 컴포넌트에서 사용
```typescript
import { useQuery } from '@tanstack/react-query';

function ProfilePage() {
  const { data, isLoading } = useQuery(AuthQueries.userInfo());
  // ...
}
```

## 에러 처리

`Axios.ts` wrapper가 `ReservedError` 타입으로 정규화. 컴포넌트는 try-catch 또는 React Query의 `error` 상태로 처리.

```typescript
class ReservedError extends Error {
  code: number;
  message: string;
  // ...
}

const isReservedError = (err: any): err is ReservedError => {
  return err?.data?.message !== undefined;
};
```

## 폼 처리

- **react-hook-form** + **Zod** validation
- 스키마는 컴포넌트 옆 또는 `<Component>/schema.ts`

```typescript
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

type LoginFormValues = z.infer<typeof loginSchema>;

const { register, handleSubmit } = useForm<LoginFormValues>({
  resolver: zodResolver(loginSchema),
});
```

## URL 상수 (선택)

`utils/helper/UrlHelp.ts` 또는 `utils/helper/urlHelp.ts`:
```typescript
export const URL = {
  AUTH_LOGIN_URL: 'auth/login',
  AUTH_USER_INFO_URL: 'auth/userInfo',
  // ...
};
```

서비스 메서드에서 사용:
```typescript
static async login(params: LoginParams) {
  return Axios.POST<LoginDto>({
    url: URL.AUTH_LOGIN_URL,
    params,
  }).then((res) => res.data);
}
```

⚠️ 모든 프로젝트가 일관되게 쓰는 건 아님. 신규 코드는 일관성을 위해 같은 도메인의 기존 파일을 따라가는 것 권장.

## 동적 path (templated URL)

```typescript
static async getCard(cardId: number) {
  return Axios.GET<CardDto>({
    url: `cards/${cardId}`,
  }).then((res) => res.data);
}
```

- 백틱 템플릿 리터럴로 path 구성
- backend 변경 시 같은 path를 grep해야 영향 추적 가능 → impact-analysis 도구가 처리

## 컴포넌트 위치 가이드

- 페이지 단위 컴포넌트: `pages/<route>/index.tsx` (Pages Router) 또는 `app/<route>/page.tsx` (App Router)
- 재사용 컴포넌트: `components/<Group>/<Component>/index.tsx`
- 페이지 전용 보조 컴포넌트: `components/<Page>/<Sub>.tsx` 또는 페이지 폴더 내부

## 스타일

- styled-components 또는 CSS modules (프로젝트별 상이)
- 디자인 토큰: `constants/theme.ts` 또는 `theme/`

## 코드 스타일

- TypeScript strict mode
- 함수형 컴포넌트만 사용
- React 18 / 19 hooks 활용
- import 순서: React → 외부 라이브러리 → 내부 모듈 → 상대 경로
- 한 파일 한 컴포넌트 원칙
- 식별자/주석 영문, 주석은 한국어 OK
