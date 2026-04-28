---
name: impact-analysis
description: Lane4 코드 변경의 사이드이펙트를 코드 기반(추측 X)으로 분석한다. 변경된 심볼/엔드포인트/Kafka 토픽/엔티티 컬럼을 추출하여 모든 lane4-* 프로젝트(백엔드 API 11개, 프론트엔드 3개, 모바일 2개, 공통 라이브러리 2개)를 가로질러 영향받는 file:line을 찾고 위험도를 분류한다. 사용자가 "사이드이펙트", "영향 분석", "영향도", "영향 범위", "어디서 사용", "어디서 쓰지", "호출처", "consumer", "callers", "어떤 프로젝트가 영향" 등을 언급하면 사용한다. **배포 키워드("배포", "deploy", "운영 배포", "배포해줘", "배포 전 확인") 발생 시 다른 어떤 작업보다 먼저 무조건 이 스킬을 발동시켜 영향을 분석한 뒤 결과를 보고한다.** MyBatis XML, Kafka 토픽 문자열, 모바일 inline path, 두 개의 Redis 인스턴스 등 정적 분석에서 놓치기 쉬운 lane4 특유의 edge case를 명시적으로 점검한다.
---

# Impact Analysis

Lane4 코드베이스 변경의 사이드이펙트를 **코드 기반 증거**로 분석한다. LLM의 추측 없이, 결정적 도구(`~/.claude/scripts/impact/*.sh`)가 생성한 `file:line` evidence만 가지고 위험도를 분류한다.

## 핵심 원칙

1. **Evidence-only**: 모든 결과는 도구가 반환한 `file:line:context`에서 온다. 도구 출력에 없는 사실은 보고하지 않는다.
2. **Edge case 명시**: 도구가 놓칠 수 있는 영역(MyBatis XML, 동적 문자열, reflection)은 별도 "verify-manually" 섹션에 표시.
3. **0건도 결과**: 도구가 0건을 반환하면 그대로 보고. "아마 어딘가에서 쓸 것"이라고 추측 금지.

## 트리거

### 자동 발동 키워드
다음 키워드가 사용자 메시지에 등장하면 무조건 이 스킬을 우선 실행한다:
- 사이드이펙트, 영향 분석, 영향도, 영향 범위
- 어디서 사용, 어디서 쓰지, 호출처, consumer, callers
- 어떤 프로젝트가 영향

### 강제 발동 — 배포 키워드 ⚠️
다음 키워드가 등장하면 **다른 어떤 작업도 시작하기 전에** 이 스킬을 발동하여 영향을 분석한 뒤 결과를 사용자에게 보고한다. 영향 분석 결과 없이 배포 진행을 안내하지 않는다.
- 배포, deploy, 운영 배포, 배포해줘, 배포 전 확인, 배포 체크

`deploy` 스킬과의 관계: `deploy`는 단일 프로젝트의 git diff/.env/DB 스키마 체크리스트를 만든다. `impact-analysis`는 **변경이 다른 프로젝트로 어떻게 파급되는지**를 분석한다. 배포 키워드 시 둘 다 실행해야 하면 `impact-analysis`를 먼저 실행하고, 그 결과를 `deploy` 체크리스트에 첨부한다.

## 도구

`~/.claude/scripts/impact/`에 설치된 결정적 검색 도구들:

| 도구 | 용도 | 입력 |
|------|------|------|
| `find-callers.sh` | 임의 심볼/문자열의 호출처를 모든 lane4-* 가로질러 검색 | 패턴, `--type ts\|xml`, `--exclude <repo>`, `--word` |
| `find-lib-consumers.sh` | `@lane4company/lane4-backend-library`의 특정 export 사용처 | export 이름 |
| `find-api-consumers.sh` | API path 문자열을 FE/Mobile에서 검색 | path (예: `auth/login`) |
| `find-kafka-refs.sh` | Kafka 토픽의 producer + consumer | 토픽명 |
| `find-mybatis-refs.sh` | MyBatis XML mapper에서 컬럼/테이블 SQL 참조 | 컬럼/테이블명 |
| `find-cache-refs.sh` | Redis 캐시 키 사이트에서 패턴 검색 | 패턴 |

**MUST**: 도구의 출력은 `path:line:content` 또는 `path-line-context` 형식이다. 보고서의 모든 evidence는 이 출력에서 직접 인용한다.

## 워크플로우

### Step 1: 변경 범위 결정
사용자가 명시한 범위를 우선 사용. 미명시 시:
- git 저장소 안: `git diff HEAD` (또는 사용자 확인 후 `HEAD~1..HEAD`, `dev..main` 등)
- 워크스페이스 루트(`~/IdeaProjects`)나 git 외부: 사용자에게 분석 대상 파일/심볼/엔드포인트를 물어 확정

### Step 2: 변경 분류 (각 변경에 대해)

| 변경 패턴 | 호출 도구 | 입력 |
|----------|---------|-----|
| `lane4-backend-library/src/index.ts` 또는 `src/**/*.ts`의 export 변경 | `find-lib-consumers.sh` | 변경된 export 이름 |
| `*.controller.ts`의 `@Get/@Post/...` route 변경 | `find-api-consumers.sh` | 라우트 path (글로벌 `/api` prefix 제외) |
| `@MessagePattern('...')` (lane4-allocation-api) | `find-callers.sh` | 메시지 패턴 문자열 |
| `*Producer.ts`의 `kafka.emit('...')` 또는 `*Consumer.ts`의 `subscribe({ topic: ... })` | `find-kafka-refs.sh` | 토픽명 |
| `src/entities/*.ts`의 컬럼 추가/제거/타입 변경 | `find-mybatis-refs.sh` (테이블/컬럼) + `find-cache-refs.sh` (테이블명) | 컬럼/테이블 |
| `src/commons/redis/*.ts`의 키 패턴 변경 | `find-callers.sh` | 키 prefix (예: `{driver}:history`) |
| 일반 함수/메서드/클래스 시그니처 변경 | `find-callers.sh --word --exclude <self-repo>` | 심볼명 |

