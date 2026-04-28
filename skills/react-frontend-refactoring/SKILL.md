---
name: react-frontend-refactoring
description: "React/Next.js 프론트엔드 코드 체계적 리팩토링 스킬. 성능, 코드 품질, 접근성, 모던 패턴 관점에서 분석하고 단계적으로 개선한다. '리팩토링', 'refactor', '코드 개선', '코드 정리', 'clean up', 'improve code quality', '성능 개선', '안티패턴 수정', '코드 리뷰 후 수정' 등의 요청 시 반드시 사용한다. 단순 버그 수정이나 새 기능 추가에는 사용하지 않고, 기존 코드의 구조적 개선이 목적일 때 사용한다."
---

# React/Next.js Frontend Refactoring

기존 React/Next.js 코드를 체계적으로 분석하고 개선하는 리팩토링 전문 스킬. 단순히 문제를 찾는 것이 아니라, 우선순위를 매기고 실제로 고치는 것까지가 범위다.

## 리팩토링 워크플로우

반드시 4단계를 순서대로 진행한다. 각 단계에서 사용자 확인을 받고 다음으로 넘어간다.

### Phase 1: 분석 (Analyze)

대상 코드를 읽고 아래 체크리스트 순서로 문제를 탐지한다. 발견 즉시 `[CRITICAL]`, `[HIGH]`, `[MEDIUM]`, `[LOW]` 태그를 붙인다.

#### 1-1. 성능 (Performance)

우선순위가 높은 순서대로 검사한다.

**CRITICAL - 워터폴/직렬 요청**
- 순차적 await가 병렬 가능한 경우 → `Promise.all()` 또는 병렬 쿼리
- 부모-자식 간 데이터 fetch 워터폴 → 병렬 fetch 또는 prefetch
- API 라우트에서 응답 전에 불필요한 await → 비동기 작업 분리

**CRITICAL - 번들 사이즈**
- barrel import (`index.ts`에서 re-export) → 직접 import
- 무거운 라이브러리를 정적 import → `next/dynamic` 또는 lazy import
- 서드파티 스크립트 즉시 로딩 → hydration 후 로딩

**HIGH - 불필요한 리렌더링**
- useEffect로 파생 상태 계산 → 렌더 중 직접 계산
- 콜백에서 최신 state를 읽기 위해 state 구독 → functional setState
- Context가 자주 변하는 큰 객체 → 분리 또는 selector 패턴
- 부모 리렌더가 자식 전체를 리렌더 → composition 패턴 또는 memo

**MEDIUM - 렌더링 최적화**
- 긴 리스트에 `content-visibility` 미적용
- 이미지 최적화 미적용 (`next/image` 미사용)
- 불필요한 CSS-in-JS 런타임 → Tailwind 유틸리티

#### 1-2. 코드 품질 (Code Quality)

**CRITICAL - 버그 유발 패턴**
- `useEffect` 의존성 배열 누락/불완전
- 조건부 Hook 호출 (Rules of Hooks 위반)
- state 직접 mutation (`.push()`, `.splice()` 후 set)
- 동적 리스트에서 `key={index}`
- cleanup 없는 useEffect (이벤트 리스너, 타이머, 구독)
- 서버 상태를 로컬 state에 복사 후 useEffect로 동기화

**HIGH - 타입 안전성**
- `any` 타입 남용 (3개 이상이면 지적)
- API 응답 타입 미정의
- optional chaining 남용으로 실제 null 에러 은폐
- 제네릭 미활용으로 타입 반복

**MEDIUM - 구조/가독성**
- 컴포넌트 300줄 초과 → 분리 필요
- prop drilling 3레벨 이상 → composition 또는 context
- 중첩 삼항 연산자 → early return 또는 컴포넌트 분리
- 비즈니스 로직이 컴포넌트에 직접 존재 → custom hook 추출

#### 1-3. React Query 패턴

