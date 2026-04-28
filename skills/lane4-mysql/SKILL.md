---
name: lane4-mysql
description: |
  LANE4 DB 자연어 SQL 쿼리 생성 및 데이터 분석 스킬.
  lane4-mysql MCP 서버를 통해 DB에 접근하여 자연어 질문을 SQL로 변환하고 실행한다.
  이 스킬은 다음 상황에서 반드시 사용한다:
  - 사용자가 배차, 기사, 차량, 법인, 요금, 결제, 쿠폰 등 LANE4 비즈니스 데이터를 조회할 때
  - "이번 달 배차 현황", "법인별 매출", "기사 스케줄" 등 운영 데이터 질문
  - DB 테이블 구조, 컬럼 정보, 관계 등을 물어볼 때
  - SQL 쿼리 작성을 도와달라고 할 때
  - 데이터 분석, 통계, 리포트 생성 요청 시
  DB 관련 키워드가 조금이라도 포함되면 이 스킬을 적극적으로 활용할 것.
---

# LANE4 MySQL DB 스킬

LANE4 운송 서비스 플랫폼의 MySQL DB를 자연어로 조회하고 분석하는 스킬이다.

## MCP 도구

`lane4-mysql` MCP 서버의 도구를 사용한다:

- `query`: SELECT 쿼리 실행 (READ-ONLY)

## 핵심 원칙

1. **READ-ONLY**: SELECT 문만 사용한다. INSERT, UPDATE, DELETE, DROP 등은 절대 실행하지 않는다.
2. **안전한 쿼리**: 대용량 테이블 조회 시 반드시 WHERE 조건 + LIMIT을 사용한다.
3. **도메인 이해 우선**: 쿼리 작성 전에 도메인 맵과 테이블 관계를 참조한다.
4. **단계적 접근**: 복잡한 질문은 여러 쿼리로 나누어 단계적으로 답변한다.

## 워크플로우

사용자가 데이터 관련 질문을 하면:

1. **도메인 파악**: 질문이 어떤 비즈니스 도메인에 해당하는지 판단한다
   → `references/domain-map.md` 참조
2. **테이블 선택**: 필요한 테이블과 JOIN 경로를 결정한다
   → `references/relationships.md` 참조
3. **상태값 확인**: 필터에 사용할 상태값/코드값을 확인한다
   → `references/status-codes.md` 참조
4. **스키마 확인**: 정확한 컬럼명과 타입을 확인한다
   → `references/core-schemas.md` 참조
5. **쿼리 작성**: SQL을 생성하고 MCP를 통해 실행한다
   → `references/query-patterns.md`에서 유사 패턴 참고
6. **결과 해석**: 결과를 사용자가 이해하기 쉽게 요약한다

## 주의사항

- 날짜 컬럼 혼재: `date`+`time` 분리형(ALLOCATION.ALLOC_DT + ALLOC_TIME) vs `datetime` 통합형(REG_DT)이 있다
- PK 네이밍이 약어 기반: ALLOC_ID, DRV_ID, CAR_ID 등
- STATUS 값이 테이블마다 다르다 ('NORMAL', '정상', 'ACTIVE' 등) → status-codes.md 필수 참조
- COMP_CD(법인코드)가 명시적 FK가 아닌 경우도 있으므로 JOIN 시 주의
- 쿼리 결과가 많을 경우 LIMIT 50 이하로 제한하고, 필요시 집계(COUNT, SUM, AVG)를 먼저 제공

## 참조 문서

| 문서                             | 용도               | 언제 읽는가             |
|--------------------------------|------------------|--------------------|
| `references/domain-map.md`     | 도메인별 테이블 분류      | 어떤 테이블을 써야 할지 모를 때 |
| `references/core-schemas.md`   | 핵심 테이블 컬럼 정보     | 정확한 컬럼명/타입이 필요할 때  |
| `references/relationships.md`  | 테이블 간 FK/JOIN 경로 | JOIN 쿼리를 작성할 때     |
| `references/status-codes.md`   | 상태값/enum/공통코드    | WHERE 조건에 상태값을 쓸 때 |
| `references/query-patterns.md` | 자주 쓰는 쿼리 예시      | 복잡한 쿼리 패턴이 필요할 때   |