### Step 3: 병렬 실행
변경이 여럿이면 subagent로 분산하여 동시 실행. 각 subagent는 한 변경을 담당하고 도구 출력 + 분류만 반환한다.

### Step 4: 위험도 분류

| 등급 | 기준 |
|-----|-----|
| 🔴 HIGH | (a) consumer ≥ 5 + signature/semantics 변경, (b) 공유 enum 값 제거, (c) 운영 배포 시 즉시 깨질 가능성 |
| 🟡 MED | (a) consumer 1-4, (b) breaking 가능성 있으나 우회 가능, (c) 마이그레이션 순서 의존 |
| 🟢 LOW | (a) consumer 0, (b) additive only (신규 enum 값 추가, 새 endpoint 추가), (c) deprecation 표시만 |
| ❓ VERIFY | 도구가 놓칠 수 있는 영역 (동적 문자열, reflection, 외부 시스템) |

### Step 5: 출력
`references/output-format.md`의 템플릿을 따른다.

## Lane4-특화 Edge Cases (도구가 놓치는 것)

이 항목들은 `find-callers.sh` 등으로 잡히지 않는다. 분석 결과의 **"❓ Verify Manually"** 섹션에 항상 명시한다.

1. **MyBatis XML mappers** — `lane4-admin-api/src/lib/mapper/*.xml`에 raw SQL 존재. 엔티티 컬럼 변경 시 `find-mybatis-refs.sh` 별도 실행 필수.
2. **lane4-driver-api 두 개 Redis 인스턴스** — `commons/redis/`(legacy ioredis) + `commons/newRedis/`(new) + `commons/cache/`(cache-manager). 캐시 키 변경 시 모두 점검.
3. **lane4-allocation-api는 Redis microservice** — HTTP가 아닌 `@MessagePattern('...')`. 컨트롤러 변경 시 일반 API consumer 검색이 무의미.
4. **모바일 두 개 base URL** — `API_URL` (legacy) + `API_V2_URL`. 파일 업로드는 legacy 사용. base URL 분기 변경 시 `find-callers.sh "Config.API_URL"` 별도 실행.
5. **CodePush 핫업데이트** — JS 변경은 앱스토어 리뷰 없이 즉시 반영. 백엔드 배포 후 모바일 핫업데이트 누락 시 사용자 깨짐. `appVerNo`/`codePushNo` 관련 코드 (`driver/app-version` PATCH) 변경 주의.
6. **Kafka vs RabbitMQ 분리** — 알림(notification)은 RabbitMQ (`NOTIFICATION_MQ_URL`), 나머지는 Kafka. 메시지 추적 시 두 system 분리.
7. **동적 enum 접근** — `EvaluateScore[dto.evalDetail]` 같은 bracket notation. `find-callers.sh`로 enum 멤버명 검색 시 매치 안 됨. enum 변경 시 enum 자체 이름으로도 검색.
8. **shared entity at lane4-driver-api/src/entities/** — 다른 백엔드들이 이 디렉토리를 import하는 패턴이 있을 수 있음. 엔티티 변경 시 `find-callers.sh` with entity class name 권장.
9. **로컬 enum 중복** — 공유 enum이 `lane4-backend-library`에 있어도 `lane4-admin-api/src/commons/enum/e.*.type.ts`처럼 로컬 중복이 존재. 공유 enum 변경 시 로컬 중복본도 grep.
10. **하드코딩 Firebase 경로** — `.env`의 `FIREBASE_DRIVER_PATH=real/driving/`, `FIREBASE_USER_PATH=real/calling/`. RTDB 스키마 변경 시 .env + 코드 양쪽 검사.

## 입력 받기

사용자가 분석 대상을 명시하지 않은 경우 다음 우선순위로 결정:

1. 사용자 메시지에 `git diff` 컨텍스트가 있으면 그 범위 사용
2. 현재 git 저장소가 있으면: `git -C <cwd> diff HEAD --name-only` 실행 후 변경 파일 출력하고 사용자에게 "이 범위로 분석할까요?" 확인
3. 명시되지 않으면 사용자에게 다음 중 하나 요청:
   - 변경된 파일 경로
   - 변경된 심볼/메서드 이름
   - 변경된 API path
   - 변경된 Kafka 토픽
   - 변경된 엔티티/컬럼

## 출력

분석이 끝나면 `references/output-format.md`에 정의된 형식으로 결과를 출력한다. 모든 finding은 `file:line` 인용을 포함해야 한다.

배포 키워드로 발동된 경우, 출력 끝에 다음 한 줄을 추가:
> **배포 진행 가이드**: 위 🔴 HIGH 항목이 있으면 배포 전 해결, 🟡 MED는 배포 순서 또는 모바일 핫업데이트 동시 진행 검토, ❓ VERIFY는 수동 점검 필수.

## 참조 문서

| 문서 | 용도 |
|------|------|
| `references/lane4-context.md` | Lane4 코드베이스 구조/패턴/import idiom 사실표 (분석 시 참조) |
| `references/output-format.md` | 결과 출력 템플릿 |

## 제약

- 코드를 수정하지 않는다.
- 실제 배포를 수행하지 않는다.
- DB/Redis/ES/Firebase 데이터 조회가 필요하면 `lane4-mysql`, `lane4-redis`, `lane4-es`, `lane4-firebase` 스킬에 위임.
- 도구 출력에 없는 사실을 보고하지 않는다.
