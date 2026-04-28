# Q&A Templates (Step 2: 의도 명확화)

사용자 요청에서 모호한 카테고리를 추출하여 `AskUserQuestion`으로 일괄 발사. 카테고리당 한 질문, 옵션 2~4개 + 자유입력.

---

## Backend (NestJS) 카테고리

### Q-B1: 엔드포인트 정의
모호 신호: 사용자가 path/HTTP method를 명시하지 않음
```
question: "엔드포인트는 어떻게 정의할까요?"
header: "엔드포인트"
options:
  - "사용자가 명시한 path/method (있으면)"
  - "표준 RESTful: GET /resources, POST /resources, GET /resources/:id, ..."
  - "기존 같은 도메인 컨트롤러 패턴 따라"
  - "메서드명에서 추론"
```

### Q-B2: 인증/권한
모호 신호: 사용자가 권한 명시 안 함
```
question: "인증/권한 정책은?"
header: "권한"
options:
  - "JwtAuthGuard (일반 사용자 인증)"
  - "RoleGuards (어드민)"
  - "Public — 인증 불필요"
  - "OptionalJwt — 게스트 허용"
```

### Q-B3: DTO 위치/네이밍
모호 신호: 사용자가 새 도메인 추가 (기존 폴더 없음)
```
question: "DTO를 어디에 둘까요?"
header: "DTO 위치"
options:
  - "src/domains/<new-domain>/application/dto/ (DDD 표준)"
  - "기존 도메인의 dto/에 합치기 (어느 도메인?)"
  - "src/<flat-module>/dto/ (legacy 패턴)"
```

### Q-B4: Kafka 이벤트 발행 여부
모호 신호: 도메인 이벤트(생성/상태변경)가 발생하지만 사용자가 알림/연계 언급 없음
```
question: "이 작업이 Kafka 이벤트를 발행해야 하나요?"
header: "Kafka 발행"
options:
  - "예 — 토픽명: local.<domain>.<event> (어떤?)"
  - "아니오"
  - "기존 producer 재활용 (어느 producer?)"
```

### Q-B5: Redis 캐싱
모호 신호: 조회 API + 결과 변하지 않음 + 자주 호출
```
question: "Redis 캐싱이 필요한가요?"
header: "캐싱"
options:
  - "예 — TTL과 키 형식 별도 정의"
  - "아니오"
  - "기존 캐시 패턴 따라"
```

### Q-B6: lane4-driver-api Redis 인스턴스 (cwd 한정)
조건: cwd === lane4-driver-api AND Q-B5 답이 "예"
```
question: "어느 Redis 인스턴스를 사용할까요? (lane4-driver-api 듀얼/트리플)"
header: "Redis 인스턴스"
options:
  - "commons/redis/ (legacy ioredis @InjectRedis)"
  - "commons/newRedis/ (new instance)"
  - "commons/cache/ (cache-manager 추상화)"
  - "같은 도메인 기존 코드 따라"
```

### Q-B7: 트랜잭션 경계
모호 신호: 한 메서드에서 여러 entity write
```
question: "트랜잭션 처리는?"
header: "트랜잭션"
options:
  - "@Transactional() 데코레이터"
  - "dataSource.transaction(...)"
  - "트랜잭션 불필요 (단일 write)"
```

### Q-B8: 알림 트리거
모호 신호: 도메인 이벤트(상태 변경/완료) 발생
```
question: "이 액션 후 알림을 보내야 하나요?"
header: "알림"
multiSelect: true
options:
  - "Push (FCM/APNS) — 사용자에게"
  - "알림톡 (KakaoTalk) — lane4-notification-api 경유"
  - "Slack — 내부 모니터링 채널 (어느 SlackChannelType?)"
  - "없음"
```

