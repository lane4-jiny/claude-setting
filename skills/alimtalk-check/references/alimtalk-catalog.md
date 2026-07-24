# 알림톡 카탈로그 (진입점 / 목차)

> **이건 근거가 아니라 목차다.** 여기서 후보를 빠르게 찾되, 최종 답변 전에는 반드시
> `task.template.mapper.ts`와 해당 알림톡 클래스의 **실제 코드(file:line)**로 재확인한다.
> 코드가 바뀌면 이 표는 낡는다. (기준 소스: lane4-notification-api, 2026-07 시점)

## 목차
- [1. 알림톡 템플릿 코드 레지스트리](#1-알림톡-템플릿-코드-레지스트리)
- [2. taskType별 알림톡 발송 (상황·수신자·템플릿)](#2-tasktype별-알림톡-발송)
- [3. 수신자 그룹 메서드 (전화번호 소스)](#3-수신자-그룹-메서드)
- [4. companyCode 분기 패턴](#4-companycode-분기-패턴)
- [5. 자주 헷갈리는 것](#5-자주-헷갈리는-것)

---

## 1. 알림톡 템플릿 코드 레지스트리

`src/commons/constant/alimtalk.template.code.ts` — Aligo 카카오 비즈메시지 `tpl_code` 단일 소스.

| 상수 | tpl_code | 용도 |
|------|----------|------|
| RESERVATION_SUCCESS_ONE_WAY | `TX_5494` | 예약접수 편도 (탑승자·수신인용) |
| RESERVATION_SUCCESS_ONE_WAY_URL_INCLUDED | `TX_5193` | 예약접수 편도 (호출자용, URL포함) |
| RESERVATION_SUCCESS_TWO_WAY | `TX_5197` | 예약접수 왕복 |
| RESERVATION_SUCCESS_TWO_WAY_URL_INCLUDED | `TX_5196` | 예약접수 왕복 (호출자 URL) |
| RESERVATION_SUCCESS_KE | `UE_2624` | 예약접수 KE(대한항공) 법인 전용 |
| RESERVATION_SUCCESS_GUEST_AIR | `UJ_0359` | 예약접수 게스트 항공 |
| RESERVATION_CANCEL_KE | `UE_2965` | 예약취소 KE |
| RESERVATION_REMINDER_ONE_WAY / _URL_INCLUDED | `TY_0197` / `TY_0196` | 리마인더 편도 (수신인 / 호출자) |
| RESERVATION_REMINDER_TWO_WAY / _URL_INCLUDED | `TY_0199` / `TY_0198` | 리마인더 왕복 |
| RESERVATION_CANCELLED_ONE_WAY / _URL_INCLUDED | `TV_4590` / `TV_4596` | 예약취소 편도 (수신인 / 호출자) |
| RESERVATION_CANCELLED_TWO_WAY / _URL_INCLUDED | `TX_5199` / `TX_5198` | 예약취소 왕복 |
| DRIVER_AND_CAR_ASSIGNED / _URL_INCLUDED | `TP_9106` / `TV_4594` | 배차완료(탑승안내) (수신인 / 호출자) |
| DRIVER_AND_CAR_ASSIGNED_URL_INCLUDED_KE_DEPARTURE | `UE_1846` | 배차완료 KE 출발지 |
| DRIVER_AND_CAR_NOT_ASSIGNED | `TT_3518` | 미배차/배정전 안내 |
| DRIVER_DEPART / _URL_INCLUDED | `TQ_0810` / `TV_4595` | 기사출발(차량이동) (수신인 / 호출자) |
| DRIVER_DEPART_KE / _KE_ARRIVAL | `UE_1847` / `UE_1848` | 기사출발/도착 KE |
| ARRIVAL_AT_DEPARTURE | `TP_9109` | 출발지 도착(차량도착) |
| PASSENGER_BOARDING / _KE | `TP_9110` / `UE_1845` | 탑승 (일반 / KE) |
| DRIVING_COMPLETED | `TP_9111` | 운행완료 |
| PASSENGER_NO_SHOW | `TP_9112` | 미탑승(노쇼) |
| RESERVATION_NO_SHOW_NOTICE | `UE_2966` | 대기안내(회차) — 제목 `[LANE4 대기안내]` |
| RESERVATION_NO_SHOW_CANCELED | `UE_2967` | 노쇼 취소 |
| AIRLINE_DRIVER_NEAR_ARRIVAL | `UE_1851` | 기사 근접 도착 |
| AIRLINE_DRIVER_SPOT_PASSED_KE | `UF_1334` | KE 기사 스팟 통과 |
| AIRLINE_ARRIVAL_AT_DEPARTURE | `UD_6217` | 항공 출발지 도착 |
| SEND_SURVEY_REQUEST_SMS | `UA_0163` | 만족도 설문 요청 |
| DMT_RESERVATION_SUCCESS / _REMINDER | `UC_7750` / `UC_6190` | DMT셔틀 예약 / 리마인더 |
| DMT_SURVEY_REQUEST_INCHEONINNO | `UC_3238` | DMT 설문(인천이노) |
| REAL_TIME_CALL_SUCCESS | `TQ_0827` | 실시간콜 성공 |
| REALTIME_RESERVATION_SUCCESS | `UG_9714` | 실시간 예약성공 |
| REALTIME_DRIVER_DEPART | `UH_0219` | 실시간 기사출발 (소스에 `TODO 검수 후 수정 필요` 주석) |
| REALTIME_ARRIVAL_AT_DEPARTURE | `UH_0234` | 실시간 출발지도착 |
| REALTIME_RESERVATION_CANCELLED | `UH_0236` | 실시간 예약취소 |
| REALTIME_PASSENGER_NO_SHOW | `UH_0239` | 실시간 미탑승 |

**미연결(레거시 의심) — taskType에 미등록, 클래스/상수만 존재:**
`AIRLINE_REQUEST_INPUT_BAGGAGE`(`UE_0178`), `AIRLINE_REQUEST_PAYMENT`(`UE_0177`), `AIRLINE_REQUEST_CHECK_RESERVATION`(`UE_0179`), `AIRLINE_ARRIVAL_AT_DEPARTURE`(`UD_6217`), `REAL_TIME_CALL_SUCCESS`(`TQ_0827`).
→ 이들은 `task.template.mapper.ts`에 직접 등록돼 있지 않다. 다른 템플릿 내부에서만 참조되거나 사용 안 됨. 답변 시 "현재 taskType 미연결" 명시.

---

## 2. taskType별 알림톡 발송

`src/domains/template/application/task.template.mapper.ts`. 아래는 **알림톡(KAKAO_NOTIFICATION)이 걸린 taskType만** 추림. 각 taskType엔 SLACK/MAIL/SMS/CAFE24_SMS가 함께 붙기도 함(병행 채널). 라인은 참고용 근사치이므로 **실제 답변 전 mapper에서 재확인**.

| taskType | 발송 상황 | 알림톡 (수신자용도) | 병행 채널 |
|----------|----------|--------------------|----------|
| RESERVATION_SUCCESS / _TWO_WAY | 예약 접수(편도/왕복) | ×2: 수신인용 + 호출자용(URL) | SLACK, Cafe24 SMS |
| RESERVATION_SUCCESS_KE | KE 예약 접수 | KE 법인 전용(`UE_2624`) | MAIL(영문) |
| RESERVATION_SUCCESS_GUEST_AIR | 게스트 항공 예약 | 게스트 항공(`UJ_0359`) | — |
| RESERVATION_SUCCESS_GIFT_CARD | 기프트카드 예약 | 호출자용(URL, 기프트카드 variant) | SLACK |
| RESERVATION_REMINDER / _TWO_WAY | 탑승 전 리마인더 | ×2: 수신인 + 호출자(URL) | — |
| DRIVER_AND_CAR_NOT_ASSIGNED | 배정 전 안내 | 수신인(`TT_3518`) | — |
| ALLOCATION_SUCCESS | 차량/기사 배정완료(탑승안내) | ×2: 수신인 + 호출자(URL), KE분기 | MAIL(KE), Cafe24 SMS |
| DRIVER_DEPART | 기사 출발(상태 10) | ×2: 수신인 + 호출자(URL), realtime wrapper | — |
| ARRIVAL_AT_DEPARTURE | 출발지 도착(상태 20, 차량도착) | 수신인, realtime wrapper | MAIL(KE) |
| PASSENGER_BOARDING | 탑승(상태 30) | ×2: 일반 + KE | — |
| PASSENGER_NO_SHOW | 미탑승(상태 50N) | ×2: 미탑승 + 노쇼취소, realtime wrapper | MAIL(외국인) |
| DRIVING_COMPLETED | 운행 완료(상태 50) | 수신인(`TP_9111`) | — |
| CANCEL_RESERVATION / _TWO_WAY | 예약 취소 | ×2: 수신인 + 호출자(URL), realtime wrapper | (MAIL KE), Cafe24 SMS |
| RESERVATION_NO_SHOW_NOTICE | 대기 안내(회차) | 수신인(`UE_2966`) | MAIL |
| AIRLINE_DRIVER_ARRIVAL_LOCAL | 항공 기사도착(내국인) | 내국인 탑승자(`UD_6217`) | MAIL |
| AIRLINE_REMINDER_LOCAL | 항공 리마인더(내국인) | 내국인 | MAIL |
| AIRLINE_DRIVER_NEAR_ARRIVAL | 기사 근접 도착 | 탑승자(`UE_1851`) | — |
| AIRLINE_DRIVER_SPOT_PASSED_KE | KE 스팟 통과 | 탑승자(`UF_1334`) | — |
| SEND_SURVEY_REQUEST_SMS | 만족도 설문 | 탑승자(`UA_0163`) | — |
| DMT_RESERVATION_SUCCESS / _REMINDER / DMT_SURVEY_REQUEST | DMT셔틀 예약/리마인더/설문 | 탑승자(`UC_*`) | — |

> `AIRLINE_*_FOREIGNER` 계열은 알림톡 없이 **메일 전용**(외국인). 알림톡은 내국인(`_LOCAL`)만.

---

## 3. 수신자 그룹 메서드

전화번호는 **배차(Allocation) 엔티티**에서 조회. `src/domains/allocation/domain/allocation.entity.ts`.

| 메서드 | 대상 |
|--------|------|
| `getCallerMobile()` | 호출자 |
| `getPassengerMobile()` | 탑승자 (passenger → callRequest.passengerTel → caller 순 fallback) |
| `getReceiverMobilesForKakao()` | 수신인 |
| `getActivatedPassengerAndReceiverMobilesForKakao()` | 탑승자 + 수신인 |
| `getActivatedManagerMobilesForKakao()` | 법인 담당자(매니저) |
| `getActivatedCallerAndEmployeeMobilesForKakao()` | 호출자 + 법인직원 |
| `getActivatedPassengerAndCallerMobilesForKakao()` | 탑승자 + 호출자 |
| `isSelfBoarding()` | 본인탑승 여부(true면 탑승자용 알림 생략) |
| `isForeigner()` / `hasCaller()` | 외국인/호출자 존재 여부 분기 |

수신자 유형 enum: `src/domains/notification/domain/client.type.ts` — `CALLER`, `SMS_RECEIVER`, `MANAGER`, `PASSENGER`.

각 알림톡 클래스가 `addReceiversWithSameMessage([...mobiles])`에 어떤 그룹을 넣느냐로 수신 대상 결정. 빈 배열이면 `shouldSkip()`으로 통째 탈락 → **아무한테도 안 감**.

---

## 4. companyCode 분기 패턴

알림톡 클래스는 `getRealTemplate(resource)`에서 companyCode로 실제 템플릿을 갈아끼운다. 대표 예 (`src/domains/provider/kakao-notification/allocation/assign-success.kakao.template.ts:19-27`):

```ts
if (['ke', 'ssgdfs'].includes(allocation.getCompanyCode())) {
  return new AssignSuccessUrlIncludedKeKakaoTemplate();  // ke=대한항공, ssgdfs=신세계DF 전용
}
return new AssignSuccessBaseKakaoTemplate();             // 그 외 일반
```

- `ke` = 대한항공, `ssgdfs` = 신세계디에프.
- **이 분기가 과거 조건 반전 사고가 난 지점.** 검증 시 반드시 양방향으로 확인(모드 2의 companyCode 섹션 참조).
- 최근 커밋에 "ssgdfs 확대", "KE 전용", "외국인 호출자 SSGDFS 확대" 같은 게 있으면 분기 대상 목록(`['ke','ssgdfs']`)이 넓어지거나 좁아진 것 → diff로 방향 확인.

---

## 5. 자주 헷갈리는 것

- **알림톡 본문 = TS 클래스(`.addLine`)**, `.ejs`는 메일 전용. "ejs 포맷 수정" 커밋은 알림톡 아님.
- **notification-api는 발송 안 함** — 렌더링·히스토리 저장만. 실발송은 notification-server(Aligo).
- **기사(driver)에겐 알림톡이 아니라 PUSH.** 기사 이름·안심번호는 알림톡 *본문*에 들어갈 뿐 수신자는 승객/호출자.
- **한 taskType = 여러 알림톡**(수신인용 + 호출자URL용) + 여러 채널. 조건 안 맞으면 `shouldSkip`/realtime wrapper로 탈락.
- **failover** = 알림톡 실패 시 SMS 대체발송(`setFailOver(true)`, `failover='Y'`). emirates 계열은 의도적 비활성일 수 있음.
- **환경 가드 주의(참고)**: notification-server에서 SMS/메일/슬랙은 dev 미발송이지만 **알림톡은 환경 가드가 주석 처리**돼 dev에서도 실발송될 수 있음(`kakao-alim.notifier.ts` — notification-server 레포).
