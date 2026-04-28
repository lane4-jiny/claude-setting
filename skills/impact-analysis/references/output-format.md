# Impact Analysis 결과 출력 템플릿

모든 finding은 `file:line` 인용을 포함한다. 도구 출력에 없는 사실을 추가하지 않는다.

## 표준 형식

```markdown
# 영향 분석 결과

**분석 범위**: <git diff range 또는 사용자 명시 범위>
**분석 시각**: <YYYY-MM-DD HH:MM>
**변경 항목 수**: N (HIGH M / MED M / LOW M / VERIFY M)

---

## 🔴 HIGH (즉시 깨짐 가능, 배포 전 해결 필수)

### [HIGH-1] <변경 요약 한 줄>
**변경 위치**: `<repo>/<path>:<line>` <code snippet>
**변경 유형**: <signature change / enum value removal / route deletion / topic rename / column drop / cache key change>

**영향받는 consumer (X건)**:
- `<repo>/<path>:<line>` — `<context line>`
- `<repo>/<path>:<line>` — `<context line>`
- ...

**도구 출력**:
\`\`\`
<원본 도구 출력 발췌>
\`\`\`

**대응 권장**:
- <구체적 액션>

---

## 🟡 MED (배포 순서 또는 동시 변경 필요)

### [MED-1] <변경 요약>
**변경 위치**: ...
**영향받는 consumer (X건)**:
- ...

---

## 🟢 LOW (additive, 깨짐 없음)

### [LOW-1] <변경 요약>
**변경 위치**: ...
**Consumer**: 0건 (또는 신규 endpoint 추가만)

---

## ❓ Verify Manually (도구 한계로 자동 검출 불가)

다음 영역은 정적 분석으로 잡히지 않으므로 변경 영향이 있는지 수동으로 확인 필요:

- [ ] **MyBatis XML mappers** (`lane4-admin-api/src/lib/mapper/*.xml`): 변경된 컬럼/테이블이 raw SQL에 있는지
- [ ] **lane4-driver-api 듀얼 Redis** (`commons/redis` + `commons/newRedis` + `commons/cache`): 모두 점검했는가
- [ ] **동적 enum 접근**: `Enum[varName]` 패턴이 있다면 enum 이름 자체로도 검색
- [ ] **모바일 dual base URL**: `Config.API_URL` 사용처도 영향받는가
- [ ] **CodePush 핫업데이트 동시 진행**: 백엔드 변경이 모바일 JS 변경 동반 필요한가
- [ ] **로컬 enum 중복**: `src/commons/enum/e.*.type.ts` 같은 로컬 사본 동기화
- [ ] **Firebase RTDB 경로**: `.env`의 `FIREBASE_*_PATH` 변경 시 양쪽 driver-api + admin-api 동시 변경

---

## 요약 표

| 변경 항목 | 위험도 | Consumer | 영향 프로젝트 |
|---------|------|----------|------------|
| <변경 1> | 🔴 HIGH | 17 | lane4-driver-api, lane4-admin-api, ... |
| <변경 2> | 🟡 MED | 3 | lane4-monitoring-api |
| <변경 3> | 🟢 LOW | 0 | — |
```

## 배포 키워드로 발동된 경우

마지막 줄에 다음을 추가:

```markdown
---

**배포 진행 가이드**:
- 🔴 HIGH 항목이 있으면 배포 전 해결 필수
- 🟡 MED는 배포 순서 또는 모바일 핫업데이트 동시 진행 검토
- ❓ VERIFY는 수동 점검 후 안전 확인

이 분석 결과를 검토한 뒤 `deploy` 스킬을 호출하여 단일 프로젝트 배포 체크리스트를 받으세요.
```

## 변경 분류별 출력 가이드

### 1) 공유 라이브러리 export 변경
```
**변경 유형**: lane4-backend-library export 변경
**Export**: <name>
**도구**: find-lib-consumers.sh <name>
```

### 2) Controller route 변경
```
**변경 유형**: API route <added | renamed | removed>
**Path**: /api/<route>
**도구**: find-api-consumers.sh <route> + find-callers.sh <route> --type ts
```

### 3) Kafka 토픽 변경
```
**변경 유형**: Kafka topic <added | renamed | removed>
**Topic**: <topic-name>
**도구**: find-kafka-refs.sh <topic-name>
**주의**: producer + consumer 양방향 매칭 확인
```

### 4) Entity 컬럼 변경
```
**변경 유형**: TypeORM 엔티티 컬럼 <added | renamed | removed | retyped>
**Entity.column**: <Entity>.<column>
**도구**: find-callers.sh <Entity> + find-mybatis-refs.sh <COLUMN_NAME> + find-cache-refs.sh <table>
**주의**: MyBatis raw SQL 별도 점검 (TypeORM 분석으로 안 잡힘)
```

### 5) 일반 함수/메서드 변경
```
**변경 유형**: 함수/메서드 시그니처 변경
**Symbol**: <ClassName>.<methodName> 또는 <functionName>
**도구**: find-callers.sh "<symbol>" --type ts --exclude <self-repo>
```

## 출력 길이 가이드

- HIGH 항목당 evidence는 최대 10건까지 본문에 표시. 그 이상은 `(외 N건)` 처리.
- 도구 출력 원문은 최대 20줄. 잘랐으면 "(잘림 — 전체 X건)" 명시.
- 0건 결과도 명시적으로 보고 ("Consumer 0건").
