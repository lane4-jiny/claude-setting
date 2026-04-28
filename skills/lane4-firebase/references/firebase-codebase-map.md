# Firebase 코드베이스 맵

> 이 문서는 Lane4 코드베이스 내 Firebase 사용처를 정리한다.
> 코드 추적, 이슈 분석, FCM 관련 조사 시 이 문서를 참조한다.

---

## 목차

1. [프로젝트별 Firebase 사용 현황](#1-프로젝트별-firebase-사용-현황)
2. [핵심 코드 파일 경로](#2-핵심-코드-파일-경로)
3. [Firebase Admin SDK 버전](#3-firebase-admin-sdk-버전)
4. [코드 패턴 설명](#4-코드-패턴-설명)

---

## 1. 프로젝트별 Firebase 사용 현황

| 프로젝트 | RTDB | FCM | 주요 파일 |
|---------|------|-----|----------|
| **lane4-backend-library** | ✅ (공통 모듈) | ✅ | `src/firebase/` 전체 |
| **lane4-admin-api** | ✅ (CustomFirebase) | - | `src/domains/custom-firebase/` |
| **lane4-driver-api** | ✅ (콜/배차) | - | `src/domains/custom-firebase/`, `src/lib/external/firebase.ts` |
| **lane4-app-api** | ✅ (CustomFirebase) | - | `src/domains/custom-firebase/` |
| **lane4-monitoring-api** | ✅ (상태 추적) | ✅ (사일런트 푸시) | `src/commons/firebase/`, `src/commons/custom-firebase/` |
| **lane4-scheduler** | - | ✅ (알림) | `src/lib/external/firebase.ts` |
| **lane4-notification-server** | - | ✅ (Push 발송) | AWS SQS → FCM 경유 |
| **lane4-web** | - | - | `firebase.json` (Hosting) |
| **lane4-app-user** | - | ✅ (Push 수신) | React Native FCM |
| **lane4-app-driver** | ✅ (콜 수신) | ✅ (Push 수신) | React Native RTDB + FCM |

---

## 2. 핵심 코드 파일 경로

### lane4-backend-library (공통 Firebase 모듈)

이 프로젝트가 Firebase 관련 공통 로직의 핵심이다. 다른 API 프로젝트들이 이 모듈을 확장하여 사용한다.

```
src/firebase/
├── firebase.module.ts                              # NestJS 모듈
├── application/
│   ├── firebase.service.ts                         # 추상 베이스 서비스
│   ├── driver.firebase.service.ts                  # 기사 RTDB 조작
│   └── user.firebase.service.ts                    # 고객 RTDB 조작
├── infrastructure/
│   └── firebase.utils.ts                           # RTDB/Messaging 유틸
├── environment/
│   └── firebase.environment.ts                     # 인증 정보/URL
└── domain/
    ├── firebase.driver.allocation.ts               # 기사 배차 도메인 모델
    └── firebase.user.allocation.ts                 # 고객 배차 도메인 모델
```

### 각 API 프로젝트 (CustomFirebase 패턴)

`lane4-admin-api`, `lane4-driver-api`, `lane4-app-api` 등은 backend-library의 FirebaseService를 확장한다:

```
src/domains/custom-firebase/
├── custom.firebase.module.ts
└── application/
    ├── custom.driver.firebase.service.ts           # DriverFirebaseService 확장
    └── custom.user.firebase.service.ts             # UserFirebaseService 확장
```

### lane4-monitoring-api (독립 Firebase 모듈)

monitoring-api는 자체 Firebase 모듈을 가진다:

```
src/commons/firebase/           # 자체 Firebase 모듈
src/commons/custom-firebase/    # CustomFirebase 패턴
```

### lane4-driver-api (레거시 패턴 혼재)

driver-api에는 레거시 코드와 모던 패턴이 공존한다:

```
src/lib/external/firebase.ts              # 레거시: hardcoded config
src/domains/custom-firebase/              # 모던: CustomFirebase 패턴
```

### 모바일 앱

```
# lane4-app-driver (기사앱)
→ React Native에서 RTDB 실시간 리스너 + FCM 수신

# lane4-app-user (고객앱)
→ React Native에서 FCM 수신
```

---

## 3. Firebase Admin SDK 버전

| 프로젝트 | firebase-admin 버전 | 비고 |
|---------|-------------------|------|
| lane4-backend-library | ^13.0.1 | 최신 |
| lane4-monitoring-api | ^12.0.0 | 한 세대 이전 |
| lane4-scheduler | ^10.0.1 | 구버전 (레거시) |

---

## 4. 코드 패턴 설명

### 모던 패턴: CustomFirebase

대부분의 API 프로젝트에서 사용하는 패턴이다. `lane4-backend-library`의 `FirebaseService`(추상 클래스)를 확장하여 프로젝트별 커스텀 로직을 추가한다.

```
backend-library의 FirebaseService (추상)
  ↓ 확장
각 API의 CustomDriverFirebaseService / CustomUserFirebaseService
```

- `firebase.environment.ts`에서 ConfigService를 통해 인증 정보를 주입
- 환경(dev/real)은 ConfigService 설정에 따라 결정

### 레거시 패턴: Hardcoded Config

일부 프로젝트(`lane4-driver-api`, `lane4-scheduler`)에 남아있는 레거시 방식:

- `src/lib/external/firebase.ts`에 Firebase config가 직접 하드코딩
- ConfigService 대신 직접 `firebase-admin.initializeApp()` 호출

### FCM 발송 경로

```
lane4-scheduler (알림 스케줄링)
  → AWS SQS
    → lane4-notification-server (FCM 발송)
      → FCM → 모바일 디바이스

lane4-monitoring-api (사일런트 푸시)
  → 직접 FCM 발송
```

### RTDB 읽기/쓰기 경로

```
lane4-admin-api     → CustomFirebase → RTDB (점검/버전 관리)
lane4-driver-api    → CustomFirebase → RTDB (콜/배차 상태)
lane4-app-api       → CustomFirebase → RTDB (앱 상태)
lane4-monitoring-api → CustomFirebase → RTDB (상태 추적)
```
