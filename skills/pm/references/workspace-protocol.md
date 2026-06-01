# 워크스페이스 프로토콜 (에이전트 간 blackboard 규약)

서브에이전트는 서로 격리돼 있어 대화를 공유하지 못한다. 모든 정보 전달은 **기능별 워크스페이스
폴더의 마크다운 파일**로 이뤄진다. PM이 폴더를 만들고, 각 에이전트가 정해진 파일을 읽고/쓴다.

## 폴더 위치 & 구조

```
~/IdeaProjects/claudedocs/features/{YYYY-MM-DD}_{기능-slug}/
├── spec.md          # PM 작성. 기획·요구사항·AC·작업분할. (단일 진실원천)
├── backend.md       # BE 에이전트 작성. 구현 결과·변경파일·빌드결과.
├── frontend.md      # FE 에이전트 작성. 구현 결과·변경파일·빌드결과.
├── qa-report.md     # QA 에이전트 작성. 4종 검증 결과·이슈 목록.
└── loop.md          # PM 작성. 루프 회차별 이슈→해결책→재작업 기록.
```

- `slug`: 영문 kebab-case, 2~4 단어 (예: `corporate-monthly-invoice`).
- 같은 기능의 후속 작업이면 새 폴더 만들지 말고 기존 폴더에 이어 쓴다.

## 파일별 규약

### spec.md (PM → 모두)
PM이 기획 대화 후 작성. 모든 에이전트가 가장 먼저 읽는 단일 진실 원천.

```markdown
# {기능명}

## 1. 배경/목적
(왜 이 기능이 필요한가 — 1~3줄)

## 2. 요구사항
- (사용자가 확정한 요구사항 불릿)

## 3. 수용 기준 (Acceptance Criteria)
- [ ] AC1: (검증 가능한 형태로. QA가 이걸로 대조)
- [ ] AC2: ...

## 4. 영향 범위 (lane4-service-map 기반 PM 판단)
- **백엔드**: {프로젝트명} — {절대경로} — {담당 작업 요약}
- **프론트**: {프로젝트명} — {절대경로} — {담당 작업 요약}
- **교차 관심사**: (이중 Redis / TaskType / Kafka / MyBatis 등 해당되는 것)

## 5. 작업 분할
### Backend ({프로젝트})
- (구체 작업 항목)
### Frontend ({프로젝트})
- (구체 작업 항목)
### API 계약 (BE↔FE 인터페이스)
- 엔드포인트: `METHOD /path`
- 요청: { ... }
- 응답: { code, data: { ... }, result }

## 6. 비범위 (YAGNI)
- (하지 않을 것 명시)
```

### backend.md / frontend.md (BE·FE 에이전트 → QA·PM)
구현 후 작성. **실제 코드 수정 + 빌드/타입체크까지 한 뒤** 결과를 기록.

```markdown
# Backend 구현 결과 — {프로젝트}

## 구현 요약
(무엇을 했는지 3~6줄)

## 변경 파일 (file:line)
- `src/domains/.../x.service.ts:120` — (한 줄 설명)
- (신규/수정/삭제 표시)

## API 계약 실제 구현
- `METHOD /path` — 실제 요청/응답 스키마 (spec과 차이 있으면 명시)

## 빌드/타입체크 결과
- 명령: `yarn build` / `yarn tsc --noEmit`
- 결과: ✅ 통과 / ❌ 실패 (실패 시 에러 발췌)

## 컨벤션 점검 (자가)
- 이중 Redis / QueryRunner / envelope / Kafka 토픽 등 해당 항목 준수 여부

## QA에게 전달할 메모
- (테스트 시 주의점, 로컬 구동법, 시드 데이터 등)

## 미해결/위험
- (있으면. 없으면 "없음")
```

### qa-report.md (QA 에이전트 → PM)
BE/FE 결과 + spec을 받아 4종 검증 수행 후 작성.

```markdown
# QA 리포트 — {기능명} (루프 {N}회차)

## 검증 방식별 결과
### 1. 자동 테스트/빌드
- {프로젝트}: `yarn build` ✅/❌, `yarn test` ✅/❌ (발췌)
### 2. 컨벤션/정적 검증
- (lane4-convention-auditor 위임 결과 요약: Block/Warn/Suggest)
### 3. 요구사항(AC) 대조
- [x] AC1 충족 / [ ] AC2 미충족 — 근거 file:line
### 4. 브라우저 E2E (프론트, 해당 시)
- (playwright 시나리오·결과. 미실행 시 사유)

## 🚨 이슈 목록 (PM에게)
1. **[심각도 Block]** {요약} — 원인 추정 file:line — 재현/근거
2. **[Warn]** ...

## 종합 판정
- ✅ PASS (이슈 없음 / Warn만) → 완료 보고
- ❌ FAIL (Block 존재) → PM 재기획 루프
```

### loop.md (PM, 루프 발생 시)
QA가 FAIL을 줄 때마다 회차별로 append.

```markdown
## 루프 {N}회차 — {timestamp}
### QA 이슈
- (qa-report에서 가져온 Block 이슈)
### PM 원인 분석 & 해결책
- 이슈1 → 원인: ... → 해결: {BE/FE} 에게 "..." 재지시
### 재디스패치 대상
- Backend / Frontend (무엇을)
```

## 루프 제어 규칙 (PM)
1. QA 판정이 ❌FAIL이면 PM이 이슈를 분석→해결책 수립→해당 에이전트 재디스패치→QA 재검증.
2. **최대 3회차**까지 자동 반복. 3회차 후에도 Block이 남으면 자동 중단하고 사용자에게
   현재 상태·남은 이슈·PM의 판단을 보고하고 지시를 기다린다.
3. 매 회차 `loop.md`에 기록을 남겨 추적 가능하게 한다.
4. Warn/Suggest만 남으면 PASS로 보고 (Block만 루프 트리거).
