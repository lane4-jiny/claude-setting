# LANE4 Claude Code Skills

LANE4 운영에 특화된 Claude Code 커스텀 스킬 모음.

## 스킬 목록

| 스킬 | 호출 | 설명 |
|------|------|------|
| **code-review** | `/code-review` | git diff 기반 코드 리뷰. NestJS 패턴 위반, 보안 취약점, 컨벤션 위반을 심각도별로 피드백 |
| **deploy** | `/deploy` | 배포 전 사이드이펙트 체크. 코드 diff + DB 스키마 + 외부 연동 변경사항 종합 분석 |
| **git-committer** | `/git-committer` | 변경점 분석 후 한국어 커밋 메시지 생성 및 최소 작업 단위로 분할 커밋 |
| **issue** | `/issue` | 이슈 발생 시 관련 로직 조회 및 수정/해결 방안 제안 |
| **lane4-mysql** | `/lane4-mysql` | 자연어 → SQL 변환 및 실행. 배차, 기사, 차량, 법인, 요금 등 LANE4 비즈니스 데이터 조회 |
| **lane4-redis** | `/lane4-redis` | Redis 캐시 자연어 조회. 대시보드, 요금, 좌표, 매출 등 캐시 데이터 조회·분석 |
| **lane4-es** | `/lane4-es` | Elasticsearch 자연어 쿼리. 실시간 위치, 경로, 기사/배차 상태 등 시계열 데이터 조회 |
| **lane4-firebase** | `/lane4-firebase` | Firebase RTDB 읽기 전용 조회. 점검 모드, 앱 버전, 콜/운행 상태 확인 |
| **data-compare** | `/data-compare` | MySQL/Redis/ES/Firebase 크로스 소스 정합성 비교·진단. 데이터 불일치 원인 분석 |
| **log-search** | `/log-search` | DB(HTTP_LOG)와 Elasticsearch 양쪽에서 로그 검색 및 분석 |
| **api-docs** | `/api-docs` | NestJS 컨트롤러/DTO 분석하여 API 문서 마크다운 자동 생성 |
| **handover** | `/handover` | git log + diff + 코드 분석으로 작업 인수인계서 작성 |
| **incident** | `/incident` | 장애 대응 플로우. 로그 검색 → 원인 분석 → 영향 범위 → 대응/롤백 가이드 |
| **work-report** | `/work-report` | git log 기반 기간별 작업 리포트 생성 (일일/주간/커스텀) |

## 설치

```bash
git clone https://github.com/lane4-jiny/claude-lane4-skills.git ~/.claude/skills
```

## 업데이트

```bash
cd ~/.claude/skills && git pull
```
