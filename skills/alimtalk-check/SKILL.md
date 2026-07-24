---
name: alimtalk-check
description: >-
  lane4-notification-api의 카카오 알림톡(AlimTalk)을 코드 기반으로 조회·검증·미리보기하는 전용 스킬.
  "노쇼 알림톡 누구한테 가?", "KE 예약취소 문구 뭐야?", "차량도착 안내는 어떤 템플릿 코드?",
  "이 알림톡 템플릿 배포 전에 확인해줘", "ALLOCATION_SUCCESS 알림톡 미리보기", "companyCode 분기 맞는지 봐줘"
  같은 요청에 사용한다. 알림톡 관련 taskType·템플릿코드·수신자·발송상황·companyCode(ke/ssgdfs) 분기를
  묻거나, 알림톡 TS 템플릿 클래스를 배포 전 검증하거나, 특정 상황에 어떤 알림톡이 나갈지 시뮬레이션할 때
  반드시 이 스킬을 사용한다. 사용자가 "알림톡"을 명시하지 않아도 예약확정/취소/노쇼/차량도착/대기안내/탑승/
  기사출발 등 lane4 배차 알림 문구·수신자·발송조건을 확인하려는 맥락이면 적극 트리거한다.
  단, 실제 발송 여부(발송 이력 DB/로그) 조회는 이 스킬 범위가 아니다(그건 lane4-mysql/log-search).
---

# 알림톡 확인 (alimtalk-check)

lane4-notification-api의 카카오 알림톡을 **코드 기반으로** 조회·검증·미리보기한다. 세 가지 모드로 동작하며, 사용자 요청에 따라 하나 이상을 수행한다.

## 먼저 알아야 할 3가지 사실 (오답의 90%가 여기서 나옴)

1. **이 프로젝트는 알림톡을 실제로 발송하지 않는다.** notification-api는 `POST /template`으로 taskType을 받아 **템플릿을 조립·렌더링해 payload를 반환하고 히스토리를 저장**할 뿐이다. 실제 카카오 비즈메시지 발송은 **lane4-notification-server(Aligo)**가 한다. 그래서 "이 알림톡 진짜 나갔어?"류 질문은 이 스킬 범위 밖이다 — 발송 이력은 `notification_history` 테이블(lane4-mysql)이나 log-search로 안내한다.

2. **알림톡 본문은 EJS가 아니라 TypeScript 클래스다.** `.addLine('...')` 체이닝으로 본문을 쌓는다. 위치는 `src/domains/provider/kakao-notification/`. 반면 `src/templates/*.ejs`는 **메일 전용**이다. 최근 커밋의 "ejs 포맷 수정"은 전부 메일이지 알림톡이 아니다 — 절대 혼동하지 말 것. 알림톡을 물으면 TS 클래스를 봐야 한다.

3. **한 taskType은 보통 여러 채널·여러 알림톡을 동시에 건다.** 예: `RESERVATION_SUCCESS` = SLACK + 알림톡×2(수신인용 + 호출자URL용) + Cafe24 SMS. 수신자/조건이 안 맞는 템플릿은 `shouldSkip()`(receiver·message·subject 모두 비면 true)으로 자동 탈락한다. "누구한테 가냐"는 질문은 이 조건까지 봐야 정확하다.

## 진입점 파일 지도

| 무엇 | 경로 |
|------|------|
| 알림톡 템플릿 코드 레지스트리 (Aligo tpl_code) | `src/commons/constant/alimtalk.template.code.ts` |
| **taskType → provider·템플릿 매핑 (마스터)** | `src/domains/template/application/task.template.mapper.ts` |
| 알림톡 템플릿 클래스 (본문 `.addLine`) | `src/domains/provider/kakao-notification/**` |
| 알림톡 베이스 클래스 (`addLine`/`shouldSkip`/`copyFrom`/failover) | `src/domains/provider/kakao-notification/kakao-notification.template.ts` |
| 수신자(전화번호) 결정 메서드 | `src/domains/allocation/domain/allocation.entity.ts` |
| 리소스(배차·고객·기사) 로더 | `src/domains/resource/application/*.resource.finder.ts` |
| 채널 enum | `src/commons/enum/provider.type.ts` (`KAKAO_NOTIFICATION`) |
| 수신자 유형 enum | `src/domains/notification/domain/client.type.ts` (CALLER/SMS_RECEIVER/MANAGER/PASSENGER) |

