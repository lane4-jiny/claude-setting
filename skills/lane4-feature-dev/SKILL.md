---
name: lane4-feature-dev
description: Lane4 백엔드(NestJS) 또는 프론트엔드(Next.js) 신규 기능을 개발한다. 사용자가 "개발해줘", "만들어줘", "구현해줘", "추가해줘", "기능 추가", "신규 기능", "implement", "develop", "build", "add feature" 등을 언급하고 lane4 프로젝트 컨텍스트가 있을 때 사용한다. cwd로 프로젝트 타입 자동 감지(backend vs frontend)하여 해당 컨벤션 세트 적용. 4단계 워크플로우(컨텍스트 감지 → 의도 명확화 Q&A → Pre-flight 검증 → 구현) 수행. 기존 파일 수정이 포함되면 impact-analysis 스킬 자동 발동하여 사이드이펙트 보고. 변경 파일이 2개 이상이면 플랜 모드(승인 후 구현), 1개 신규 추가만이면 즉시 구현. lane4 특유 컨벤션(NestJS DDD 레이어, Axios 커스텀 래퍼, React Query, 응답 envelope { code, data, result })과 엣지 케이스(듀얼 Redis, MyBatis XML, 로컬 enum 중복)를 매번 점검한다. **모바일(lane4-app-*)은 이 스킬 범위 밖이므로 cwd가 모바일이면 사용자에게 알리고 종료한다.** 단순 버그 수정/이슈 대응은 lane4-issue 스킬 사용.
---

# Lane4 Feature Development

Lane4 코드베이스에서 신규 기능을 개발하는 종합 스킬. 컨텍스트 감지 → 의도 명확화 → 컨벤션/엣지케이스/사이드이펙트 점검 → 구현을 일관된 흐름으로 진행한다.

## 핵심 원칙

1. **컨벤션은 베이크인** — `references/*-conventions.md`에 정의된 패턴을 따른다. 매번 코드베이스 스캔으로 추측하지 않는다.
2. **추측하지 말고 질문** — 모호한 점은 코드 작성 전 `AskUserQuestion`으로 일괄 확인.
3. **사이드이펙트는 도구가 검증** — 기존 파일 수정 포함 시 `impact-analysis` 스킬을 자동 호출하여 file:line 기반 영향 보고.
4. **YAGNI** — 사용자가 요청하지 않은 기능, 미래 확장성, 추상화는 추가하지 않는다.

## 트리거

### 자동 발동 키워드
사용자 메시지에 다음이 등장하면 발동:
- 한국어: 개발해줘, 만들어줘, 구현해줘, 추가해줘, 만들어, 기능 추가, 신규 기능
- 영어: implement, develop, build, add feature

### 발동 차단 조건
- 단순 **버그 수정** 요청은 `lane4-issue` 스킬을 우선
- **사이드이펙트 분석만** 요청이면 `impact-analysis` 스킬을 우선
- **여러 시스템에 걸친 큰 신규 시스템** (예: "결제 도메인 전체 새로 만들자")이면 `brainstorming` 스킬로 위임

## 4단계 워크플로우

### Step 1: 컨텍스트 감지

1. 현재 작업 디렉토리(cwd) 확인:
   ```bash
   pwd
   ```
2. cwd가 어느 lane4 프로젝트인지 매핑:
   | cwd 패턴 | 프로젝트 타입 | 적용 컨벤션 |
   |---------|------------|-----------|
   | `/lane4-*-api`, `/lane4_backend`, `/lane4-scheduler`, `/lane4-notification-server` | **backend** | `references/backend-conventions.md` |
   | `/lane4-web`, `/lane4-admin`, `/lane4-biz` | **frontend** | `references/frontend-conventions.md` |
   | `/lane4-app-driver`, `/lane4-app-user` | **mobile (out of scope)** | 사용자에게 알리고 종료 |
   | `/lane4-backend-library` | **shared lib** | backend 컨벤션 + "이 변경은 모든 consumer에 영향" 경고 |
   | 그 외 (`/IdeaProjects` 루트 등) | **불명확** | 사용자에게 1회 질문 |

3. 모바일이면 다음 메시지 반환 후 종료:
   > 이 스킬은 backend/frontend 전용입니다. 모바일(lane4-app-*) 작업은 일반 흐름으로 진행하시거나 별도 스킬을 사용해주세요.

### Step 2: 의도 명확화 Q&A

1. 사용자 요청에서 다음 카테고리에 해당하는 모호 포인트 추출:
   - **Backend**: 엔드포인트 path/메서드, 권한(Guard), DTO 위치/네이밍, Kafka 이벤트 발행 여부, Redis 캐싱 여부, MyBatis vs TypeORM, 트랜잭션 경계
   - **Frontend**: API 호출 service 클래스 위치, React Query 키, 페이지/컴포넌트 위치, react-hook-form + Zod 스키마 사용 여부, 응답 타입 정의 위치

2. `references/question-templates.md`에서 카테고리별 질문 템플릿 로드

3. 모호 포인트가 2개 이상이면 **AskUserQuestion으로 일괄 질문** (한 번에 multi-select 가능한 형태). 0~1개면 그대로 진행.

4. 답변을 분석 결과에 반영. 사용자가 "Other"로 입력한 자유 답변도 그대로 채택.

