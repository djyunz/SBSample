//
//  ViewController.swift
//  SBSample
//
//  Created by Durk Jae Yun on 10/16/24.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // WKWebView 를 self.view 에 추가 합니다.
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.view.addSubview(webView)
        
        // 웹뷰의 크기를 자동으로 조정하도록 설정합니다.
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        webView.isInspectable = true // 디버깅을 위해 웹뷰를 검사할 수 있도록 설정합니다.
        
        // 웹뷰를 상단 하단 Safe Area 에 맞춰 배치합니다.
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor)
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
        if let url = URL(string: "https://storage-access-api-demo.glitch.me/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

extension ViewController: WKNavigationDelegate {
    // 웹 페이지 로딩이 완료되면 호출됩니다.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("웹 페이지 로딩 완료")
    }
    
    // 웹 페이지 로딩 중 오류가 발생하면 호출됩니다.
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("웹 페이지 로딩 실패: \(error.localizedDescription)")
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

