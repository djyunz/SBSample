import Combine
import LogMacro
import SnapKit
import SwiftUI
import UIKit
import WebKit
import QuickLook // QuickLook 프레임워크를 추가합니다.

@Logging
// WKDownloadDelegate와 QLPreviewControllerDataSource 프로토콜을 추가합니다.
class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, QLPreviewControllerDataSource {
    
    let data: HeartData = .init(beatsPerMinute: 120)
    private let viewModel = FileDownloadViewModel()
    
    // 다운로드된 파일의 URL을 저장할 프로퍼티를 추가합니다.
    private var downloadedFileURL: URL?
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        
        // 웹뷰가 다른 SwiftUI 뷰 뒤에 위치하도록 하고, 투명하게 만듭니다.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        view.insertSubview(webView, at: 0)


        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        // 테스트 URL을 수정합니다.
        if let url = URL(string: "https://www.shilla.net/seoul/firsthand/download.do?filePath=notice&fileName=PB_SpecialGift.pdf") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        // --- 기존 SwiftUI 뷰 설정은 그대로 유지합니다. ---
        let swiftUIView = SwiftUIView().background(Color.red).onTapGesture {
            let nextVC = UIHostingController(rootView: SwiftUIView().background(Color.blue))
            self.present(nextVC, animated: true)
        }
        let swiftUIViewController = UIHostingController(rootView: swiftUIView)
        addChild(swiftUIViewController)
        view.addSubview(swiftUIViewController.view)
        swiftUIViewController.view.backgroundColor = .cyan
        swiftUIViewController.view.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.height.equalTo(50)
            make.centerX.equalTo(self.view.safeAreaLayoutGuide)
        }

        let heartRateView = HeartRateView(data: data).background(Color.brown).onTapGesture { [weak self] in
            self?.data.beatsPerMinute = Int.random(in: 60 ... 120)
        }
        let heartRateViewController = UIHostingController(rootView: heartRateView)
        addChild(heartRateViewController)
        view.addSubview(heartRateViewController.view)
        heartRateViewController.view.backgroundColor = .yellow
        heartRateViewController.view.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide)
            make.centerX.equalTo(self.view.safeAreaLayoutGuide)
        }

        let fileDownloadView = FileDownloadView(viewModel: self.viewModel).background(Color.green)
        let fileDownloadViewController = UIHostingController(rootView: fileDownloadView)
        self.addChild(fileDownloadViewController)
        self.view.addSubview(fileDownloadViewController.view)
        fileDownloadViewController.view.backgroundColor = .orange
        fileDownloadViewController.view.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide).offset(60)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide).offset(-50)
            make.leading.trailing.equalTo(self.view.safeAreaLayoutGuide)
            make.centerX.equalTo(self.view.safeAreaLayoutGuide)
        }

        #mlog("뷰컨트롤러 로드 완료")
    }
}

// MARK: - WKNavigationDelegate
extension ViewController {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #mlog("웹 페이지 로딩 완료")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #mlog("웹 페이지 로딩 실패: \(error.localizedDescription)")
    }
    
    // 기존 async 버전을 삭제하고, 하위 버전 호환을 위해 decisionHandler 버전으로 교체합니다.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 외부 앱 링크(tel:, mailto: 등)를 처리합니다.
        if let url = navigationAction.request.url,
           !["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // navigationResponse 델리게이트에서 다운로드를 분기 처리합니다.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let response = navigationResponse.response as? HTTPURLResponse,
              let url = response.url else {
            decisionHandler(.allow)
            return
        }

        let disp = (response.allHeaderFields["Content-Disposition"] as? String ?? "").lowercased()
        let type = (response.allHeaderFields["Content-Type"] as? String ?? "").lowercased()

        // 다운로드할 파일인지 확인합니다.
        if disp.contains("attachment") || type.contains("application/pdf") {
            // iOS 14.5 이상인 경우에만 .download 정책을 사용합니다.
            if #available(iOS 14.5, *) {
                #mlog("iOS 14.5+ 감지. WKDownloadDelegate를 사용합니다.")
                decisionHandler(.download)
            } else {
                // 그 이전 버전에서는 기존 방식을 사용합니다.
                #mlog("구버전 iOS 감지. FileDownloadViewModel을 사용합니다.")
                viewModel.startDownload(urlString: url.absoluteString)
                decisionHandler(.cancel)
            }
            return
        }
        
        decisionHandler(.allow)
    }
    
    // iOS 14.5 이상에서만 호출됩니다.
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            return
        }
        #mlog("Provisional navigation failed: \(error.localizedDescription)")
    }
}

// MARK: - WKUIDelegate
extension ViewController {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }
}

// MARK: - WKDownloadDelegate (iOS 14.5+ 전용)
@available(iOS 14.5, *)
extension ViewController {
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(suggestedFilename)
        
        try? FileManager.default.removeItem(at: fileURL)

        self.downloadedFileURL = fileURL
        #mlog("다운로드 경로 설정: \(fileURL.path)")
        completionHandler(fileURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let fileURL = self.downloadedFileURL else {
            #mlog("다운로드 완료되었으나 파일 URL이 없습니다.")
            return
        }
        #mlog("다운로드 성공: \(fileURL.path)")
        DispatchQueue.main.async {
            let preview = QLPreviewController()
            preview.dataSource = self
            self.present(preview, animated: true)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        #mlog("다운로드 실패: \(error.localizedDescription)")
    }
}

// MARK: - QLPreviewControllerDataSource (iOS 14.5+ 전용)
@available(iOS 14.5, *)
extension ViewController {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return downloadedFileURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let url = downloadedFileURL else {
            fatalError("미리보기할 파일 URL이 없습니다.")
        }
        return url as QLPreviewItem
    }
}

// MARK: - Keyboard Handling
extension ViewController {
    @objc
    func keyboardWillShow(_ notification: Notification) {
        #mlog("keyboardWillShow")
    }

    @objc
    func keyboardWillHide(_ notification: Notification) {
        #log("keyboardWillHide")
    }
}
