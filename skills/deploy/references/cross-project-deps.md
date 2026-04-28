# 프로젝트 간 공유 테이블/연동 의존성

## 공유 테이블 매핑

다수의 프로젝트가 동일 DB 테이블을 사용한다. 테이블 스키마 변경시 모든 관련 프로젝트에 영향이 있다.

### 핵심 공유 테이블

| 테이블 | 사용 프로젝트 | 비고 |
|--------|-------------|------|
| ALLOCATION | admin-api, partner-api, guest-api, driver-api, monitoring-api | 모든 프로젝트의 핵심 테이블 |
| CALL_REQ | admin-api, partner-api, guest-api, app-api | 호출 요청 |
| DRIVER | admin-api, driver-api, monitoring-api | 기사 정보 |
| CAR | admin-api, driver-api | 차량 정보 |
| COMP | admin-api, partner-api | 법인 정보 |
| SVC_USER | admin-api, guest-api, app-api | 사용자 정보 |
| FARE / FARE_HISTORY | admin-api, partner-api, monitoring-api | 요금/매출 |
| PAY_TRX | admin-api, partner-api, guest-api | 결제 |
| CPN | admin-api, guest-api | 쿠폰 |
| CD_GRP / CD_DTL | 전체 | 공통코드 (변경시 전체 영향) |

### 프론트엔드 의존성

| 프론트엔드 | 의존하는 API |
|-----------|-------------|
| lane4-admin | admin-api |
| lane4-biz | partner-api |
| lane4-web | guest-api |

## 프로젝트 간 API 호출

### 내부 API 호출 관계
- notification-api ← 다른 API에서 알림 발송 요청
- monitoring-api ← 실시간 모니터링 데이터 수집

### 공유 모듈/라이브러리
- 공통 Entity 정의가 여러 프로젝트에 복사되어 사용될 수 있음
- Entity 변경시 모든 프로젝트의 해당 Entity 동기화 필요

## 변경 영향 분석 가이드

### 테이블 변경시
1. 위 공유 테이블 매핑에서 영향받는 프로젝트 확인
2. 각 프로젝트에서 해당 테이블의 Entity 파일 확인
3. Entity 변경이 필요한 경우 모든 프로젝트에 반영

### API 변경시
1. 프론트엔드 의존성에서 해당 API를 사용하는 프론트 확인
2. 내부 API 호출 관계에서 해당 API를 호출하는 서비스 확인
3. Breaking Change인 경우 모든 호출자 업데이트 필요

### 공통코드 변경시
- CD_GRP/CD_DTL 변경은 전체 프로젝트에 영향
- 코드값 변경/삭제시 해당 코드를 사용하는 모든 로직 확인

> **참고**: 이 문서는 프로젝트 구조 변경시 업데이트가 필요합니다.
> 새 프로젝트 추가나 테이블 공유 관계 변경시 반영하세요.
