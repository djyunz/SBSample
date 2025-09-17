//
//  ViewController.swift
//  SBSample
//
//  Created by Durk Jae Yun on 10/16/24.
//

import Combine
import LogMacro
import SnapKit
import SwiftUI
import UIKit
import WebKit

@Logging
class ViewController: UIViewController {
    let data: HeartData = .init(beatsPerMinute: 120)
    
    // ViewController가 ViewModel을 소유합니다.
    private let viewModel = FileDownloadViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // WKWebView 를 self.view 에 추가 합니다.
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        view.addSubview(webView)

        // 웹뷰의 크기를 자동으로 조정하도록 설정합니다.
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 디버깅을 위해 웹뷰를 검사할 수 있도록 설정합니다.
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // 웹뷰를 상단 하단 Safe Area 에 맞춰 배치합니다.
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])

        // 웹뷰 페이지 링크로 이동이 가능하도록 설정합니다.
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // 웹뷰에서 JavaScript 를 실행할 수 있도록 설정합니다.
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // 웹뷰에서 팝업 창을 열 수 있도록 설정합니다.
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 웹뷰에서 뒤로가기, 앞으로가기 제스처를 허용합니다.
        webView.allowsBackForwardNavigationGestures = true

        // 웹 페이지를 로드합니다.
//        if let url = URL(string: "https://www.shilla.net/seoul/firsthand/download.do?filePath=notice&fileName=PB_SpecialGiftdfsdfs.pdf") {
        if let url = URL(string:"https://www.shillahotels.com/membership/resources/images/download/shilla_rewards_guide_ko.pdf") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

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

        // FileDownloadView를 생성할 때 viewModel을 전달합니다.
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

extension ViewController: WKNavigationDelegate {
    // 웹 페이지 로딩이 완료되면 호출됩니다.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #mlog("웹 페이지 로딩 완료")
    }

    // 웹 페이지 로딩 중 오류가 발생하면 호출됩니다.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #mlog("웹 페이지 로딩 실패: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        #mlog("decidePolicyFor navigationAction: \(navigationAction)")
        if let urlString = navigationAction.request.url?.absoluteString,
           urlString.contains("firsthand/download.do") || urlString.contains("/download/") {
            // ViewController가 소유한 viewModel의 메서드를 직접 호출합니다.
            viewModel.startDownload(urlString: urlString)
            return .cancel
        }
        return .allow
    }
}

extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 새 창을 열 때 호출되는 메소드입니다.
        if navigationAction.targetFrame == nil {
            // 새 창을 열려고 할 때, 현재 웹뷰에서 링크를 열도록 설정합니다.
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
        }
        // 여기서는 새 창을 열지 않고 nil을 반환하여 기본 동작을 방지합니다.
        return nil
    }
}

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
