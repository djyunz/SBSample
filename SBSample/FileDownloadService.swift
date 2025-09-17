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
        config.isDiscretionary = true // 시스템 최적화 허용 - 베터리, 네트워크 상태, 전원 연결 상태등을 고려한 상황 판단하여 실행
        config.sessionSendsLaunchEvents = true // 앱이 종료되었거나 백그라운드 상태일 경우에도 URLSession 이벤트 발생시 시스템이 앱 자동 실행
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var continuations: [Int: AsyncThrowingStream<DownloadStatus, Error>.Continuation] = [:]

    override private init() {
        super.init()
    }

    func downloadFile(url: URL) -> AsyncThrowingStream<DownloadStatus, Error> {
        return AsyncThrowingStream { continuation in
            let task = session.downloadTask(with: url)
            continuations[task.taskIdentifier] = continuation
            task.resume()
        }
    }
}

extension FileDownloadService {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        #mlog("Download finished for task \(downloadTask.taskIdentifier) at: \(location)")
        moveDownloadedFile(downloadTask: downloadTask, downloadedLocation: location)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        #mlog("Task \(downloadTask.taskIdentifier): Downloading: \(totalBytesWritten / 1024 / 1024)MB of \(totalBytesExpectedToWrite / 1024 / 1024)MB, \(String(format: "%.0f", progress * 100))%")
        continuations[downloadTask.taskIdentifier]?.yield(.progress(progress))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let continuation = continuations[task.taskIdentifier] else {
            #mlog("Continuation not found for task \(task.taskIdentifier)")
            return
        }
        if let error = error {
            #mlog("Download Error for task \(task.taskIdentifier): \(error.localizedDescription)")
            continuation.finish(throwing: error)
        } else {
            // This is called after didFinishDownloadingTo, so we just finish the stream here.
            continuation.finish()
        }
        continuations.removeValue(forKey: task.taskIdentifier)
    }
}

// 파일 Management 관련 코드 분리
private extension FileDownloadService {
    func moveDownloadedFile(downloadTask: URLSessionDownloadTask, downloadedLocation: URL) {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            continuations[downloadTask.taskIdentifier]?.finish(throwing: NSError(domain: "Invalid File Document Directory", code: -1))
            continuations.removeValue(forKey: downloadTask.taskIdentifier)
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
            continuations[downloadTask.taskIdentifier]?.finish(throwing: error)
            continuations.removeValue(forKey: downloadTask.taskIdentifier)
        }
    }
}