### Step 3: Pre-flight 검증

1. **컨벤션 베이스 패턴 확정**
   - 비슷한 기존 파일 1~2개 찾기 (`Glob` 또는 `Grep` 사용)
   - 예: 새 controller 작성 시 같은 도메인의 다른 controller 1개를 베이스로
   - 발견된 베이스 파일 경로를 사용자에게 보고: "다음 패턴을 따릅니다: <path>"

2. **Edge case 점검**
   - `references/edge-case-checklist.md`의 프로젝트별 항목 적용
   - 해당되는 케이스만 보고, 무관한 항목은 침묵
   - 예: "lane4-driver-api에서 Redis 캐싱 추가 → commons/redis vs commons/newRedis vs commons/cache 중 어느 인스턴스 사용?"

3. **사이드이펙트 점검** (조건부)
   - **트리거**: 기존 파일 수정이 포함된 경우 (신규 파일만 추가면 스킵)
   - `~/.claude/scripts/impact/find-callers.sh` 등을 직접 호출하거나 `impact-analysis` 스킬 위임
   - 결과 요약: 영향받는 file:line + 위험도

4. 모든 발견사항을 사용자에게 한 블록으로 보고:
   ```markdown
   ## Pre-flight 결과
   ✅ 베이스 패턴: <file>
   ⚠️ Edge case: <설명>
   🔴/🟡/🟢 사이드이펙트: <요약>
   ```

### Step 4: 구현

1. **모드 자동 판단**
   - 작성/수정할 파일 수 계산
   - **즉시 모드**: 신규 파일 추가만 + 총 변경 1개 (+ 모듈 import 등 사소한 수정 1개 허용)
   - **플랜 모드**: 변경 파일 ≥ 2 OR 기존 파일 수정 포함

2. **사용자 명시 옵션 우선**
   - 사용자가 `--quick` 또는 "빠르게" 명시 → 즉시 모드
   - 사용자가 `--plan` 또는 "플랜 보여줘" 명시 → 플랜 모드

3. **플랜 모드**
   - 변경 파일 목록 (`[신규]` / `[수정]` 표시)
   - 핵심 결정사항 (DTO 위치, 의존성, 응답 타입 등)
   - Pre-flight 발견사항 재인용
   - "승인 후 구현 시작합니다" + 사용자 응답 대기

4. **구현 실행**
   - 베이스 패턴을 따라 코드 작성
   - 한국어 주석은 자제 (식별자/주석 영문, 단 도메인 용어는 한국어 허용 — lane4 컨벤션 따름)
   - Build 검증 명령은 자동 실행하지 않음 (사용자가 직접 결정)

5. **구현 후 자체 점검**
   - 생성한 파일이 베이스 패턴과 일관되는가
   - 응답 envelope `{ code, data, result }` 사용했는가 (frontend) / 컨트롤러 응답 DTO 사용했는가 (backend)
   - import 순서/네이밍이 컨벤션과 맞는가
   - 발견된 불일치는 즉시 수정

## 출력 형식

### 즉시 모드 출력
```markdown
## 컨텍스트
- 프로젝트: <name> (<type>)
- 적용 컨벤션: <conv-set>

## 명확화 답변
- <카테고리>: <답변>

## Pre-flight
✅ 베이스 패턴: <path>
[edge case / 사이드이펙트 발견사항]

## 구현
[파일 작성 — 도구로 직접 진행]

## 자체 점검
✅ 베이스 패턴 일치
✅ 응답 envelope 일치
[수정 내역 있으면 보고]
```

### 플랜 모드 출력
```markdown
## 플랜 (변경 N개)
1. [신규] <path>
2. [신규] <path>
3. [수정] <path>

## 핵심 결정
- <결정 1>
- <결정 2>

## Pre-flight 발견사항
[Step 3 결과]

승인 후 구현 시작합니다.
```

## 다른 스킬과의 관계

| 스킬 | 관계 |
|-----|------|
| `impact-analysis` | Step 3에서 자동 호출 (기존 파일 수정 시) |
| `lane4-issue` | 별개 — 이슈/버그/장애 대응은 그쪽 |
| `brainstorming` | 더 큰 시스템 신규 설계는 그쪽으로 위임 (단일 도메인 기능은 이 스킬이 직접) |
| `nestjs-best-practices` | backend-conventions.md가 핵심 패턴 인용 |
| `git-committer` | 구현 후 사용자가 명시 요청 시 별도 호출 |

## 제약

- 코드만 작성한다. 빌드/테스트/배포 명령은 자동 실행하지 않는다 (사용자가 결정).
- 컨벤션이 명확치 않은 영역은 사용자에게 질문하거나 `❓ Verify Manually`로 표시.
- 모바일(lane4-app-*) 프로젝트에서는 발동하지 않는다.

## 참조 문서

| 문서 | 언제 읽는가 |
|------|----------|
| `references/backend-conventions.md` | cwd가 backend일 때 Step 1~4 전반 |
| `references/frontend-conventions.md` | cwd가 frontend일 때 Step 1~4 전반 |
| `references/edge-case-checklist.md` | Step 3 edge case 점검 |
| `references/question-templates.md` | Step 2 Q&A 발사 시 |
