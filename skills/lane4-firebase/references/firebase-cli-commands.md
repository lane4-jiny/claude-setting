# Firebase CLI 명령어 레퍼런스

> 이 문서는 Firebase CLI 명령어의 전체 레퍼런스와 시나리오별 예제를 정리한다.
> CLI 명령어를 구성할 때 이 문서를 참조한다.

---

## 목차

1. [기본 명령어 형식](#1-기본-명령어-형식)
2. [도구 매핑표](#2-도구-매핑표)
3. [도구 선택 기준](#3-도구-선택-기준)
4. [시나리오별 명령어](#4-시나리오별-명령어)
5. [환경별 주의사항](#5-환경별-주의사항)
6. [쓰기 명령 가이드](#6-쓰기-명령-가이드)

---

## 1. 기본 명령어 형식

```bash
firebase --project {projectId} {command} {path} [options]
```

| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `{projectId}` | Firebase 프로젝트 ID | `lane4-driver-c8064`, `lane4-user-5993e` |
| `{command}` | CLI 명령어 | `database:get`, `database:set` 등 |
| `{path}` | RTDB 경로 | `/real/common/maintenance` |
| `[options]` | 추가 옵션 | `--shallow`, `--data '...'` |

---

## 2. 도구 매핑표

| 명령어 | 용도 | 쓰기 | 사용 시점 |
|--------|------|------|----------|
| `database:get {path}` | RTDB 데이터 읽기 | ❌ | 대부분의 조회 (기본 도구) |
| `database:get {path} --shallow` | 하위 키 목록만 조회 | ❌ | 구조 파악, 키 탐색, 대량 데이터 방지 |
| `database:set {path} --data {value}` | 특정 경로에 값 설정 | ⚠️ | 버전/점검 모드 단일 값 변경 |
| `database:update {path} --data {json}` | 기존 데이터에 병합 | ⚠️ | 여러 필드 동시 변경 |
| `database:remove {path}` | 경로 데이터 삭제 | ⚠️ | 만료된 콜/배차 데이터 정리 |
| `apps:list` | 등록된 앱 목록 | ❌ | 앱 정보 확인 |
| `hosting:sites:list` | 호스팅 사이트 목록 | ❌ | 호스팅 상태 확인 |
| `projects:list` | 프로젝트 목록 | ❌ | 프로젝트 구조 파악 |

---

## 3. 도구 선택 기준

```
단순 값 조회 (점검 상태, 버전, 특정 유저/기사)
  → database:get

키 목록/구조 파악 (어떤 데이터가 있는지 탐색)
  → database:get --shallow

특정 경로 단일 값 변경 (점검 모드 on/off, 단일 버전 업데이트)
  → database:set  ⚠️ 사용자 확인 필수

여러 필드 동시 변경 (여러 버전을 한번에 업데이트)
  → database:update  ⚠️ 사용자 확인 필수

데이터 정리/삭제 (만료된 콜 플래그 제거)
  → database:remove  ⚠️ 사용자 확인 필수
```

---

## 4. 시나리오별 명령어

### 4.1 점검 모드 (maintenance)

**확인** (Driver + User 양쪽):
```bash
firebase --project lane4-driver-c8064 database:get /real/common/maintenance
firebase --project lane4-user-5993e database:get /real/common/maintenance
```

**활성화** ⚠️ (Driver + User 양쪽 수행):
```bash
firebase --project lane4-driver-c8064 database:set /real/common/maintenance/active --data true
firebase --project lane4-user-5993e database:set /real/common/maintenance/active --data true
```

**비활성화** ⚠️ (Driver + User 양쪽 수행):
```bash
firebase --project lane4-driver-c8064 database:set /real/common/maintenance/active --data false
firebase --project lane4-user-5993e database:set /real/common/maintenance/active --data false
```

> 점검 모드 변경 시 반드시 Driver + User 양쪽 모두 수행해야 한다.
> 한쪽만 변경하면 기사앱/고객앱 동작이 불일치한다.

### 4.2 앱 버전 (version)

**전체 버전 정보 조회:**
```bash
# Driver (android만)
firebase --project lane4-driver-c8064 database:get /real/common/maintenance/version

# User (android + ios)
firebase --project lane4-user-5993e database:get /real/common/maintenance/version
```

**특정 플랫폼 버전 조회:**
```bash
# Driver android
firebase --project lane4-driver-c8064 database:get /real/common/maintenance/version/android

# User iOS
firebase --project lane4-user-5993e database:get /real/common/maintenance/version/ios
```

**버전 업데이트** ⚠️:
```bash
# current 버전 변경
firebase --project lane4-driver-c8064 database:set /real/common/maintenance/version/android/current --data '"3.5.0"'

# minimum 버전 변경 (강제 업데이트 임계값)
firebase --project lane4-driver-c8064 database:set /real/common/maintenance/version/android/minimum --data '"3.0.0"'

# CodePush 버전 변경
firebase --project lane4-driver-c8064 database:set /real/common/maintenance/version/android/codepush --data '"v60"'

# User iOS CodePush 변경
firebase --project lane4-user-5993e database:set /real/common/maintenance/version/ios/codepush --data '"v252"'
```

> 문자열 값은 반드시 `'"값"'` 형태로 감싼다 (외부 작은따옴표 + 내부 큰따옴표).

### 4.3 콜 상태 (calling)

**특정 유저 콜 상태 조회:**
```bash
# Driver 프로젝트에서 조회
firebase --project lane4-driver-c8064 database:get /real/calling/user_{userId}

# User 프로젝트에서 조회
firebase --project lane4-user-5993e database:get /real/calling/user_{userId}
```

**현재 콜 진행 중인 유저 목록 (키만):**
```bash
firebase --project lane4-driver-c8064 database:get /real/calling --shallow
firebase --project lane4-user-5993e database:get /real/calling --shallow
```

**특정 콜 데이터 삭제** ⚠️:
```bash
firebase --project lane4-driver-c8064 database:remove /real/calling/user_{userId}/allocId_{allocId}
```

### 4.4 운행 상태 (driving) — Driver 프로젝트만

**특정 기사 운행 상태 조회:**
```bash
firebase --project lane4-driver-c8064 database:get /real/driving/driver_{driverId}
```

**현재 운행 중인 기사 목록 (키만):**
```bash
firebase --project lane4-driver-c8064 database:get /real/driving --shallow
```

**특정 기사 배차 데이터 삭제** ⚠️:
```bash
firebase --project lane4-driver-c8064 database:remove /real/driving/driver_{driverId}
```

### 4.5 범용 RTDB 조회

**환경 전체 키 구조 확인:**
```bash
firebase --project lane4-driver-c8064 database:get /real --shallow
firebase --project lane4-user-5993e database:get /real --shallow
```

**임의 경로 조회:**
```bash
firebase --project {projectId} database:get /{env}/{path}
```

### 4.6 프로젝트/앱 정보

```bash
# 프로젝트 목록
firebase projects:list

# Driver 프로젝트 앱 목록
firebase --project lane4-driver-c8064 apps:list

# User 프로젝트 앱 목록
firebase --project lane4-user-5993e apps:list
```

---

## 5. 환경별 주의사항

| 환경 | 경로 prefix | 쓰기 정책 |
|------|------------|----------|
| `dev` | `/dev/...` | 경고 후 수행 가능 |
| `real` | `/real/...` | 반드시 사용자 명시적 확인 후 수행 |

- 사용자가 환경을 지정하지 않으면 **real**이 기본값이다.
- "개발", "dev", "테스트" 등을 언급하면 dev 환경을 사용한다.
- dev 환경 데이터도 실제 테스트에 사용될 수 있으므로 삭제 시 주의한다.

---

## 6. 쓰기 명령 가이드

### 쓰기 전 체크리스트

1. **사용자가 명시적으로 요청했는가?** → 아니면 읽기만 수행
2. **환경이 real인가?** → 사용자에게 재확인 요청
3. **양쪽 프로젝트에 동시 수행해야 하는가?** → 점검 모드는 반드시 양쪽
4. **값 형식이 올바른가?** → 문자열은 `'"값"'`, boolean은 `true`/`false`, 숫자는 그대로

### 양쪽 동시 수행이 필요한 작업

| 작업 | Driver | User | 이유 |
|------|--------|------|------|
| 점검 모드 활성/비활성 | ✅ | ✅ | 기사앱+고객앱 동시에 점검 상태 반영 |
| 기타 버전/콜/운행 | 해당 프로젝트만 | 해당 프로젝트만 | 프로젝트별 독립 데이터 |

### 데이터 타입별 --data 형식

```bash
# 문자열 (반드시 이중 따옴표)
--data '"3.5.0"'
--data '"v60"'

# boolean
--data true
--data false

# 숫자
--data 12345

# JSON 객체
--data '{"codepush":"v60","current":"3.5.0"}'
```
