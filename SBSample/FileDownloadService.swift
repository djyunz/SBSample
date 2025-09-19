//
//  FileDownloadService.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//

import Foundation
import LogMacro
import UniformTypeIdentifiers

enum DownloadStatus {
    case progress(Double) // 0.0 ~ 1.0 사이의 진행률 값
    case finished(URL) // 다운로드 완료 후 파일이 위치한 URL
}

@Logging
final class FileDownloadService: NSObject, URLSessionDownloadDelegate {
    static let shared = FileDownloadService()

    private lazy var session: URLSession = {
        let config: URLSessionConfiguration = URLSessionConfiguration.background(withIdentifier: "fileDownload")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var continuations: [Int: AsyncThrowingStream<DownloadStatus, Error>.Continuation] = [:]

    override private init() {
        super.init()
    }

    func downloadFile(url: URL, expectedContentType: String? = nil) -> AsyncThrowingStream<DownloadStatus, Error> {
        return AsyncThrowingStream { continuation in
            var request = URLRequest(url: url)
            if let expectedContentType = expectedContentType {
                request.setValue(expectedContentType, forHTTPHeaderField: "Accept")
            }
            let task = session.downloadTask(with: request)
            continuations[task.taskIdentifier] = continuation
            task.resume()
        }
    }
}

extension FileDownloadService {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        #mlog("Download finished for task \(downloadTask.taskIdentifier) at: \(location)")

        guard let response = downloadTask.response as? HTTPURLResponse else {
            let error = NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            finishWithError(error, for: downloadTask)
            return
        }

        guard (200 ... 299).contains(response.statusCode) else {
            let error = NSError(domain: "HTTPError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Download failed with status code: \(response.statusCode)"])
            finishWithError(error, for: downloadTask)
            return
        }

        if response.expectedContentLength == 0 {
            let error = NSError(domain: "DownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Content-Length is 0"])
            finishWithError(error, for: downloadTask)
            return
        }

        // expectedContentType이 nil이 아닐 경우에만 Content-Type 검사
        if let expectedContentType = downloadTask.originalRequest?.value(forHTTPHeaderField: "Accept"),
           let mimeType = response.mimeType, !mimeType.contains(expectedContentType) {
            let error = NSError(domain: "DownloadError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Content-Type mismatch. Expected \(expectedContentType) but got \(mimeType)"])
            finishWithError(error, for: downloadTask)
            return
        }

        moveDownloadedFile(downloadTask: downloadTask, downloadedLocation: location)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = if totalBytesExpectedToWrite > 0 {
            Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else { 0.0 }
        #mlog("Task \(downloadTask.taskIdentifier): Downloading: \(totalBytesWritten / 1024 / 1024)MB of \(totalBytesExpectedToWrite / 1024 / 1024)MB, \(String(format: "%.0f", progress * 100))%")
        continuations[downloadTask.taskIdentifier]?.yield(.progress(progress))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            #mlog("Download Error for task \(task.taskIdentifier): \(error.localizedDescription)")
            finishWithError(error, for: task)
        } else {
            continuations[task.taskIdentifier]?.finish()
            continuations.removeValue(forKey: task.taskIdentifier)
        }
    }

    private func finishWithError(_ error: Error, for task: URLSessionTask) {
        continuations[task.taskIdentifier]?.finish(throwing: error)
        continuations.removeValue(forKey: task.taskIdentifier)
    }
}

private extension FileDownloadService {
    func moveDownloadedFile(downloadTask: URLSessionDownloadTask, downloadedLocation: URL) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            let error = NSError(domain: "FileError", code: -100, userInfo: [NSLocalizedDescriptionKey: "Could not find documents directory"])
            finishWithError(error, for: downloadTask)
            return
        }

        var fileName = downloadTask.response?.suggestedFilename ?? UUID().uuidString
        if (fileName as NSString).pathExtension.isEmpty,
           let mimeType = downloadTask.response?.mimeType,
           let utType = UTType(mimeType: mimeType),
           let ext = utType.preferredFilenameExtension {
            fileName += ".\(ext)"
        }

        let folderURL = documentsDirectory.appendingPathComponent("MyDownloads", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

        let destinationURL = folderURL.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: downloadedLocation, to: destinationURL)
            continuations[downloadTask.taskIdentifier]?.yield(.finished(destinationURL))
        } catch {
            finishWithError(error, for: downloadTask)
        }
    }
}
