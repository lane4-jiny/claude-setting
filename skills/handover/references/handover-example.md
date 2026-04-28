# 인수인계서 예시

아래 예시를 참고하여 인수인계서를 생성한다.
git log, diff, 코드 분석 결과를 이 구조 예시를 참고하여 작성한다.


# 기프트카드 작업

## 관련 프로젝트
- lane4-admin-api
- lane4-guest-api

---

## 태스크 문서

[대한항공 기프트카드 작업](https://www.notion.so/2d29e329685b80a5a253e89dc117cfaa?pvs=21) 

## 작업 배경

- [대한항공 바우처 회의](https://www.notion.so/2ca9e329685b803681bff349cec9ad47?pvs=21)
- 대한항공 기내 판매 잡지에 레인포 서비스에 대한 기프트카드가 추가 될 예정

## 주요 작업 내용

### GUEST

- giftcard
- user_point

폴더 참고

### GIFT_CARD 정책

- 대한항공 기준 (20260107)
- 기프트카드의 금액은 25만원 고정, 170달러 고정
- 공항/시간대절 서비스에서만 사용 가능
    - 공항 - 전액 기프트카드 결제 가능 (1회권 개념으로 사용)
    - 시간 대절 - 시간대절의 경우 25만원 할인 (50% 할인권 개념으로 사용) * 2
    - 골프 대절 - 시간대절과 마찬가지로 25만원 할인 (50% 할인권 개념으로 사용) * 2
    - 어드민에서 각 기프트카드 별 정책 설정 가능
- 시간대절의 경우 10시간 대절 한정으로 사용
- 원 기준으로 전체 계산 후 표출만 달러 기준

### GIFT_CARD_TRANSACTION 정책

- 대한항공 기준 (20260107)
- 기프트카드 등록 시 `+25만원` 등록 트랜잭션 추가
- 1차 기프트카드에서는 케이스가 존재하지 않으나 만약 차액이 남는 경우 포인트 전환
    - 예약 중 사용 금액만큼 `차감` 트랜잭션 추가
    - 예약 후 남은 잔액만큼 `포인트 전환` 트랜잭션 추가
- 여러 장의 기프트카드 사용 시 우선 차감 순서
    1. 만료일
    2. 등록일
    3. 카드 ID
- 사용 시 `USE`, 포인트 전환 시 `CHANGE`, 등록 시 `REGISTER` 타입 사용

### USER_POINT 정책

- 대한항공 기준 (20260107)
- 예약 취소로 인한 기프트카드 환불 시 환불금은 기존 정책과 동일
    - 출발 전일 18시 이전까지 취소 시 수수료 없이 기프트카드 요금의 100% 전환
    - 출발 전일 18시 ~ 출발 전일 자정까지 취소 시 기프트카드 요금의 50% 전환
    - 출발 당일 탑승 3시간 전까지 취소 시 기프트카드 요금의 20% 전환
    - 출발 당일 탑승 3시간 내에 취소 시 기프트카드 요금의 0% 전환
    - 출발지 도착 후 취소 시 기프트카드 요금의 0% 전환
- 기프트카드 사용 후 예약 취소 시 기프트카드 금액 원복이 아닌 포인트화
- 포인트 사용 결제 후 예약 취소로 인한 기프트카드 환불 시 환불금은 기존 정책과 동일
    - 출발 전일 18시 이전까지 취소 시 수수료 없이 사용 포인트의 요금의 100% 전환
    - 출발 전일 18시 ~ 출발 전일 자정까지 취소 시 사용 포인트의 50% 전환
    - 출발 당일 탑승 3시간 전까지 취소 시 사용 포인트의 20% 전환
    - 출발 당일 탑승 3시간 내에 취소 시 사용 포인트의 0% 전환
    - 출발지 도착 후 취소 시 사용 포인트의 0% 전환
- 예약으로 인한 잔여 기프트카드 잔액에 대해 적립된 포인트에 대해서는 금액 원복 X
- ~~비회원이 아닌 진짜 회원인 경우에만 포인트 사용할 수 있도록 변경 필요~~
    - ~~현재는 기프트카드 사용 시 포인트 사용이 가능~~
    - ~~추후 기프트카드는 포인트 사용 X → 회원웹에서 포인트 사용~~
    - ~~따라서 예약 취소 시 연동 또는 회원 전환 안내 필요~~
    - [~~관련 스레드~~](https://lane4workspace.slack.com/archives/C04N7JF7HUL/p1769586749701779)

### ~~기프트카드 정책~~

- ~~일부 금액 정책이 다르게 잡혀 있어 기존 lane4의 요금을 보는 것이 아닌 신규 lane4_gift_card를 생성하여 사용~~
- `DB::GIFT_CARD_POLICY`에 각 서비스에 대한 금액 정책 작성
- 시간 대절의 경우 10시간 대절 50만원 고정
- ~~기프트카드로 요금 차감 시 톨게이트 요금, 부가 서비스 요금 등은 제외한 baseTotalAmount 기준으로 차감~~
    - ~~쿠폰 요금 차감 정책과 동일하게 작업~~
- 톨게이트 요금, 부가 서비스 요금 등 추가 요금을 제외하고 공항 25만원, 시간/공항대절 50만원 고정
    - 기프트카드 등록시 서비스 타입 별 금액권/횟수권 + 금액 설정 기능 추가됨
- 예약 시 보유하고 있는 포인트 사용 가능
    - 기프트카드 + 포인트 혼합 사용 가능
- 이용내역 설명 필드 포맷
    - 기프트카드
        - **사용** `{allocId}` 배차 사용
        - **롤백** `{allocId}` 배차 취소
        - **포인트 전환** `{allocId}` 포인트 전환
    - 포인트
        - **사용** `{allocId}` 배차 사용
        - **롤백** `{allocId}` 배차 취소
        - **포인트 전환** `{allocId}` 포인트 전환
- 기프트카드 등록 시 **`#04_알림_배차_기프트카드`** 채널로 슬랙 알림 발송

## 기타

- 게스트 테스트용 포스트맨

[giftcard.postman_collection.json](attachment:4235fedc-7065-4a7c-97c8-0745fd77dbfa:giftcard.postman_collection.json)

- 어드민 테스트용 포스트맨

[giftcard.postman_collection.json](attachment:e2d4989d-373f-4595-998c-3bf57a07c602:giftcard.postman_collection.json)

- 초기 요구명세

[초기 요구명세 정리 ](https://www.notion.so/2d89e329685b80778149e5c0562b8028?pvs=21) 

- 관련 회의록

[대한항공 바우처 회의](https://www.notion.so/2ca9e329685b803681bff349cec9ad47?pvs=21) 

[대한항공 기프트카드 관련 회의](https://www.notion.so/2dc9e329685b8075b573e80e90a2ecc7?pvs=21) 

[대한항공 기프트카드](https://www.notion.so/2ea9e329685b80d493bbf07d7b6d0af5?pvs=21) 

## 백로그

- PG사 예약 취소 시 배차 취소 및 기프트카드 사용 롤백처리 필요
    - 기존 예약 플로우도 쿠폰 사용 후 롤백 처리 안 됨


# ke 메뉴 순서 변경

## 관련 프로젝트
- lane4-biz
- lane4-partner

## 작업 배경

https://lane4workspace.slack.com/archives/C04N7JF7HUL/p1770939412400869

- 대한항공에서 메뉴 순서 변경 요청

## 작업 내용

### PARTNER

```tsx
private getHierarchicalTokenPayload(employee: Employee) {
    const policy = PermissionOrderingPolicyFactory.from(employee.companyCode);

    const sortedPermissions = policy.sort(employee.getGrantPermissions());

    const hierarchicalPermissions = HierarchicalPermissions.fromPermissions(sortedPermissions);

    return {
      pageToken: hierarchicalPermissions.toPageTokenPayload(),
      componentToken: hierarchicalPermissions.toComponentTokenPayload(),
    };
  }
```

- permission ID 기준 정렬에서 대한항공의 경우 grant_permission createdAt 기준 정렬하도록 조건 추가
- permission.ordering.policy.ts에 정책 및 sort 메소드 구현되어 있음

### BIZ

- 신규 메뉴 작업 진행
    - 일별 현황 - daily-operations
    - 실적 현황 - earning-operations

## 기타

- 권한 업데이트 쿼리
    
    ```sql
    start transaction;
    
    UPDATE LANE4.PERMISSION
    SET page = '/daily-operations',
        parent_id = null,
        project_type = 'PARTNER'
    WHERE name = '일별현황'; 
    
    INSERT INTO LANE4.PERMISSION
    (company_code, permission_type, name, endpoint, page, component, parent_id, project_type)
    VALUES
        ('ke', 'PAGE', '실적현황', null, '/earning-operations', null, null, 'PARTNER');
    
    DELETE gp
    FROM GRANT_PERMISSION gp
             JOIN PERMISSION p ON gp.permission_id = p.id
    WHERE gp.company_code = 'ke'
      AND p.permission_type = 'PAGE';
    
    INSERT INTO LANE4.GRANT_PERMISSION
    (grant_type,
     company_code,
     role,
     department_id,
     employee_id,
     permission_id,
     created_at)
    SELECT IF(ordered.name IN (
                               '대한항공',
                               '접수현황',
                               '항공편 관리',
                               '일별현황'
        ), 'ROLE', 'COMPANY')                           as grant_type,
           'ke',
           IF(ordered.name IN (
                               '대한항공',
                               '접수현황',
                               '항공편 관리',
                               '일별현황'
               ), 'COMPANY_MASTER', NULL)               AS role,
           NULL                                         AS department_id,
           NULL                                         AS employee_id,
           p.id                                         AS permission_id,
           DATE_ADD(NOW(), INTERVAL ordered.seq SECOND) AS created_at
    FROM (SELECT 1 as seq, '일별현황' as name
          UNION ALL
          SELECT 2, '차량관제'
          UNION ALL
          SELECT 3, '실적현황'
          UNION ALL
          SELECT 4, '예약/이용내역'
          UNION ALL
          SELECT 5, '예약내역'
          UNION ALL
          SELECT 6, '이용내역'
          UNION ALL
          SELECT 7, '전체내역'
          UNION ALL
          SELECT 8, '대한항공'
          UNION ALL
          SELECT 9, '접수현황'
          UNION ALL
          SELECT 10, '항공편 관리'
          UNION ALL
          SELECT 11, '대시보드'
          UNION ALL
          SELECT 12, '예약/이용 현황'
          UNION ALL
          SELECT 13, '예약관리'
          UNION ALL
          SELECT 14, '공항대절 예약') ordered
             JOIN LANE4.PERMISSION p
                  ON p.name = ordered.name
                      AND (p.company_code = 'ke' OR p.company_code IS NULL)
                      AND p.project_type = 'PARTNER'
    ORDER BY ordered.seq;
    
    commit;
    ```
    
- 타 법인에서도 메뉴 변경 요청 들어올 시 위 쿼리에서 seq, name 수정과 PARTNER에서 법인 추가로 처리

## 백로그

# 2월 인스파이어 신규 요청

## 관련 프로젝트
- lane4-partner-api


---

## 태스크 문서

[인스파이어 추가 요구 명세](https://www.notion.so/2fb9e329685b809ab295f87ad359aaef?pvs=21) 

## 작업 배경

- 차량 인수/반납 모니터링의 경우 기존 카카오톡으로 차량 계기판 확인 및 상태 점검을 하고 있었으나, 기사앱 플로우 상 차량 인수/반납 모니터링이 가능하여 신규 기능 이전

## 작업 내용

### 예약 차량 선택

- 프론트에서 `-` 처리

### **당일 예약 건 new 알림 표시**

- 백엔드에서 `allocation.regDt == allocation.allocDt` / `allocation.regDt == now()` 조건 확인하여 isTodayReservation: YesNo로 내려줌

### **상태변경 기능 추가**

- ~~ek에서 기존에 사용하던 /status-ek를 전체 사용 가능하도록 변경~~
- ~~ek에서는 기본적으로 탑승전, 운행완료, 미탑승, 운행취소를 사용하고 있으나 inspire는 미배정 건도 고려 필요~~
- `~~AllocationStatusUpdateAll` 권한 추가~~

---

26-02-26 신규 권한 추가

- AllocationStatusUpdateScope 권한 추가 → 미탑승 권한 제거

[배차상태변경_권한_사이드이펙트_분석.md](attachment:1f4b4839-db90-417f-a7b6-cc009266a670:배차상태변경_권한_사이드이펙트_분석.md)

### **항공편명 조회 응답 터미널 기준으로 공항 출/도착지 위치가 자동으로 선택**

- 백엔드에서 flightaware 조회 후 터미널, 공항 코드 필드 추가
    - ICN T1 → `AIRPORT_TYPE_01`
    - ICN T2 → `AIRPORT_TYPE_02`
    - GMP I → `AIRPORT_TYPE_03`
    - GMP D → `AIRPORT_TYPE_04`

### 차량인수/반납 모니터링

- 법인어드민 `/car-inspections` 신규 도메인 추가
- 차량 검수 후 다시 PENDING 상태로 돌아가는 것 불가능
    - PASS
    - WARN
    - FAIL
- ~~차량 인수/반납을 하나의 플로우로 묶어 판단 및 검수~~
    - ~~예) 기사 스케줄 1개 차량 2대
          차량A : 인수 / 반납
          차량B : 인수~~
    - ~~전체 검수해야 할 목록 2개~~
    - ~~차량 인수/반납 검수 시 인수/반납 CAR_INSPECTION 같이 업데이트~~
- 한 차량에 대해서 인수/반납 별도의 플로우로 판단 및 검수
- 메뉴 접근 권한 `/supervisor/car-inspection`
- 검색/필터 정책
    - 검색 가능 타입
        - DRIVER_NAME
        - CAR_NUMBER
        - ALL
    - 필터 정책
        - status 필터
    
    → 미결정된 사항
    
    - 하나의 차량에 대해서 status가 여러개라면 status 필터 걸었을 때 차량 일부 inspection만 보여도 될지? → YES

### 신규 부서 추가

```sql
start transaction;

set @CASINO_ID = (select id from DEPARTMENT where company_code = 'inspire' and name = '카지노'); -- 운영계 CASINO 수정 필요

insert into DEPARTMENT (name, company_code, parent_id)
values ('IM', 'inspire', @CASINO_ID),
       ('JM', 'inspire', @CASINO_ID),
       ('CASINO CLUB', 'inspire', @CASINO_ID);

select * from DEPARTMENT where parent_id = @CASINO_ID;

# commit;
rollback;
```

## 기타

** 운영계 배포 전 신규 권한으로 추가된 부분에 대해서 권한 처리 필요 → 인스파이어 임원 명단 전달 필요

- 2602 - 인스파이어 당일 예약 검증에 KST 변환이 누락되어 `당일` 표시 누락되는 문제 발생
수정 후 재배포 진행 (관련 커밋 `3fc71d04`)

## 백로그