### Q-B9: MyBatis vs TypeORM (lane4-admin-api 한정)
조건: cwd === lane4-admin-api AND 복잡한 쿼리 필요
```
question: "복잡 쿼리, 어디에 작성할까요?"
header: "쿼리 작성"
options:
  - "TypeORM createQueryBuilder (가능하면 우선)"
  - "MyBatis XML mapper (복잡한 join/aggregation 시)"
```

---

## Frontend (Next.js) 카테고리

### Q-F1: API 호출 위치
모호 신호: 새 backend endpoint 호출
```
question: "API 호출 코드는 어디에?"
header: "API 호출"
options:
  - "기존 service 클래스에 메서드 추가 (어느 service?)"
  - "새 service 클래스 생성 (apis/<domain>/<domain>.service.ts)"
```

### Q-F2: 응답 타입 위치
모호 신호: 새 응답 DTO 정의 필요
```
question: "응답/요청 타입은?"
header: "타입 정의"
options:
  - "apis/<domain>/<domain>.type.ts에 새로 정의"
  - "기존 타입 재사용 (어느?)"
  - "백엔드 OpenAPI 자동생성 타입 사용 (있으면)"
```

### Q-F3: React Query 키 구조
모호 신호: 새 query/mutation 추가
```
question: "React Query 키 구조는?"
header: "Query Key"
options:
  - "[<domain>, <subkey>] hierarchical (표준)"
  - "기존 Queries 클래스 확장"
  - "별도 새 Queries 클래스 생성"
```

### Q-F4: Mutation invalidation
모ho 신호: write 작업 추가
```
question: "성공 시 어떤 query를 invalidate?"
header: "Invalidation"
options:
  - "같은 도메인 전체 (<DomainQueries>.keys.all)"
  - "특정 query만 (어느?)"
  - "invalidation 없음"
```

### Q-F5: 페이지 vs 컴포넌트 위치
모호 신호: UI 추가 (페이지인지 재사용 컴포넌트인지 불명확)
```
question: "어디에 위치할까요?"
header: "위치"
options:
  - "신규 페이지 (pages/<route> 또는 app/<route>)"
  - "기존 페이지의 부분 (어느 페이지?)"
  - "재사용 컴포넌트 (components/<Group>/<Component>)"
```

### Q-F6: 폼 처리
모호 신호: 사용자 입력 폼 필요
```
question: "폼 처리는?"
header: "폼"
options:
  - "react-hook-form + Zod (표준)"
  - "uncontrolled (단순 input 1~2개)"
  - "다른 라이브러리 (지정)"
```

### Q-F7: 권한 체크 (어드민)
모호 신호: lane4-admin/biz에서 권한 분기 필요
```
question: "사용자 권한 체크가 필요한가요?"
header: "권한"
options:
  - "예 — 어드민 권한 분기"
  - "예 — 법인 권한 분기"
  - "예 — 기타 (지정)"
  - "아니오"
```

---

## 공통 카테고리

### Q-C1: 명확화 필요 없음 (사용자 요청이 충분히 명확)
모호 포인트가 0~1개일 때 Q&A 스킵하고 바로 Step 3로.

### Q-C2: 사용자 요청 자체가 모호
조건: 어떤 도메인/기능인지조차 불명확
```
question: "어떤 도메인의 기능인가요?"
header: "도메인"
options:
  - "기존 도메인 확장 (어느?)"
  - "신규 도메인 (이름?)"
  - "유틸리티/공통"
```

---

## 사용 가이드

1. **카테고리 선별**: 사용자 요청 텍스트 + cwd 기반으로 위 카테고리 중 모호한 것만 골라 사용. 모든 카테고리 묻지 말 것.
2. **일괄 발사**: 2개 이상이면 `AskUserQuestion`에 모두 한 번에. 1개면 그것만.
3. **자유입력 활용**: "Other" 옵션은 자동 추가됨. 사용자가 자유입력하면 그대로 채택.
4. **답변 통합**: 답변을 Pre-flight (Step 3) 입력으로 사용. 컨벤션 위반/엣지케이스가 답변과 충돌하면 사용자에게 재확인.