**HIGH - 서버 상태 관리**
- `useQuery` 결과를 `useState`에 복사 → query가 source of truth
- queryKey 불일치 (파라미터 누락) → 캐시 불일치 버그
- `onSuccess`/`onError` 콜백에서 state 업데이트 → select 또는 직접 사용
- mutation 후 수동 refetch → `invalidateQueries` 활용

**MEDIUM - 쿼리 구조**
- queryOptions 미사용 → queryOptions 팩토리 패턴
- queryKey 하드코딩 → keys 객체로 중앙 관리
- 불필요한 `enabled: !!param` → param 체크 후 조건부 렌더

#### 1-4. 스타일링

**MEDIUM**
- 인라인 스타일 객체가 렌더마다 새로 생성 → Tailwind 유틸리티 또는 상수 추출
- styled-components에서 props 기반 동적 스타일 과다 → CVA 또는 Tailwind variant
- 하드코딩 색상/간격 → 디자인 토큰 또는 Tailwind 테마
- 중복 스타일 패턴 → 공통 컴포넌트 추출

#### 1-5. 접근성 (Accessibility)

**HIGH**
- 클릭 가능한 div/span에 role, tabIndex 누락
- 이미지에 alt 누락
- 폼 요소에 label 미연결
- 색상만으로 상태 구분 (색약 고려 부족)

**MEDIUM**
- 키보드 네비게이션 불가한 인터랙티브 요소
- aria-label 누락된 아이콘 버튼
- focus 스타일 제거 (`outline-none`만 있고 대체 스타일 없음)

### Phase 2: 계획 (Plan)

분석 결과를 바탕으로 리팩토링 계획을 세운다.

**출력 형식:**

```
## 리팩토링 계획

### 즉시 수정 (CRITICAL)
1. [파일:라인] 문제 설명 → 해결 방안
2. ...

### 우선 개선 (HIGH)  
1. [파일:라인] 문제 설명 → 해결 방안
2. ...

### 추후 개선 (MEDIUM/LOW)
1. [파일:라인] 문제 설명 → 해결 방안
2. ...

### 예상 영향
- 성능: ...
- 번들 사이즈: ...
- 코드 라인 수: ...
- 타입 안전성: ...
```

계획을 사용자에게 보여주고 **반드시 승인을 받은 후** Phase 3로 진행한다. 사용자가 일부만 선택하면 선택된 항목만 진행한다.

### Phase 3: 실행 (Execute)

승인된 계획에 따라 코드를 수정한다.

#### 3-1. 작업 순서 결정 — 의존성 DAG 우선

Phase 2의 계획은 severity(CRITICAL→HIGH→MEDIUM)로 정렬돼 있지만, 실제 실행은 **의존성 순서**가 더 안전하다. 단순히 심각도 순으로 가면 앞 단계의 수정이 뒷 단계의 전제를 깨뜨려 불필요한 재작업이 생긴다.

기본 의존성 순서 (앞 단계가 뒷 단계의 신뢰 기반이 된다):

1. **타입 정리** — 타입/enum 이동, `any` 제거, 인라인 타입 분리
   - *왜 먼저*: `yarn type-check` 한 번으로 영향 범위가 컴파일 에러로 드러난다. 뒷 단계에서 "이 필드가 null일 수 있나?"를 추측이 아닌 타입 시스템에 물어볼 수 있다.
2. **순수 함수/헬퍼 추출** — 중복 로직을 순수 함수로 분리
3. **커스텀 훅 추출** — 추출된 순수 함수를 감싸는 훅 생성
4. **mutation/쿼리 패턴 정리** — `useMutation`/`queryOptions` 교체
5. **UI 구조 정리** — 컴포넌트 분리, 파생 상태 제거, `useReducer` 전환
6. **DOM/이벤트 정리** — DOM 직접 조작 제거, socket/타이머 cleanup
7. **스타일 정리** — CVA, Tailwind 전환, styled-components 제거

severity가 높아도 의존성 순서를 거스르지 않는다. 예: CRITICAL이라도 DOM 조작 수정은 앞 단계에서 타입/훅이 정리된 후에 하는 게 안전하다.

