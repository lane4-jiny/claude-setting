# API 문서 출력 템플릿

아래 형식에 맞춰 API 문서를 생성한다.

## 구조 규칙

- 최상위: `## {모듈명}` (예: `## gift-cards`, `## points`)
- 엔드포인트별: `### {엔드포인트 설명}` (예: `### 기프트카드 목록 조회`)
- 전달하는 값이 없는 섹션은 생략한다 (Query/Path/Request Body 등)
- interface는 토글(접기)로 제공한다. 단순한 응답은 생략 가능하다.

## 엔드포인트 템플릿

---

### {엔드포인트 설명}

**Base**

```
Method  :  {GET/POST/PUT/PATCH/DELETE}
Endpoint: {path}
```

**Path Parameters** _(있는 경우에만)_

```json
{paramName}: {type}
```

**Query Parameters** _(있는 경우에만)_

```
{paramName}: {type}
{paramName}?: {type} // 선택값 설명
```

**Headers**

| Key | Value |
| --- | --- |
| x-guest-authorization | {guestToken} |

**Request Body** _(있는 경우에만)_

```json
{
    "field": "value"
}
```

**Response Body**

```json
{
    "result": true,
    "code": null,
    "data": { }
}
```

- interface _(토글, 복잡한 응답인 경우에만)_

    ```tsx
    export class ResponseClassName {
      field: type;
    }
    ```

**Exceptions**

| StatusCode | Cause | Message |
| --- | --- | --- |
| 401 | 원인 설명 | 에러 메시지 |
