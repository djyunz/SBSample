# 변경사항 요약 (2025-09-17)

## 1. WKWebView 파일 다운로드 기능 추가 (Commit: `09749a1`)

- `WKWebView`에서 다운로드 링크를 감지하여 파일을 다운로드하는 초기 기능을 구현했습니다.
- `FileDownloadService`, `FileDownloadViewModel`, `FileDownloadView`를 추가하여 단일 파일 다운로드 및 진행률 표시 기능을 구현했습니다.
- `SnapKit` 라이브러리를 추가하고, `ViewController`에 `SwiftUIView`, `HeartRateView` 등 여러 SwiftUI 뷰를 통합했습니다.

## 2. 동시 다운로드를 위한 리팩토링 (Commit: `5b97ca0`)

### 대화 내용 요약

- **문제 제기:** 기존 코드가 한 번에 하나의 파일만 다운로드할 수 있는 문제를 해결하고, 여러 파일을 동시에 다운로드할 수 있도록 수정을 요청했습니다.
- **해결 과정:**
    1.  각 다운로드의 상태를 독립적으로 추적하는 `DownloadItem.swift` 모델을 새로 생성했습니다.
    2.  `FileDownloadService`가 `taskIdentifier`를 키로 사용하여 여러 다운로드 작업을 동시에 관리하도록 딕셔너리 기반으로 수정했습니다.
    3.  `FileDownloadViewModel`이 `DownloadItem` 객체의 배열을 관리하도록 리팩토링했습니다.
    4.  `FileDownloadView`가 다운로드 목록 전체를 표시하도록 UI를 수정했습니다.
- **추가 수정:**
    - **빌드 오류 해결:** `ViewController`와 `FileDownloadView` 간의 잘못된 데이터 흐름으로 인해 발생한 빌드 오류를 수정했습니다. `ViewController`가 `ViewModel`을 소유하고, 이를 `FileDownloadView`에 주입하는 방식으로 구조를 개선하여 문제를 해결했습니다.
    - **샘플 URL 수정:** 작동하지 않는 샘플 다운로드 URL을 실제 다운로드 가능한 이미지 파일 URL로 교체했습니다.

### 주요 코드 변경사항

- **`DownloadItem.swift` (신규):**
  - `id`, `url`, `progress`, `state`, `localFileLocation` 등을 포함하는 `ObservableObject`로, 각 다운로드 항목의 상태를 관리합니다.

- **`FileDownloadService.swift` (리팩토링):**
  - 단일 `streamContinuation` 대신 `[Int: Continuation]` 딕셔너리를 사용하여 여러 다운로드 작업을 동시에 처리합니다.

- **`FileDownloadViewModel.swift` (리팩토링):**
  - 단일 진행률(`progress`) 대신 `@Published var downloadItems: [DownloadItem]` 배열을 사용하여 여러 다운로드 상태를 관리합니다.

- **`FileDownloadView.swift` (리팩토링):**
  - `@StateObject`로 자체 생성하던 `ViewModel`을, 상위 뷰로부터 주입받는 `@ObservedObject`로 변경했습니다.
  - UI가 단일 진행률 대신 다운로드 목록(`List`)을 표시하도록 변경되었습니다.

- **`ViewController.swift` (리팩토링):**
  - `FileDownloadViewModel`의 인스턴스를 직접 생성하고 소유합니다.
  - `viewDidLoad`에서 `FileDownloadView`를 초기화할 때 이 `ViewModel`을 전달합니다.
  - `WKNavigationDelegate`에서 `ViewModel`의 `startDownload` 메서드를 직접 호출하여 데이터 흐름을 단순화하고 안정성을 높였습니다.

## 3. 경고 수정 및 다운로드 검증 로직 강화

### `WKProcessPool` Deprecation 경고 해결 (Commit: `06bf2c3`)

- **문제 제기:** `WKProcessPool`이 iOS 15.0부터 deprecated 되었다는 경고가 발생했습니다.
- **해결:** `ViewController.swift`에서 불필해진 `WKProcessPool` 인스턴스 생성 코드를 제거하여 경고를 해결했습니다.

### 다운로드 실패 케이스 처리 강화 (Commit: `99d9615`)

- **문제 제기:** 존재하지 않는 URL로 다운로드 시도 시, 서버가 404 에러 페이지(HTML)를 정상적으로 응답하면 다운로드가 '성공'으로 처리되는 문제를 지적했습니다. 또한, `Content-Type` 검사를 옵션으로 두고 다른 검증 방법을 추가로 요청했습니다.
- **해결 과정:**
    1.  **`Content-Length` 검사:** `FileDownloadService`의 다운로드 완료 시점에서 응답 헤더의 `Content-Length`가 0인 경우, 유효한 파일이 아닌 것으로 간주하여 에러 처리하는 로직을 추가했습니다.
    2.  **`Content-Type` 옵셔널 검사:** `downloadFile` 함수가 `expectedContentType`을 옵셔널 파라미터로 받도록 수정했습니다.
    3.  `FileDownloadViewModel`에서는 URL의 확장자를 기반으로 `expectedContentType`을 유추하여 `FileDownloadService`로 전달합니다.
    4.  `FileDownloadService`는 이 `expectedContentType` 값이 존재할 경우에만 실제 응답의 `Content-Type`과 일치하는지 검사하여, 일치하지 않으면 에러 처리합니다.