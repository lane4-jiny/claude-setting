# Firebase 프로젝트 맵

## 목차
1. [프로젝트 목록](#1-프로젝트-목록)
2. [등록된 앱](#2-등록된-앱)
3. [사용 중인 Firebase 서비스](#3-사용-중인-firebase-서비스)
4. [RTDB 구조 — Driver 프로젝트](#4-rtdb-구조--driver-프로젝트)
5. [RTDB 구조 — User 프로젝트](#5-rtdb-구조--user-프로젝트)
6. [RTDB 경로 빠른 참조표](#6-rtdb-경로-빠른-참조표)
7. [Database Rules](#7-database-rules)

---

## 1. 프로젝트 목록

| 프로젝트명 | Project ID | 용도 | 리전 |
|-----------|------------|------|------|
| Lane4 Driver | `lane4-driver-c8064` | 기사 앱 실시간 데이터 | asia-northeast3 |
| Lane4 User | `lane4-user-5993e` | 고객 앱 실시간 데이터 | - |

**Service Account (참조용):**
- Driver: `firebase-adminsdk-qrg1d@lane4-driver-c8064.iam.gserviceaccount.com`
- User: `firebase-adminsdk-6odkj@lane4-user-5993e.iam.gserviceaccount.com`

---

## 2. 등록된 앱

### lane4-driver-c8064

| 앱 이름 | App ID | 플랫폼 |
|---------|--------|--------|
| Lane4 Driver | `1:581938180759:android:7aa553882eaaa1670e6fd2` | ANDROID |
| Lane4 Driver [Debug] | `1:581938180759:android:df9f750867b929520e6fd2` | ANDROID |
| lane4-web | `1:581938180759:web:cd243e3017e845580e6fd2` | WEB |

### lane4-user-5993e

| 앱 이름 | App ID | 플랫폼 |
|---------|--------|--------|
| Lane4 User | `1:986944302374:android:76546e70c08409dc8a25e7` | ANDROID |
| (iOS) | `1:986944302374:ios:0f9217a2dfa057cf8a25e7` | IOS |
| lane4-web | `1:986944302374:web:20a8c43d02496c868a25e7` | WEB |

---

## 3. 사용 중인 Firebase 서비스

| 서비스 | Driver | User | 용도 |
|--------|--------|------|------|
| **Realtime Database** | ✅ | ✅ | 실시간 콜/배차 상태, 점검 모드, 앱 버전 |
| **Cloud Messaging (FCM)** | ✅ | ✅ | 푸시 알림 (사일런트 포함) |
| Hosting | ✅ | ✅ | 웹 호스팅 (미사용 가능성) |
| Firestore | 빈 인덱스 | 비활성 | 미사용 |
| Cloud Functions | ❌ | ❌ | 미사용 |
| Remote Config | 비어있음 | 비어있음 | 미사용 |

---

## 4. RTDB 구조 — Driver 프로젝트

Project ID: `lane4-driver-c8064`

```
/{env}/                              # dev | real
├── calling/
│   └── user_{userId}/
│       └── allocId_{allocId}: true   # 콜 요청 알림 플래그 (boolean)
├── common/
│   └── maintenance/
│       ├── active: boolean           # 점검 모드 활성화 여부
│       └── version/
│           └── android/
│               ├── codepush: string  # CodePush 버전 ("v58" 등)
│               ├── current: string   # 최신 앱 버전 ("3.4.7")
│               └── minimum: string   # 최소 지원 버전 ("2.1.1")
└── driving/
    └── driver_{driverId}/
        └── resv/
            ├── allocId: number       # 현재 배차 ID
            └── status: string        # 배차 상태 코드 ("30" 등)
```

### Driver 버전 정보 (참고값)

| 환경 | codepush | current | minimum |
|------|----------|---------|---------|
| dev | v11 | 3.4.7 | 2.1.1 |
| real | v58 | 3.4.7 | 2.1.1 |

### Driver Allocation 도메인 모델 (driving 하위 전체 필드)

코드에서 정의된 배차 데이터 전체 구조:

```typescript
{
  callId: number       // 콜 요청 ID
  allocId: number      // 배차 ID
  destAddr: string     // 도착지 주소
  destPoi: string      // 도착지 좌표
  dptAddr: string      // 출발지 주소
  dptPoi: string       // 출발지 좌표
  time: number         // 예상 소요 시간
  dist: number         // 거리
  status: string       // 상태 코드
  cpnPubId: number     // 쿠폰 발행 ID
  serviceId: number    // 서비스 ID
  wayPoints: any       // 경유지
}
```

---

## 5. RTDB 구조 — User 프로젝트

Project ID: `lane4-user-5993e`

```
/{env}/                              # dev | real
├── calling/
│   └── user_{userId}/
│       └── allocId_{allocId}: true   # 콜 요청 알림 플래그 (boolean)
└── common/
    └── maintenance/
        ├── active: boolean           # 점검 모드 활성화 여부
        └── version/
            ├── android/
            │   ├── codepush: string  # "v158"
            │   ├── current: string   # "2.5.0"
            │   └── minimum: string   # "1.8.0"
            └── ios/
                ├── codepush: string  # "v251"
                ├── current: string   # "2.5.0"
                └── minimum: string   # "1.8.0"
```

### User 버전 정보 (참고값, real 환경)

| 플랫폼 | codepush | current | minimum |
|--------|----------|---------|---------|
| android | v158 | 2.5.0 | 1.8.0 |
| ios | v251 | 2.5.0 | 1.8.0 |

> User 프로젝트는 **driving 노드가 없다**. 운행 상태는 Driver 프로젝트에서만 관리.

---

## 6. RTDB 경로 빠른 참조표

자주 조회하는 경로를 한눈에 정리:

| 목적 | 프로젝트 | 경로 |
|------|---------|------|
| 점검 모드 상태 | Driver | `/{env}/common/maintenance/active` |
| 점검 모드 상태 | User | `/{env}/common/maintenance/active` |
| 점검 + 버전 전체 | Driver | `/{env}/common/maintenance` |
| 점검 + 버전 전체 | User | `/{env}/common/maintenance` |
| 기사앱 버전 (Android) | Driver | `/{env}/common/maintenance/version/android` |
| 고객앱 버전 (Android) | User | `/{env}/common/maintenance/version/android` |
| 고객앱 버전 (iOS) | User | `/{env}/common/maintenance/version/ios` |
| 유저 콜 상태 | Driver | `/{env}/calling/user_{userId}` |
| 유저 콜 상태 | User | `/{env}/calling/user_{userId}` |
| 기사 운행 상태 | Driver | `/{env}/driving/driver_{driverId}` |
| 기사 배차 정보 | Driver | `/{env}/driving/driver_{driverId}/resv` |
| RTDB 최상위 키 | 둘 다 | `/{env}` (--shallow) |

---

## 7. Database Rules

### User 프로젝트 Rules (lane4-web 기준)

```json
{
  "rules": {
    "dev": {
      "common": { ".read": true, ".write": true },
      "calling": { ".read": true, ".write": true }
    },
    "real": {
      "common": { ".read": true, ".write": true },
      "calling": { ".read": true, ".write": true }
    }
  }
}
```

dev와 real 모두 common, calling 경로에 대해 읽기/쓰기 허용.
단, 스킬에서 쓰기를 수행할 때는 반드시 사용자 확인을 거친다 (규칙과 무관하게 안전 원칙 적용).
