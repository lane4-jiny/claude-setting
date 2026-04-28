---
name: api-docs
description: NestJS 컨트롤러/DTO를 분석하여 API 문서를 마크다운으로 자동 생성. 사용자가 "API 문서", "api-docs", "문서 생성", "엔드포인트 정리" 등을 요청할 때 사용.
---

# API Docs

NestJS 컨트롤러와 DTO를 읽어서 API 문서를 마크다운으로 자동 생성한다.

## 핵심 제약사항

- 코드를 수정하지 않는다. 문서 생성만 수행한다.
- 추측으로 문서를 작성하지 않는다. 코드에서 확인된 정보만 기록한다.
- Guard, Decorator, DTO 등 실제 코드 기반으로 정확한 정보를 추출한다.
- 출력 형식은 `references/doc-template.md`를 따른다.

## 추출 대상

| 항목 | 소스 | 설명 |
|------|------|------|
| Method & Path | `@Get`, `@Post`, `@Put`, `@Delete`, `@Patch` | HTTP 메서드와 경로 |
| Guard | `@UseGuards(...)` | 인증/인가 Guard |
| Decorator | 커스텀 데코레이터 (`@CurrentUser` 등) | 파라미터 데코레이터 |
| Request DTO | `@Body()`, `@Query()`, `@Param()` | 요청 파라미터 |
| Response DTO | 리턴 타입, `@ApiResponse` | 응답 형식 |
| Description | `@ApiOperation`, 주석 | 엔드포인트 설명 |

## 워크플로우

1. 사용자가 대상 프로젝트 또는 모듈 지정 (미지정시 확인)
2. 해당 경로에서 `*.controller.ts` 파일 스캔
3. 각 컨트롤러에서 엔드포인트별 정보 추출:
   - HTTP Method, Path (Controller prefix + Method path)
   - UseGuards, 커스텀 Decorator
   - Request DTO (Body, Query, Param) → DTO 클래스 읽어서 필드 추출
   - Response DTO → 리턴 타입 추적하여 필드 추출
4. `references/doc-template.md` 형식에 맞춰 마크다운 문서 출력
5. 사용자에게 결과 전달 (파일 저장 여부 확인)

## 참조 문서

| 문서 | 용도 | 언제 읽는가 |
|------|------|-----------|
| `references/doc-template.md` | API 문서 출력 템플릿 | 문서 생성 시 출력 형식을 결정할 때 |
