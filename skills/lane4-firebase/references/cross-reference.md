# Cross-Reference 가이드: Firebase ↔ MySQL / Redis / ES

> 이 문서는 Firebase RTDB 데이터와 다른 데이터 스토어(MySQL, Redis, ES) 간의 연계 관계를 정리한다.
> 다른 스킬(lane4-mysql, lane4-redis, lane4-es)과 cross-reference 조회가 필요할 때 참조한다.

---

## 목차

1. [Firebase → MySQL 연계](#1-firebase--mysql-연계)
2. [Firebase → Redis 연계](#2-firebase--redis-연계)
3. [Firebase → ES 연계](#3-firebase--es-연계)
4. [연계 조회 시나리오](#4-연계-조회-시나리오)

---

## 1. Firebase → MySQL 연계

Firebase RTDB의 키 필드를 MySQL 테이블과 JOIN하여 상세 정보를 조회할 수 있다.

| Firebase 경로 | Firebase 키 필드 | MySQL 테이블 | MySQL 키 | 연계 용도 |
|--------------|-----------------|-------------|----------|----------|
| `calling/user_{id}` | userId | `SVC_USER` | `USER_ID` | 유저 상세정보 (이름, 연락처 등) |
| `calling/user_{id}/allocId_{id}` | allocId | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 (경로, 요금 등) |
| `driving/driver_{id}` | driverId | `DRIVER` | `DRV_ID` | 기사 상세정보 (이름, 차량 등) |
| `driving/driver_{id}/resv/allocId` | allocId | `ALLOCATION` | `ALLOC_ID` | 배차 상세정보 |
| `driving/driver_{id}/resv/status` | status | `ALLOC_STATUS_HIST` | `STATUS` | 배차 상태 이력 |

### 연계 예시

**"기사 661 배차가 RTDB에 남아있는데 DB 상태는?"**

```
1단계: Firebase 조회
  firebase --project lane4-driver-c8064 database:get /real/driving/driver_661
  → allocId: 12345, status: "30" 확인

2단계: MySQL 조회 (lane4-mysql 스킬 연계)
  SELECT * FROM ALLOCATION WHERE ALLOC_ID = 12345;
  → 실제 배차 상태, 완료 여부 등 확인

3단계: 비교 분석
  → RTDB에는 남아있지만 MySQL에서 이미 완료된 상태라면 → RTDB 정리 필요
```

---

## 2. Firebase → Redis 연계

| Firebase 경로 | Redis 연계 키 | 연계 용도 |
|--------------|-------------|----------|
| `calling/user_{id}` | `dashboard:*` (배차현황) | 대시보드 캐시와 콜 상태 비교 |
| `maintenance/active` | - | 점검 모드 변경 시 대시보드 캐시 영향 확인 |

### 연계 예시

**"점검 모드 켰는데 대시보드에 반영됐나?"**

```
1단계: Firebase 확인
  firebase --project lane4-driver-c8064 database:get /real/common/maintenance/active
  → true 확인

2단계: Redis 확인 (lane4-redis 스킬 연계)
  대시보드 관련 캐시 키 조회
  → 캐시가 점검 상태를 반영하고 있는지 확인
```

---

## 3. Firebase → ES 연계

| Firebase 경로 | ES 인덱스 | 연계 용도 |
|--------------|----------|----------|
| `driving/driver_{id}` | `driver` (실시간 상태) | RTDB 배차 상태와 ES 기사 인덱스 비교 |
| `calling/user_{id}` | `allocation` (배차 매핑) | 콜 상태와 ES 배차 인덱스 비교 |
| `maintenance/version` | - | (직접 연계 없음) |

### 연계 예시

**"기사 661이 RTDB에서는 운행 중인데 ES에서는?"**

```
1단계: Firebase 조회
  firebase --project lane4-driver-c8064 database:get /real/driving/driver_661
  → status: "30" (운행 중)

2단계: ES 조회 (lane4-es 스킬 연계)
  ES driver 인덱스에서 기사 661의 현재 상태 조회
  → 상태 일치 여부 비교

3단계: 불일치 시
  → RTDB와 ES 간 동기화 이슈 가능성 → 코드 레벨 추적 필요
```

---

## 4. 연계 조회 시나리오

### 시나리오 1: 배차 불일치 진단

**질문**: "배차 12345가 RTDB에는 있는데 실제로 유효한 건가?"

| 단계 | 스킬 | 조회 내용 |
|------|------|----------|
| 1 | **lane4-firebase** | `database:get /real/driving/...` → RTDB 배차 상태 확인 |
| 2 | **lane4-mysql** | `SELECT * FROM ALLOCATION WHERE ALLOC_ID = 12345` → DB 배차 상태 확인 |
| 3 | **lane4-es** | ES allocation 인덱스 조회 → 검색 인덱스 상태 확인 |
| 4 | 종합 | 3곳의 상태 비교 → 불일치 원인 분석 |

### 시나리오 2: 앱 접근 불가 진단

**질문**: "고객이 앱이 안 열린다고 하는데?"

| 단계 | 스킬 | 조회 내용 |
|------|------|----------|
| 1 | **lane4-firebase** | maintenance/active 확인 → 점검 모드 여부 |
| 2 | **lane4-firebase** | version 확인 → minimum 버전 vs 고객 앱 버전 |
| 3 | **lane4-mysql** | 유저 정보 조회 → 계정 상태 확인 |
| 4 | 종합 | 점검 모드 / 버전 미달 / 계정 이슈 중 원인 판별 |

### 시나리오 3: 푸시 알림 미도달 진단

**질문**: "유저 5935에게 푸시가 안 가요"

| 단계 | 스킬 | 조회 내용 |
|------|------|----------|
| 1 | **lane4-firebase** | `calling/user_5935` 확인 → RTDB 콜 플래그 존재 여부 |
| 2 | **lane4-mysql** | 유저 FCM 토큰 등록 여부 확인 |
| 3 | **lane4-firebase (코드 참조)** | FCM 발송 로직 코드 경로 안내 |
| 4 | 종합 | RTDB 플래그 없음 / 토큰 미등록 / 발송 실패 중 원인 판별 |

---

## 키 필드 매핑 요약

```
Firebase userId  ←→ MySQL SVC_USER.USER_ID
Firebase allocId ←→ MySQL ALLOCATION.ALLOC_ID
Firebase driverId ←→ MySQL DRIVER.DRV_ID
Firebase status  ←→ MySQL ALLOC_STATUS_HIST.STATUS
```

이 매핑을 사용하면 Firebase에서 조회한 ID를 다른 스킬에 전달하여 상세 조회가 가능하다.