#### 3-2. 원자 단위 분할 — 되돌리기 쉬운 최소 단위

각 수정은 **독립 커밋이 가능한 최소 단위**로 쪼갠다. "한 파일 한 줄 변경"도 별도 작업이 될 수 있다. 이유:

- **git bisect 가능성**: 나중에 회귀가 발생했을 때 원인 커밋을 이등분 탐색으로 정확히 찾을 수 있다. 여러 수정을 한 커밋에 몰아넣으면 어떤 변경이 범인인지 파악 불가.
- **blast radius 축소**: 한 작업이 실패하면 그 하나만 되돌리면 된다.
- **리뷰 용이성**: 리뷰어가 한 번에 하나의 관심사만 평가.

각 단위 완료 후 **즉시** Phase 4 검증 루틴을 돌리고 커밋한다. 여러 단위를 모아서 검증하지 않는다.

#### 3-3. 사전 grep 조사 — 영향 범위와 숨은 중복 탐색

타입, enum, 함수, 훅을 이동/변경하기 전에 반드시 `Grep`으로 **전체 사용처**를 먼저 스캔한다. 이유:

- **숨겨진 중복 발견**: enum이나 타입이 다른 곳에 조용히 복사돼 있는 경우가 많다. 이름으로 grep하면 "비공개(non-export) 로컬 복사본"이 드러난다. 이런 중복은 현재는 TypeScript 구조적 호환으로 돌아가지만 언젠가 어긋나는 시한폭탄이다.
- **영향 범위 산정**: 10곳에서 쓰는지, 100곳에서 쓰는지를 알아야 작업 크기를 현실적으로 예측할 수 있다.
- **네이밍 충돌 탐지**: 이름이 같은 다른 개념이 있는지 미리 확인.

grep 결과는 Phase 2의 계획 단계로 되돌아가 반영한다. "몰랐던 사용처가 드러나면 계획을 수정하는 게 정상"이다.

#### 3-4. 일반 실행 원칙

- 각 수정 후 변경 내용을 간략히 보고
- 기능 변경 없이 동작을 보존하는 것이 최우선
- import 정렬은 ESLint에 위임 (수동 정렬 금지). perfectionist 등 플러그인 설정이 CLAUDE.md 문서와 다를 수 있으니 **실제 ESLint 설정이 최종 규칙**이다. `yarn lint:fix`에 맡긴다.
- 기존 프로젝트의 컨벤션과 패턴을 따름

**수정 시 참조할 기존 스킬:**
- 성능 개선 시: `vercel-react-best-practices` 스킬의 규칙 참조
- 코드 품질 시: `typescript-react-reviewer` 스킬의 패턴 참조  
- UI 구조 개선 시: `frontend-design` 스킬의 가이드 참조
- 접근성 시: `web-design-guidelines` 스킬의 체크리스트 참조
- Tailwind 변환 시: `tailwindcss` 스킬 참조
- 라이브러리 API 확인 시: `context7-mcp` 스킬로 최신 문서 조회

### Phase 4: 검증 (Verify)

검증은 **전체 완료 후 한 번이 아니라 각 작업 단위가 끝날 때마다 반복**한다. Phase 3-2의 원자 단위 분할과 짝을 이루는 루틴이다.

각 원자 작업마다 아래 루프를 돈다:

```
작업 수정 → type-check → (필요 시 build) → 커밋 → 다음 작업
```

**검증 단계 선택 기준:**

| 변경 종류 | type-check | lint | build | test |
|---|---|---|---|---|
| 타입/enum 이동, interface 분리 | ✅ | — | ⚠️ 크로스 프로젝트 영향 우려 시 | — |
| 로직 추출, 훅 분리 | ✅ | — | ✅ | ✅ 있다면 |
| DOM/socket/이벤트 정리 | ✅ | — | ✅ | ✅ 있다면 + 수동 회귀 |
| 스타일(Tailwind/CVA) 정리 | ✅ | — | ✅ | — |

