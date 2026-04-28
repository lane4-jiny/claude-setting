---
name: lane4-firebase
description: >
  Lane4 Firebase 프로젝트(Driver/User) Realtime Database 조회 전용 스킬.
  Firebase CLI(Bash)를 통해 RTDB 데이터를 읽기 전용으로 조회한다.
  앱 점검 모드(maintenance) 상태 확인, 앱 버전(current, minimum, CodePush) 정보 조회,
  실시간 배차/콜 상태 확인을 수행한다. 쓰기/수정/삭제 작업은 일체 수행하지 않는다.
  사용자가 "점검 모드", "maintenance", "앱 버전", "CodePush", "최소 버전", "강제 업데이트",
  "Firebase", "RTDB", "실시간 데이터", "콜 상태", "배차 상태", "운행 상태",
  "앱이 안 열려", "앱 접근", "푸시", "FCM" 등을 언급할 때 반드시 이 스킬을 사용한다.
  다른 lane4 스킬(lane4-issue, lane4-mysql, lane4-redis, lane4-es)에서
  Firebase 관련 데이터가 필요할 때도 이 스킬을 참조한다.
---

# lane4-firebase 스킬

Lane4 Firebase 프로젝트(Driver, User)의 Realtime Database를 Firebase CLI로 **읽기 전용** 조회하는 스킬.

## 4대 데이터 스토어에서의 역할

| 구분 | lane4-mysql | lane4-redis | lane4-es | **lane4-firebase** |
|------|-------------|-------------|----------|-------------------|
| 대상 | 마스터 데이터, 트랜잭션 | 캐시, 실시간 집계 | 위치, 시계열 로그 | **앱 상태, 실시간 콜/배차** |
| 접근 도구 | SQL (MCP) | Redis 명령 (MCP) | ES\|QL / Query DSL (MCP) | **Firebase CLI (Bash)** |
| 쓰기 정책 | SELECT만 | READ 위주 | READ-ONLY | **READ-ONLY (쓰기 절대 금지)** |

## 프로젝트 요약

| 프로젝트 | Project ID | 용도 |
|---------|------------|------|
| Driver | `lane4-driver-c8064` | 기사 앱 (calling, driving, common) |
| User | `lane4-user-5993e` | 고객 앱 (calling, common) |

환경은 RTDB 경로 prefix로 분리: `/{env}/` → `dev` 또는 `real`

## 카테고리 분류

| 카테고리 | 트리거 키워드 | 기본 프로젝트 |
|---------|-------------|-------------|
| **점검 모드** | maintenance, 점검, 서버 점검 | Driver + User 둘 다 |
| **앱 버전** | version, 버전, CodePush, 최소 버전, 강제 업데이트 | 맥락에 따라 선택 |
| **콜 상태** | calling, 콜, 호출, 배차 요청 | Driver (기사), User (고객) |
| **운행 상태** | driving, 운행, 기사 상태, 배차 상태 | Driver만 |
| **RTDB 범용** | firebase, rtdb, 실시간 | 맥락에 따라 선택 |
| **코드 추적** | 코드, 구현, 로직, FCM | 참조 문서 안내 |

## 워크플로우

```
1. 도메인 파악
   → 사용자 질문에서 카테고리 분류 (점검/버전/콜/운행/범용/코드)

2. 프로젝트 선택
   → "기사" → Driver (lane4-driver-c8064)
   → "고객/유저" → User (lane4-user-5993e)
   → "점검 모드" → 둘 다
   → 불분명 → 사용자에게 확인

3. 환경 선택
   → 기본: real (사용자가 "dev"를 명시하지 않는 한)

4. RTDB 경로 결정
   → references/firebase-project-map.md 참조

5. CLI 명령어 선택
   → references/firebase-cli-commands.md 참조
   → 허용 명령어: database:get, apps:list, projects:list만 사용

6. Firebase CLI 실행
   → firebase --project {projectId} database:get {path} [--shallow]

7. 결과 해석 및 요약
   → JSON 응답을 사용자 친화적으로 해석
   → 다른 스킬 연계 필요 시 안내 (allocId → lane4-mysql 등)
```

## 허용 명령어 (화이트리스트)

| 명령어 | 용도 |
|--------|------|
| `database:get {path}` | RTDB 데이터 읽기 |
| `database:get {path} --shallow` | 하위 키 목록만 조회 |
| `apps:list` | 등록된 앱 목록 |
| `projects:list` | 프로젝트 목록 |

