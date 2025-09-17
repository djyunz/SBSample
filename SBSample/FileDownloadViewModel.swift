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
    @Published var downloadItems: [DownloadItem] = []

    func startDownload(urlString: String) {
        guard let url = URL(string: urlString) else {
            #mlog("Invalid URL: \(urlString)")
            return
        }

        let newItem = DownloadItem(url: url)
        downloadItems.append(newItem)

        Task {
            await self.processDownload(for: newItem)
        }
    }

    private func processDownload(for item: DownloadItem) async {
        await MainActor.run { item.state = .downloading }
        do {
            let expectedContentType = contentType(for: item.url)
            let stream = FileDownloadService.shared.downloadFile(url: item.url, expectedContentType: expectedContentType)
            for try await event in stream {
                switch event {
                case let .progress(value):
                    await MainActor.run { item.progress = value }
                case let .finished(location):
                    await MainActor.run {
                        item.progress = 1.0
                        item.state = .finished
                        item.localFileLocation = location
                    }
                }
            }
        } catch {
            #mlog("Download failed for \(item.url.absoluteString): \(error)")
            await MainActor.run { item.state = .failed(error) }
        }
    }
    
    private func contentType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        default:
            return nil
        }
    }
}
