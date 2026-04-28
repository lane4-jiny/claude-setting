# 프로젝트 맵

lane4-* 프로젝트 목록과 각 프로젝트의 역할/담당 도메인을 정의한다.
모든 백엔드 프로젝트는 NestJS + TypeScript + TypeORM + MySQL(Master-Slave) 기반이다.

## 백엔드 프로젝트 목록

| 프로젝트명 | 역할 | 경로 | 주요 도메인 | 도메인 수 |
|-----------|------|------|-----------|----------|
| lane4-admin-api | 뉴어드민 API | `~/IdeaProjects/lane4-admin-api` | 기사스케줄, 배차, 통계, 법인 관리, 어드민, 서비스 운영 전반 관리, 요금, 결제, 구독, 프로모션 | 64개 |
| lane4-partner-api | 법인어드민 API | `~/IdeaProjects/lane4-partner-api` | 대시보드, 차량관제, 예약, 예약/이용내역, 슈퍼바이저, 결제링크, 항공편, 안전번호 | 62개 |
| lane4-guest-api | 사용자 웹 API | `~/IdeaProjects/lane4-guest-api` | 예약, 결제(Toss/PortOne), 소셜로그인, 쿠폰, 기프트카드, 셔틀 | 63개 |
| lane4-app-api | 사용자 앱 API | `~/IdeaProjects/lane4-app-api` | 예약, 결제(KCP), DRT, 구독, 소셜로그인, 쿠폰 | 38개 |
| lane4-driver-api | 기사앱 API | `~/IdeaProjects/lane4-driver-api` | 배차 운행, 스케줄, 출퇴근, 위치, 셔틀, 경비문서 | 48개 |
| lane4-monitoring-api | 차량 관제 소켓 API | `~/IdeaProjects/lane4-monitoring-api` | 실시간 차량관제(WebSocket/Socket.IO), ETA, 위치, 경로 | 22개 |
| lane4-notification-api | 알림 템플릿 API | `~/IdeaProjects/lane4-notification-api` | 알림 템플릿, 푸시(SQS Provider), 다채널 발송 | 24개 |

## 프론트 프로젝트 목록

모든 프론트 프로젝트는 Next.js 15 + React 19 + Ant Design + Tailwind CSS + TanStack React Query 기반이다.

| 프로젝트명 | 역할 | 경로 | 상태관리 | 특이사항 |
|-----------|------|------|---------|---------|
| lane4-admin | 뉴어드민 프론트 | `~/IdeaProjects/lane4-admin` | Context API | Bryntum Scheduler, Playwright E2E |
| lane4-biz | 법인어드민 프론트 | `~/IdeaProjects/lane4-partner` | Zustand + Context | PC/모바일 분리, i18n, Socket.IO, MSW |
| lane4-web | 사용자 웹 프론트 | `~/IdeaProjects/lane4-guest` | Redux Toolkit + Persist | PortOne/Toss SDK, Firebase, Cypress E2E, MSW |

## 키워드 → 프로젝트 매핑

이슈에 포함된 키워드로 관련 프로젝트를 빠르게 특정한다.

| 키워드 | 우선 탐색 프로젝트 (백엔드 → 프론트) |
|--------|----------------------------------|
| 어드민, 배차관리, 요금설정, 기사스케줄, 통계 | lane4-admin-api → lane4-admin |
| 법인어드민, 법인 예약, 차량관제, 슈퍼바이저 | lane4-partner-api → lane4-biz |
| 사용자 웹, 웹 예약, 웹 결제, 결제URL | lane4-guest-api → lane4-web |
| 사용자 앱, 앱 예약, 앱 결제, DRT | lane4-app-api |
| 기사앱, 기사 운행, 출퇴근 | lane4-driver-api |
| 관제, 실시간 위치, 소켓 | lane4-monitoring-api |
| 알림, 알림 템플릿, 푸시 발송 | lane4-notification-api |
| 결제, PG, Toss | lane4-guest-api (Toss/PortOne), lane4-app-api (KCP) |
| 쿠폰, 기프트카드, 프로모션 | lane4-guest-api, lane4-admin-api |