**도구 선택 기준:**
- 단순 값 조회 (점검 상태, 버전) → `database:get`
- 키 목록 / 구조 파악 → `database:get --shallow`

## 금지 명령어 (절대 실행 금지)

아래 명령어는 **어떤 상황에서도, 사용자가 요청하더라도** 실행하지 않는다:

| 금지 명령어 | 이유 |
|------------|------|
| `database:set` | 데이터 덮어쓰기 — 쓰기 금지 |
| `database:update` | 데이터 병합/수정 — 쓰기 금지 |
| `database:remove` | 데이터 삭제 — 쓰기 금지 |
| `database:push` | 데이터 추가 — 쓰기 금지 |
| `deploy` | 배포 — 쓰기 금지 |
| `hosting:disable` | 호스팅 비활성화 — 쓰기 금지 |

사용자가 쓰기/수정/삭제를 요청하면 **Firebase Console에서 직접 수행하도록 안내**한다.
해당 경로와 변경할 값을 알려주되, CLI 명령어는 실행하지 않는다.

## 안전 제약사항 (핵심 원칙)

### 1. READ-ONLY (최우선 규칙)
- 이 스킬은 **읽기 전용**이다. `database:get`과 `--shallow` 옵션만 사용한다.
- `database:set`, `database:update`, `database:remove`, `database:push`는 **절대 실행하지 않는다**.
- 사용자가 쓰기/수정/삭제를 요청하면:
  1. 변경할 경로와 값을 텍스트로 안내한다.
  2. Firebase Console(https://console.firebase.google.com)에서 직접 수행하도록 안내한다.
  3. **CLI 쓰기 명령어는 실행하지 않는다.**

### 2. 민감 데이터
- Service Account 키, 인증 토큰은 응답에 포함하지 않는다.
- RTDB URL은 참조용으로만 사용한다.

## Firebase 고유 고려사항

- **MCP 도구 없음**: Redis/ES와 달리 Firebase CLI(Bash)를 직접 사용한다.
- **경로 기반 환경 분리**: dev/real이 DB URL이 아닌 RTDB 경로 prefix(`/{env}/`)로 분리된다.
- **데이터 규모 소형**: MySQL(수백만), ES(수억)에 비해 Firebase RTDB는 소규모로 성능 이슈 없음.
- **스냅샷 조회만 가능**: CLI로는 실시간 리스너 불가. 현재 시점 데이터만 조회.

## 스킬 간 연계

| 연계 스킬 | 시나리오 | 방향 |
|----------|---------|------|
| **lane4-issue** | "배차가 안 돼요" → RTDB calling/driving 확인 | issue → firebase |
| **lane4-issue** | "앱이 열리지 않아요" → maintenance + 버전 확인 | issue → firebase |
| **lane4-issue** | "푸시가 안 와요" → FCM 코드 추적 + RTDB 콜 상태 | issue → firebase |
| **lane4-mysql** | RTDB allocId → ALLOCATION 테이블 크로스 조회 | firebase → mysql |
| **lane4-mysql** | RTDB driverId → DRIVER 테이블 기사 상세 조회 | firebase → mysql |
| **lane4-redis** | 점검 모드 변경 시 → 대시보드 캐시 상태 확인 | firebase → redis |
| **lane4-es** | RTDB driving 상태 → ES driver 인덱스 실시간 상태 비교 | firebase → es |

연계 조회가 필요할 때 `references/cross-reference.md`를 참조하여 키 필드 매핑을 확인한다.

## 참조 문서 가이드

상세 정보가 필요할 때 아래 참조 문서를 읽는다:

| 파일 | 내용 | 언제 읽나 |
|------|------|----------|
| `references/firebase-project-map.md` | 프로젝트 구조, RTDB 스키마, 앱 목록 | RTDB 경로 결정 시, 데이터 구조 확인 시 |
| `references/firebase-cli-commands.md` | CLI 명령어 레퍼런스 + 시나리오별 예제 | CLI 명령어 구성 시, 복잡한 시나리오 처리 시 |
| `references/firebase-codebase-map.md` | 코드베이스 내 Firebase 사용처 맵 | 코드 추적/디버깅 시, 이슈 원인 분석 시 |
| `references/cross-reference.md` | MySQL/Redis/ES ↔ Firebase 연계 가이드 | 다른 스킬과 크로스 조회 시 |
