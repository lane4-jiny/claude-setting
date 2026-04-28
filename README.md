# claude-setting

Claude Code 개인 설정 — `settings.json`, custom skills, agents, scripts(hooks/impact 도구)를 git으로 관리하고 여러 머신 간 동기화한다.

## 디렉토리

```
.
├── settings.json           # ~/.claude/settings.json (hooks, permissions, plugins, statusLine)
├── skills/                 # ~/.claude/skills/ (lane4-* + 워크플로우 스킬 28개)
├── agents/                 # ~/.claude/agents/ (NestJS/React 4개)
├── scripts/
│   ├── hooks/              # 6개 hook 스크립트 (stop-bell, lint, typecheck, bash-log, session-start, pre-compact)
│   └── impact/             # 7개 impact-analysis 검색 도구 + lib/repos.sh
├── install.sh              # ~/.claude/ 심링크 설치
├── .gitignore
└── README.md
```

## 설치 (새 머신에서)

```bash
git clone https://github.com/lane4-jiny/claude-setting.git
cd claude-setting
./install.sh             # 드라이런 (변경 없이 확인만)
./install.sh --apply     # 실제 적용 (기존 ~/.claude/<x>는 .bak 으로 백업 후 심링크)
```

`install.sh --apply`가 하는 일:
- `~/.claude/settings.json`, `~/.claude/skills`, `~/.claude/agents`, `~/.claude/scripts` 를 이 repo로 심링크
- 기존 파일/디렉토리는 `<원래경로>.bak.<timestamp>` 로 백업
- `~/.claude/ntfy-topic`이 없으면 신규 랜덤 토픽 생성 (모바일 알림 옵트인)

## 동기화 워크플로우

심링크 방식이라 **양쪽 어디서 편집하든 동시 반영**:

- `~/.claude/skills/foo/SKILL.md` 편집 = 이 repo의 `skills/foo/SKILL.md` 편집
- `git status`가 변경 감지

```bash
cd claude-setting
git status               # 변경 확인
git diff
git add -A && git commit -m "..."
git push
```

다른 머신에서:
```bash
cd claude-setting
git pull                 # 자동으로 ~/.claude/ 에도 반영됨 (심링크 덕분)
```

## 포함된 주요 컴포넌트

### Hooks (`scripts/hooks/`)

| Hook | 이벤트 | 동작 |
|------|------|------|
| `stop-bell.sh` | Stop | 마지막 응답 180자 요약을 macOS 노티 + 사운드 + ntfy.sh 푸시로 발송 |
| `bash-log.sh` | PreToolUse(Bash) | 모든 bash 명령어를 `~/.claude/bash-log.txt`에 기록 |
| `lint-on-edit.sh` | PostToolUse(Write\|Edit) | 변경된 TS/TSX 파일에 eslint --fix 자동 실행 |
| `typecheck-on-stop.sh` | Stop | 변경된 lane4-* 프로젝트에 tsc --noEmit (spec 제외) |
| `session-start.sh` | SessionStart | git 컨텍스트(브랜치/최근 커밋/dirty 파일) 자동 주입 |
| `pre-compact.sh` | PreCompact | compaction 전 보존 우선순위 리마인더 주입 |

### Impact Analysis (`scripts/impact/`)

| 도구 | 용도 |
|------|------|
| `find-callers.sh` | 임의 심볼/문자열을 모든 lane4-* repo 가로질러 검색 |
| `find-lib-consumers.sh` | `@lane4company/lane4-backend-library` export consumer 추적 |
| `find-api-consumers.sh` | API path 문자열을 FE/Mobile에서 검색 |
| `find-kafka-refs.sh` | Kafka 토픽 producer + consumer 양방향 검색 |
| `find-mybatis-refs.sh` | MyBatis XML mapper raw SQL 검색 |
| `find-cache-refs.sh` | Redis 캐시 키 사이트 검색 |
| `lib/repos.sh` | lane4-* 프로젝트 목록 + rg 공통 옵션 (sourced) |

### Skills (`skills/`)

총 28개 — 주요 카테고리:
- **lane4 데이터 소스**: lane4-mysql, lane4-redis, lane4-es, lane4-firebase, data-compare
- **워크플로우**: deploy, incident, handover, daily-report, work-report, git-committer
- **개발/리뷰**: lane4-feature-dev, code-review, nestjs-backend-refactoring, react-frontend-refactoring, impact-analysis
- **문서**: lane4-docs, api-docs
- **메타**: brainstorming, writing-plans, executing-plans, requesting-code-review, etc.

### Agents (`agents/`)

- nestjs-backend-developer
- react-designer-publisher
- react-native-developer
- react-web-developer

## 보안 / 커밋 안 되는 것

`.gitignore`로 제외됨 (각 머신 로컬에만 존재):
- `ntfy-topic` — 모바일 알림 토픽 (공개 시 메시지 수신 가능)
- `typecheck-last.log`, `bash-log.txt` — 로그
- `*.bak.*` — install.sh 백업

추가로 `~/.claude/`의 다음 항목은 **이 repo에 절대 포함 안 됨**:
- `projects/` (전체 세션 transcript), `history.jsonl`, `sessions/`, `paste-cache/`, `file-history/` 등 모든 런타임 데이터
- `plugins/` (재설치 가능)

## 머신별 설정

`settings.json` 자체는 모든 머신 공통. 머신별로 달라지는 건:
- `~/.claude/ntfy-topic` (각 머신마다 install.sh가 생성)
- `~/IdeaProjects/lane4-*` 프로젝트 체크아웃 (회사 머신만 — `scripts/impact/lib/repos.sh`의 `LANE4_ROOT` 환경변수로 override 가능)
- `~/.claude/bash-log.txt` 등 로그 (각 머신 로컬)

## 의존성

- **rg (ripgrep)** — `scripts/impact/*.sh`가 사용
- **jq** — hook 스크립트들이 JSON 파싱에 사용
- **eslint** (각 lane4-* 프로젝트의 node_modules에) — `lint-on-edit.sh` 사용
- **tsc** (각 프로젝트의 node_modules에) — `typecheck-on-stop.sh` 사용
- **gtimeout** (선택, `brew install coreutils`) — typecheck/lint 타임아웃 안전장치
- **afplay**, **osascript** (macOS 기본) — `stop-bell.sh` 알림

## Hooks 비활성화

특정 hook이 거슬리면 `settings.json`의 해당 entry를 제거하거나 `/hooks` UI에서 토글.

## 참고

- 이 setup은 macOS + zsh 환경 기준
- Lane4 lane4-* 프로젝트가 `~/IdeaProjects` 아래에 체크아웃되어 있다고 가정