- **type-check**는 매번 돌린다 (5~10초, 가장 확실한 안전망).
- **lint**는 pre-commit hook(lint-staged)에 위임하고 수동 실행은 생략한다. 어차피 커밋 시점에 staged 파일만 검사된다.
- **build**는 매번은 아니지만, 빌드 타임 체크가 필요한 변경(Next.js 라우팅, 동적 import, SSR 관련, 큰 구조 변경)에서는 반드시 돌린다.
- 빌드/타입 에러가 나오면 **그 자리에서 수정**한다. 다음 작업으로 넘어가지 않는다. 에러가 누적되면 어떤 작업이 범인인지 찾기 어려워진다.

각 단위 커밋 시에는 `git add <파일 명시>`로 **관련 파일만 staging**한다. `git add .`이나 `git add -A`는 무관한 auto-fix 결과(다른 파일의 lint 수정 등)까지 섞여 들어가 커밋의 의도를 흐린다. lint-staged는 staged 파일만 처리하므로, 이 원칙은 pre-commit hook과 자연스럽게 맞물려 동작한다.

## 리팩토링 범위 조절

사용자 요청에 따라 범위를 조절한다:

| 요청 | 범위 | 예시 |
|------|------|------|
| "이 파일 리팩토링" | 단일 파일, 전체 체크리스트 | Phase 1-4 전체 |
| "성능 개선" | 성능 항목만 집중 | 1-1 섹션만 분석 |
| "코드 정리" | 코드 품질 + 구조 | 1-2 섹션 중심 |
| "React Query 패턴 정리" | RQ 패턴만 | 1-3 섹션만 분석 |
| "이 컴포넌트 개선" | 해당 컴포넌트 + 관련 훅 | 전체 체크리스트, 좁은 범위 |
| "이 디렉토리 전체 리팩토링" | 디렉토리 내 모든 파일 | 파일별 순차 진행 |

## 리팩토링 판단 기준

리팩토링은 "더 좋은 코드"가 아니라 "더 적절한 코드"를 만드는 것이다. 아래 기준으로 수정 여부를 판단한다.

**수정해야 하는 경우:**
- 버그를 유발하거나 유발할 가능성이 높은 패턴
- 측정 가능한 성능 저하를 일으키는 코드
- 타입 안전성을 해치는 `any` 남용
- 다음 개발자가 이해하기 어려운 구조

**수정하지 않는 경우:**
- 동작하고, 읽기 쉽고, 성능 문제가 없는 코드
- 취향 차이 수준의 스타일 변경 (예: `forEach` vs `map`)
- 현재 프로젝트 컨벤션에 맞는 패턴 (프로젝트 컨벤션 > 일반 베스트 프랙티스)
- 리팩토링 비용 대비 개선 효과가 미미한 경우

## 커뮤니케이션 형식

분석 결과를 보고할 때 아래 형식을 따른다:

```
### [CRITICAL] useEffect로 파생 상태 계산
📍 `components/ReservationList.tsx:45`

현재:
const [filteredItems, setFilteredItems] = useState([]);
useEffect(() => {
  setFilteredItems(items.filter(i => i.status === selected));
}, [items, selected]);

개선:
const filteredItems = useMemo(
  () => items.filter(i => i.status === selected),
  [items, selected]
);

이유: useEffect로 파생 상태를 계산하면 불필요한 추가 렌더가 발생한다.
이 경우 items나 selected가 바뀔 때마다 렌더 → effect → setState → 재렌더로
2번 렌더되는데, useMemo로 바꾸면 1번으로 줄어든다.
```

## 제한 사항

- 이 스킬은 **기존 코드의 구조적 개선**에만 사용한다
- 새 기능 추가, 버그 수정, UI 디자인 변경은 범위 밖이다
- 리팩토링 중 기능 변경이 필요하면 사용자에게 별도 확인을 받는다
- 프로젝트의 CLAUDE.md와 코드 컨벤션을 항상 우선한다
