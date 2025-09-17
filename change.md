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