빠른 진입점으로 **`references/alimtalk-catalog.md`** (템플릿코드↔taskType↔수신자↔발송상황↔companyCode분기 표)를 먼저 읽되, **최종 답변 전에는 반드시 위 소스 파일의 실제 코드(file:line)로 재확인**한다. 카탈로그는 낡을 수 있으므로 근거가 아니라 목차다.

## 모드 1 — 레퍼런스 조회

"노쇼 알림톡 누구한테 가?", "KE 예약취소 문구 뭐야?", "차량도착 안내 템플릿 코드?" 같은 질문.

절차:
1. `references/alimtalk-catalog.md`에서 관련 taskType/템플릿코드/수신자 후보를 찾는다.
2. `task.template.mapper.ts`에서 해당 taskType의 `providerTemplates` 배열을 열어 **실제로 걸린 알림톡 클래스**를 확인한다(`ProviderType.KAKAO_NOTIFICATION`만).
3. 각 알림톡 클래스 파일을 열어 ① `tpl_code`, ② `.addLine()` 본문/제목, ③ `addReceiversWithSameMessage()`에 넣는 수신자 그룹, ④ companyCode 분기가 있으면 분기별 결과를 읽는다.
4. 답변에 **taskType · 템플릿코드(tpl_code) · 수신자그룹 · 발송상황 · companyCode 분기 · file:line 근거**를 함께 제시한다. 여러 알림톡이 걸리면(수신인용/호출자용 등) 각각 구분해 답한다.

## 모드 2 — 템플릿 내용/포맷 검증 (배포 전)

변경된 알림톡 TS 클래스를 배포 전에 점검한다. `git diff`(또는 사용자가 지목한 파일)로 변경된 `kakao-notification/**` 파일을 대상으로 아래를 확인:

1. **본문 변수 바인딩** — `.addLine(\`...${resource.xxx}...\`)`의 참조가 해당 resource 타입에 실제 존재하는 필드인지. 오타·undefined·빈 값으로 문구가 깨지지 않는지.
2. **템플릿 코드 일치** — `tpl_code`가 `alimtalk.template.code.ts`의 상수와 맞는지. 카카오 비즈메시지는 **승인된 템플릿 코드·본문과 글자 단위로 일치**해야 발송되므로, 본문 문구를 바꿨다면 "카카오 승인 템플릿도 함께 수정됐는지" 반드시 사용자에게 확인 요청한다(코드만 바꾸면 실발송 시 반려된다).
3. **companyCode(ke/ssgdfs) 분기 양방향 검증** — 이게 이 스킬의 1순위 방어 지점이다. 아래 별도 섹션 참조.
4. **수신자 그룹 누락** — `addReceiversWithSameMessage()`에 올바른 mobile 그룹(탑승자/수신인/호출자/담당자)을 넣는지. 빈 배열이면 `shouldSkip()`으로 통째로 탈락해 **아무한테도 안 가는** 사고가 난다.
5. **failover 설정** — SMS 대체발송이 필요한 템플릿에 `setFailOver(true)`가 있는지(단 emirates 계열은 의도적으로 비활성일 수 있음 — 함부로 켜지 말 것).
6. **realtime wrapper 위임** — realtime 계열은 `isRealtimeReservation()`이면 빈 템플릿으로 skip, 아니면 실제 템플릿에 위임하는 패턴. 조건 반전 시 실시간/일반이 뒤바뀐다.

검증 결과는 **대화형으로 즉답**한다(리포트 파일 생성하지 않음). 문제가 있으면 file:line + 왜 문제인지 + 고칠 방향을 제시한다.

### companyCode 분기 양방향 검증 (필수)

알림톡 클래스는 흔히 `getRealTemplate()`에서 companyCode로 실제 템플릿을 갈아끼운다:

```ts
private getRealTemplate(resource): KakaoNotificationTemplate {
  const { allocation } = resource;
  if (['ke', 'ssgdfs'].includes(allocation.getCompanyCode())) {
    return new AssignSuccessUrlIncludedKeKakaoTemplate();   // KE/신세계 전용
  }
  return new AssignSuccessBaseKakaoTemplate();               // 그 외 일반
}
```

이 분기는 **과거 조건 반전으로 KE 전용 템플릿이 일반에게 나가고 일반용이 KE에 나간 사고**가 실제로 발생한 지점이다. 그래서 한 방향만 보고 "맞다"고 하면 안 된다. **반드시 양방향으로 검증**한다:

