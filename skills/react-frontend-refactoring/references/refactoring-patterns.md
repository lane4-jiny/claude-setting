# 리팩토링 패턴 레퍼런스

Phase 3 실행 시 참고하는 구체적인 변환 패턴 모음. 프로젝트 컨벤션에 맞게 적용한다.

## 목차

1. [useEffect 제거 패턴](#1-useeffect-제거-패턴)
2. [React Query 정규화](#2-react-query-정규화)
3. [컴포넌트 분리 패턴](#3-컴포넌트-분리-패턴)
4. [타입 안전성 강화](#4-타입-안전성-강화)
5. [성능 최적화 패턴](#5-성능-최적화-패턴)
6. [스타일링 정리](#6-스타일링-정리)

---

## 1. useEffect 제거 패턴

### 1-1. 파생 상태 → 직접 계산 또는 useMemo

```typescript
// Before
const [filtered, setFiltered] = useState([]);
useEffect(() => {
  setFiltered(items.filter(i => i.status === status));
}, [items, status]);

// After (계산이 가벼운 경우)
const filtered = items.filter(i => i.status === status);

// After (계산이 무거운 경우)
const filtered = useMemo(
  () => items.filter(i => i.status === status),
  [items, status],
);
```

판단 기준: 배열 크기 100개 미만이면 직접 계산, 이상이면 useMemo. 정렬이 포함되면 항상 useMemo.

### 1-2. 이벤트 로직 → 이벤트 핸들러로 이동

```typescript
// Before
useEffect(() => {
  if (isSuccess) {
    showToast('저장 완료');
    router.push('/list');
  }
}, [isSuccess]);

// After (mutation의 onSuccess)
const mutation = useMutation({
  mutationFn: saveData,
  onSuccess: () => {
    showToast('저장 완료');
    router.push('/list');
  },
});
```

### 1-3. 외부 시스템 동기화 → cleanup 필수

```typescript
// Before (cleanup 누락)
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = handleMessage;
}, [url]);

// After
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = handleMessage;
  return () => ws.close();
}, [url]);
```

## 2. React Query 정규화

### 2-1. queryOptions 팩토리 패턴

```typescript
// Before (인라인 쿼리)
const { data } = useQuery({
  queryKey: ['reservations', 'list', params],
  queryFn: () => ReservationService.findAll(params),
});

// After (Queries 클래스)
// entities/reservation/reservation.queries.ts
export class ReservationQueries {
  static readonly keys = {
    all: ['reservation'],
    list: (params: ListParams) => [...this.keys.all, 'list', params],
    detail: (id: number) => [...this.keys.all, 'detail', id],
  };

  static list(params: ListParams) {
    return queryOptions({
      queryKey: this.keys.list(params),
      queryFn: () => ReservationService.findAll(params),
    });
  }

  static detail(id: number) {
    return queryOptions({
      queryKey: this.keys.detail(id),
      queryFn: () => ReservationService.findOne(id),
    });
  }
}

// 사용처
const { data } = useQuery(ReservationQueries.list(params));
```

### 2-2. 서버 상태 로컬 복사 제거

```typescript
// Before
const { data } = useQuery(ReservationQueries.list(params));
const [items, setItems] = useState([]);
useEffect(() => {
  if (data) setItems(data.list);
}, [data]);

// After - query 결과를 직접 사용
const { data } = useQuery(ReservationQueries.list(params));
const items = data?.list ?? [];
```

### 2-3. mutation 후 캐시 무효화

```typescript
// Before
const mutation = useMutation({
  mutationFn: ReservationService.create,
  onSuccess: () => {
    refetch(); // 수동 refetch
  },
});

// After
const queryClient = useQueryClient();
const mutation = useMutation({
  mutationFn: ReservationService.create,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ReservationQueries.keys.all });
  },
});
```

## 3. 컴포넌트 분리 패턴

### 3-1. 큰 컴포넌트 분리 기준

300줄 이상이면 분리를 고려하되, 기계적으로 분리하지 않는다.

**분리해야 하는 경우:**
- 독립적인 상태를 가진 UI 블록이 2개 이상
- 같은 JSX 패턴이 2회 이상 반복
- 조건부 렌더 블록이 50줄 이상

**분리하지 않는 경우:**
- 단순히 길지만 선형적으로 읽히는 폼
- 상태가 밀접하게 연결된 UI

### 3-2. custom hook 추출

```typescript
// Before - 컴포넌트에 로직이 직접 존재
export default function ReservationPage() {
  const [params, setParams] = useState(defaultParams);
  const { data, isLoading } = useQuery(ReservationQueries.list(params));
  const mutation = useMutation({ ... });
  
  const handleSearch = () => { ... };
  const handleReset = () => { ... };
  const handleCreate = () => { ... };
  
  // ... 30줄의 핸들러 로직
  
  return <div>...</div>;
}

// After - 로직을 hook으로 추출
function useReservationList() {
  const [params, setParams] = useState(defaultParams);
  const { data, isLoading } = useQuery(ReservationQueries.list(params));
  const mutation = useMutation({ ... });
  
  const handleSearch = () => { ... };
  const handleReset = () => { ... };
  const handleCreate = () => { ... };
  
  return { data, isLoading, params, handleSearch, handleReset, handleCreate };
}

export default function ReservationPage() {
  const { data, isLoading, params, handleSearch, handleReset, handleCreate } = useReservationList();
  return <div>...</div>;
}
```

## 4. 타입 안전성 강화

### 4-1. any 제거 전략

```typescript
// Before
const handleChange = (value: any) => {
  setFormData({ ...formData, [field]: value });
};

// After - 제네릭 활용
const handleChange = <K extends keyof FormData>(field: K, value: FormData[K]) => {
  setFormData(prev => ({ ...prev, [field]: value }));
};
```

### 4-2. API 응답 타입 정의

```typescript
// Before
const { data } = useQuery({
  queryKey: ['info'],
  queryFn: () => AxiosV2.GET({ url: 'info' }),
});
// data는 any

// After
interface InfoResponse {
  id: number;
  name: string;
  status: StatusType;
}

const { data } = useQuery({
  queryKey: ['info'],
  queryFn: () => AxiosV2.GET<InfoResponse>({ url: 'info' }),
});
```

### 4-3. discriminated union으로 상태 분기

```typescript
// Before
interface ModalState {
  isOpen: boolean;
  mode?: 'create' | 'edit';
  editId?: number;
}

// After
type ModalState =
  | { isOpen: false }
  | { isOpen: true; mode: 'create' }
  | { isOpen: true; mode: 'edit'; editId: number };
```

## 5. 성능 최적화 패턴

### 5-1. 병렬 데이터 페칭

```typescript
// Before (워터폴)
const { data: user } = useQuery(UserQueries.me());
const { data: reservations } = useQuery(
  ReservationQueries.list({ userId: user?.id }),
);

// After (병렬 - 독립적인 경우)
const { data: user } = useQuery(UserQueries.me());
const { data: stats } = useQuery(DashboardQueries.stats());
// 두 쿼리가 독립적이면 React Query가 자동 병렬 실행

// After (의존적인 경우 - enabled 활용)
const { data: user } = useQuery(UserQueries.me());
const { data: reservations } = useQuery({
  ...ReservationQueries.list({ userId: user!.id }),
  enabled: !!user?.id,
});
```

### 5-2. 동적 import

```typescript
// Before
import HeavyChart from '@/components/HeavyChart';

// After
import dynamic from 'next/dynamic';
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <Skeleton />,
  ssr: false,
});
```

### 5-3. 리렌더 최적화

```typescript
// Before - 부모가 리렌더될 때마다 자식도 리렌더
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>{count}</button>
      <ExpensiveChild items={items} /> {/* items가 안 바뀌어도 리렌더 */}
    </div>
  );
}

// After - composition 패턴
function Parent() {
  return (
    <div>
      <Counter />
      <ExpensiveChild items={items} />
    </div>
  );
}

function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

## 6. 스타일링 정리

### 6-1. 인라인 스타일 → Tailwind

```typescript
// Before
<div style={{ display: 'flex', gap: '8px', padding: '16px' }}>

// After
<div className="flex gap-2 p-4">
```

### 6-2. 조건부 스타일 → CVA 또는 clsx

```typescript
// Before
<button
  className={`px-4 py-2 rounded ${
    variant === 'primary'
      ? 'bg-blue-500 text-white'
      : variant === 'secondary'
      ? 'bg-gray-200 text-gray-800'
      : 'bg-transparent border'
  }`}
>

// After (clsx)
import { clsx } from 'clsx';

<button
  className={clsx('px-4 py-2 rounded', {
    'bg-blue-500 text-white': variant === 'primary',
    'bg-gray-200 text-gray-800': variant === 'secondary',
    'bg-transparent border': variant === 'ghost',
  })}
>
```

### 6-3. 반복 스타일 → 공통 컴포넌트

동일한 Tailwind 클래스 조합이 3회 이상 반복되면 컴포넌트로 추출한다. 2회 이하는 그냥 둔다.
