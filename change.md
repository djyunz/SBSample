## 6. 다운로드 로직 리팩토링 및 통일 (Commit: 5a7f329)

### 대화 내용 요약

- **문제 제기:** `WKDownloadDelegate`는 다운로드 진행률을 세밀하게 추적하는 기능을 제공하지 않는다는 점을 지적하며, 진행률 표시가 필수적인 기능일 경우 `WKDownload`를 사용하지 않는 것이 더 나은 접근 방식이 아닌지 질문했습니다.
- **해결 방안 논의:** `WKDownload`의 한계를 인정하고, 다운로드 진행률 추적, 백그라운드 다운로드, 세밀한 제어 등 모든 면에서 우수한 `URLSession`을 사용하는 것이 표준적이고 올바른 방법임을 확인했습니다.
- **요청 사항:** 이에 따라, 프로젝트 내에서 iOS 14.5 버전을 기준으로 `WKDownloadDelegate`를 사용하도록 분기 처리된 코드를 모두 제거하고, 모든 OS 버전에서 `URLSession` 기반의 `FileDownloadService`를 사용하도록 코드를 통일해달라고 요청했습니다.

### 주요 코드 변경사항

- **`ViewController.swift` (리팩토링):**
  - `WKDownloadDelegate` 프로토콜 채택을 제거했습니다.
  - `webView(_:decidePolicyFor:navigationResponse:)` 메서드 내의 iOS 14.5 버전 분기 로직(`if #available`)을 삭제했습니다.
  - 이제 `Content-Disposition` 또는 `Content-Type` 헤더를 통해 다운로드로 판단되는 모든 요청은 버전에 관계없이 `FileDownloadViewModel`의 `startDownload` 메서드를 호출하여 `URLSession` 기반으로 처리됩니다.
  - `WKDownloadDelegate` 관련 델리게이트 메서드와 `extension`이 모두 삭제되어 코드가 단순화되었습니다.

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

## 4. WKWebView 파일 다운로드 기능 구현 및 개선 (Commit: `2035a45`)

### 요약
`WKWebView`에서 PDF 등 첨부파일 다운로드 기능을 구현하고, iOS 버전에 따라 다른 다운로드 방식을 적용하도록 개선했습니다. 또한, 구버전 다운로드 방식의 UI를 개선하여 사용자 경험을 향상시켰습니다.

### 주요 변경 사항

- **`ViewController.swift`**
  - `WKNavigationDelegate`의 `webView(_:decidePolicyFor:navigationResponse:)`를 사용하여 서버 응답 헤더(`Content-Type`, `Content-Disposition`)를 확인합니다.
  - 파일이 다운로드 대상일 경우, iOS 14.5 이상에서는 `.download` 정책을 사용하여 `WKDownloadDelegate` 플로우를 따릅니다.
  - iOS 14.5 미만에서는 기존 `FileDownloadViewModel`을 호출하여 다운로드를 처리하는 하위 호환성을 유지합니다.
  - `WKDownloadDelegate`와 `QLPreviewControllerDataSource` 프로토콜을 채택하고 관련 델리게이트 메서드를 구현했습니다.

- **`FileDownloadView.swift`**
  - 기존 다운로드 방식(iOS 14.5 미만)으로 다운로드가 완료된 항목에 '파일 보기' 버튼을 추가했습니다.
  - SwiftUI에서 `QLPreviewController`를 사용하기 위한 `UIViewControllerRepresentable` 래퍼(`QuickLookPreview`)를 구현했습니다.
  - '파일 보기' 버튼 클릭 시 `.sheet` 모디파이어를 통해 `QuickLookPreview`를 표시합니다.

- **`FileDownloadService.swift`**
  - 다운로드 진행률 계산 시 `totalBytesExpectedToWrite`가 0일 경우 0으로 나누기 오류가 발생하는 것을 방지하는 예외 처리를 추가하여 안정성을 높였습니다.

### 해결 과정 (Troubleshooting)
- **빌드 오류 해결:** 초기 제안했던 커스텀 `View` extension 방식이 `#available` 구문과 호환되지 않아 빌드 오류가 발생했습니다. 이 문제를 해결하기 위해 해당 extension을 삭제하고, SwiftUI의 표준 방식인 `if #available(...)` 구문을 `View` 본문에 직접 사용하는 방식으로 코드를 수정하여 안정성을 확보했습니다.

## 5. WKWebView 다운로드 진행 상태 통합 및 버그 수정 (Commit: `f9e9a5f`)

### 요약
`WKWebView`에서 시작된 파일 다운로드의 진행 상태를 `FileDownloadViewModel`과 통합하여 모든 iOS 버전에서 일관된 진행률 표시 및 파일 관리를 가능하게 했습니다. 초기 구현 과정에서 발생한 버그를 수정하고 불필요한 코드를 정리했습니다.

### 주요 변경 사항

- **`ViewController.swift`**
  - `WKDownloadDelegate` (iOS 14.5 이상)에서 여러 동시 다운로드를 정확히 추적하기 위해 `[WKDownload: DownloadItem]` 딕셔너리를 사용하여 `DownloadItem`을 관리하도록 수정했습니다.
  - `download(_:decideDestinationUsing:suggestedFilename:completionHandler:)` 메서드에서 다운로드 목적지 URL을 `DownloadItem`의 `localFileLocation`에 즉시 저장하도록 수정하여, 다운로드 완료 후 파일 경로를 찾지 못하는 버그를 해결했습니다.
  - `downloadDidFinish(_:)` 및 `download(_:didFailWithError:resumeData:)` 메서드에서 `DownloadItem`의 상태를 정확히 업데이트하도록 로직을 개선했습니다.
  - `QLPreviewController` 사용 시 `downloadedFileURL` 인스턴스 프로퍼티 대신 `DownloadItem`의 `localFileLocation`을 직접 사용하도록 수정하여 다중 다운로드 시 발생할 수 있는 문제를 방지했습니다.

- **불필요한 파일 및 코드 정리**
  - 초기 통합 시도 과정에서 생성되었던 `SBSample/WebView.swift` 파일을 삭제했습니다.
  - `SBSample/SwiftUIView.swift` 파일의 내용을 원래 상태로 복원했습니다.

### 해결 과정 (Troubleshooting)
- **빌드 오류 및 "파일 정보를 찾을 수 없음" 오류 해결:**
  - `WebView.swift` 파일과 `SwiftUIView.swift`의 불필요한 수정 내용이 빌드 오류를 유발하여 이를 제거했습니다.
  - `WKDownloadDelegate`를 통한 다운로드 완료 시 `DownloadItem`에 파일 경로가 제대로 저장되지 않아 "다운로드는 완료되었으나 파일 정보를 찾을 수 없음" 메시지가 발생하는 버그를 수정했습니다. 이는 `decideDestinationUsing` 메서드에서 `DownloadItem.localFileLocation`에 파일 경로를 명시적으로 할당함으로써 해결되었습니다.
- **WKDownload 진행률 표시 문제:** `WKDownload`의 진행률이 0%에서 바로 100%로 넘어가는 것처럼 보이는 현상에 대해 설명하고, 이는 파일 크기, 네트워크 속도, 시스템 처리 방식 등에 따른 정상적인 동작임을 안내했습니다. 큰 파일 다운로드 시 UX 개선을 위한 방안(불확정 진행률 표시)을 제안했습니다.