- companyCode가 `ke`(또는 `ssgdfs`)일 때 → 정말 KE 전용 템플릿이 선택되는가?
- companyCode가 그 외일 때 → 정말 일반 템플릿이 선택되는가?
- 조건의 `includes` 대상 목록(`['ke','ssgdfs']`)과 반환 템플릿의 **네이밍이 실제 용도와 일치**하는가? (파일명에 `.ke.`가 붙은 클래스가 KE 분기에서 반환되는지 등)
- 최근 커밋이 "ssgdfs 확대"/"KE 전용"처럼 **분기 대상을 넓히거나 좁힌** 변경이면, 넓힌/좁힌 방향이 의도와 맞는지 diff로 확인한다.

정정·수정을 한 직후에는 **속도를 늦추고** 방금 바꾼 분기를 다시 양방향으로 읽어 확인한 뒤 보고한다.

## 모드 3 — 발송 시뮬레이션 / 미리보기

"ALLOCATION_SUCCESS가 KE 법인이면 어떤 알림톡 나가?", "keyIndex 12345로 예약취소 알림톡 미리보기" 같은 요청.

절차:
1. `task.template.mapper.ts`에서 taskType의 `providerTemplates`를 열어 **provider 조합과 알림톡 클래스 목록**을 파악한다.
2. 각 알림톡 클래스의 `getRealTemplate()`/조건 분기를 companyCode·realtime 등 입력 조건에 따라 **어느 실제 템플릿으로 귀결되는지** 추적한다.
3. `shouldSkip()` / realtime wrapper / self-boarding(`isSelfBoarding()`) 조건으로 **탈락하는 템플릿**을 표시한다. 최종적으로 "이 상황에선 알림톡 N개가 이러이러한 수신자에게 나간다"를 정리한다.
4. **본문 변수값 채우기** — 두 경로 지원:
   - **keyIndex가 주어지면**: lane4-mysql 스킬로 해당 배차/콜리퀘스트/고객/기사/법인/차량 데이터를 **조회 전용**으로 읽어 실제 값으로 `.addLine()` 본문을 렌더링한다. (발송 이력이 아니라 렌더링 입력 데이터를 읽는 것 — 스코프 내)
   - **keyIndex가 없으면**: 대표 샘플값(예: 탑승자명·차량모델·안심번호·일시)을 넣어 **문구 구조**를 보여준다. "샘플 데이터 기반 미리보기"임을 명시한다.
5. 결과를 대화형으로 제시: taskType → 채널 조합 → 선택된 알림톡 클래스(tpl_code) → 수신자 → 렌더링된 본문 미리보기 → 탈락 항목.

> 시뮬레이션은 **정적 추적**이다. 앱을 실행하거나 실제 발송하지 않는다. resource finder의 fallback 로직(예: passenger→passengerTel→caller 순)까지 반영하면 더 정확하다.

## 범위 밖 (명확히 안내)

- **실제 발송 여부/이력 조회** — `notification_history` DB(lane4-mysql) 또는 log-search 소관. 이 스킬은 안 함.
- **실제 벤더 발송·재발송** — lane4-notification-server(Aligo) 소관.
- **메일/SMS/푸시/슬랙 전용 조회** — 알림톡과 얽힌 부분(failover SMS, 같은 taskType의 병행 채널)만 언급. 채널 전용 심층 조회는 알림 도메인 문서(`~/IdeaProjects/lane4-docs/domains/notification/`) 참조.

이런 요청이 오면 무엇을 대신 써야 하는지 짧게 안내하고, 알림톡 범위 내에서 도울 수 있는 부분을 제시한다.

## 크로스 프로젝트 (누가 트리거하나)

"이 알림톡 어디서 보내는 거야?"처럼 **트리거하는 프로듀서**를 물으면, 트리거는 이 프로젝트가 아니라 각 백엔드(guest-api/app-api/partner-api/admin-api/driver-api/scheduler 등)가 `NotificationUtils.notify(taskType, keyIndex)`로 RabbitMQ에 적재해 발생한다. 프로젝트별 트리거 종합은 `~/IdeaProjects/lane4-docs/domains/notification/cross-project.md`, 전체 카탈로그는 같은 폴더 `notification-catalog.md` 참조.
