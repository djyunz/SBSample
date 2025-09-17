
//
//  DownloadItem.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//

import Foundation

// 각 다운로드 항목의 상태를 정의하는 열거형
enum DownloadState: Equatable {
    case waiting
    case downloading
    case finished
    case failed(Error)

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.waiting, .waiting),
             (.downloading, .downloading),
             (.finished, .finished):
            return true
        case let (.failed(lhsError), .failed(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// 다운로드 항목을 나타내는 클래스 (ObservableObject로 UI 업데이트)
class DownloadItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    @Published var progress: Double = 0.0
    @Published var state: DownloadState = .waiting
    @Published var localFileLocation: URL?

    init(url: URL) {
        self.url = url
    }
}
