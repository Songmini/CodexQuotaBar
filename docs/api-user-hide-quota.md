# API 사용자에게는 사용량 숨기기

## 배경

`CodexUsage`는 Codex app-server의 `account/rateLimits/read` 응답을 읽어 메뉴바와 floating 패널에 1주/5시간 잔여 쿼터를 표시한다. 그런데 이 쿼터는 ChatGPT 플랜 사용자에게만 적용되고, API 키로만 Codex를 쓰는 사용자에게는 의미가 없다. API 사용자에게는 게이지/퍼센트를 숨기고 안내만 보여주도록 변경했다.

## 감지 방식

응답 기반 휴리스틱으로 처리한다. `account/rateLimits/read` 응답에서 `primary`와 `secondary` 윈도우가 모두 `null`(또는 누락)이면 API 전용 사용자로 간주한다.

`auth/status` 같은 별도 endpoint를 쓰는 안도 검토했으나, 해당 메서드가 실제로 노출되는지 확인이 필요해서 보류. 지금 방식은 Codex 측 응답 스키마가 바뀌면 깨질 수 있다는 트레이드오프를 안고 있다.

## 변경 내역

### Core (`Sources/CodexUsageCore`)

- `CodexAppServerQuotaDecoder.decodeOutcome(from:readAt:)` 신설 — `CodexAppServerQuotaOutcome` (`.snapshot` / `.notApplicable`)을 반환.
  - `primary == nil && secondary == nil` 이면 `.notApplicable`.
  - 한쪽만 누락되면 기존처럼 `DecodingError.valueNotFound` throw.
- 기존 `decodeSnapshot(from:readAt:)`은 호환을 위해 유지하되 `.notApplicable`이면 throw.
- `QuotaReadResult`에 `.notApplicable` 케이스 추가. `snapshotForDisplay`는 `.idle`과 동일하게 `nil`.
- `QuotaStatusFormatter.menuBarTitle` — `.notApplicable`이면 빈 문자열.
- `QuotaCompactPanelFormatter.rows` — `.notApplicable`이면 빈 배열.

### App (`Sources/CodexUsage`)

- `CodexAppServerQuotaReader.readSnapshot()` 반환 타입을 `Result<CodexAppServerQuotaOutcome, QuotaReadError>`로 변경.
- `QuotaController` — reader outcome을 `QuotaReadResult`로 매핑하면서 `.notApplicable`도 그대로 전달.
- `StatusIconRenderer`
  - `.notApplicable`이면 게이지 호 없이 Codex 코드 마크(`< >`)만 그림.
  - `drawCodeOnlyMark(in:primaryColor:)` 헬퍼 추가.
- `StatusItemController.toolTip` — `.notApplicable`일 때 `"Codex Usage is only available for ChatGPT plans"`.
- `QuotaPanelView` (full 모드)
  - 두 quota 행을 숨기고 상태 라벨에 `"Usage limits apply to ChatGPT plans only."` 표시.
  - `setRowsHidden(_:)` 헬퍼 추가.
- `CompactQuotaPanelView`
  - `notApplicableLabel` 추가. `.notApplicable`이면 두 행 숨기고 `"ChatGPT plan only"` 단일 라벨.

### 테스트 (`Tests/CodexUsageCoreTests`)

추가된 테스트:

- `testDecodeOutcomeReturnsNotApplicableForApiOnlyUser` — `primary`/`secondary`가 `null`인 응답에서 `.notApplicable` 반환 확인.
- `testStatusTitleIsEmptyForNotApplicable` — 메뉴바 타이틀이 빈 문자열인지.
- `testCompactPanelRowsAreEmptyForNotApplicable` — compact 패널 rows가 빈 배열인지.

## 검증

```bash
swift build
swift test
```

19/19 테스트 통과.

## 동작 정리

| 상태 | 메뉴바 아이콘 | 메뉴바 타이틀 | Tooltip | Floating 패널 |
|------|---------------|---------------|---------|---------------|
| `.idle` | 빈 게이지 | `1w --` | "has not been read yet" | placeholder 행 |
| `.success` | 색상 게이지 | `1w NN%` | `1-week NN% remaining` | 5h / 1w 행 |
| `.notApplicable` | 코드 마크만 | (빈 문자열) | `ChatGPT plans only` 안내 | 안내 라벨, 행 숨김 |
| `.failure` (last 있음) | 마지막 게이지 | `1w NN%` | `error … Last NN%` | 마지막 값 + 에러 |
| `.failure` (last 없음) | 빈 게이지 | `1w !` | `error.message` | placeholder + 에러 |

## 후속 고려 사항

- `account/rateLimits/read`가 `error` 응답을 주는 경우(현재 `.failure(.quotaNotFound)`로 떨어짐)도 사용 환경에 따라 `.notApplicable`로 라우팅하는 게 더 자연스러울 수 있다. 실제 API 사용자 환경에서 응답을 한 번 확인 후 분기 보강.
- Codex 응답 스키마가 바뀌어 `primary`/`secondary`가 다른 경로로 들어오면 감지가 깨진다. 향후 `auth/status`나 plan/subscription 정보가 별도로 노출되면 그쪽으로 판정 기준을 옮기는 게 견고하다.
