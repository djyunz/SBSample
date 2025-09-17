//
//  FileDownloadViewModel.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//

import Foundation
import LogMacro

@MainActor
@Logging
final class FileDownloadViewModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var downloadedFilePath: String?

    func startDownload(urlString: String) {
        downloadedFilePath = nil
        progress = 0.0

        Task {
            do {
                let stream = FileDownloadService.shared.downloadFile(urlString: urlString)
                for try await event in stream {
                    switch event {
                    case let .progress(value):
                        await MainActor.run {
                            self.progress = value
                        }
                    case let .finished(location):
                        await MainActor.run {
                            self.progress = 1.0
                            self.downloadedFilePath = location.absoluteString
                        }
                    }
                }
            } catch {
                #mlog("다운로드 에러: \(error)")
            }
        }
    }
}
