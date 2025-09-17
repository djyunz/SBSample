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
        return URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }()

    override private init() {
        super.init()
    }

    private var streamContinuation: AsyncThrowingStream<DownloadStatus, Error>.Continuation?

    func downloadFile(urlString: String) -> AsyncThrowingStream<DownloadStatus, Error> {
        guard let url = URL(string: urlString) else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: NSError(domain: "Invalid URL", code: -1))
            }
        }

        return AsyncThrowingStream { continuation in
            self.streamContinuation = continuation
            let task = self.session.downloadTask(with: url)
            task.resume()
        }
    }
}

extension FileDownloadService {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        #mlog("Download finished at: \(location)")
        moveDownloadedFile(downloadTask: downloadTask, downloadedLocation: location)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        #mlog("Downloading: \(totalBytesWritten / 1024 / 1024)MB of \(totalBytesExpectedToWrite / 1024 / 1024)MB, \(String(format: "%.0f", progress * 100))%")
        streamContinuation?.yield(.progress(progress))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        #mlog("Download Resume: \(fileOffset / 1024 / 1024)MB of \(expectedTotalBytes / 1024 / 1024)MB")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            #mlog("Download Error: \(error.localizedDescription)")
            streamContinuation?.finish(throwing: error)
            streamContinuation = nil
        }
    }
}

// 파일 Management 관련 코드 분리
private extension FileDownloadService {
    func moveDownloadedFile(downloadTask: URLSessionDownloadTask, downloadedLocation: URL) {
        let fileManager: FileManager = FileManager.default

        // 앱의 Documents 디렉토리를 가져옴, 실패시 에러 던지기
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            streamContinuation?.finish(throwing: NSError(domain: "Invalid File Document Directory", code: -1))
            return
        }

        // 파일명 결정: 서버 response의 suggestedFilename이 있으면 사용하고, 없으면 UUID로 생성
        var fileName = downloadTask.response?.suggestedFilename ?? UUID().uuidString

        // 만약 파일명에 확장자가 없다면, response의 MIME 타입을 통해 확장자를 추론해 추가
        if (fileName as NSString).pathExtension.isEmpty,
           let mimeType = downloadTask.response?.mimeType,
           let utType = UTType(mimeType: mimeType),
           let ext = utType.preferredFilenameExtension {
            fileName += ".\(ext)"
        }

        // 사용자가 지정한 Documents(또는 Library, Cache) 내의 폴더 (예제에서는 "MyDownloads")
        let folderURL = documentsDirectory.appendingPathComponent("MyDownloads", isDirectory: true)
        try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

        let destinationURL = folderURL.appendingPathComponent(fileName)

        do {
            // 기존에 같은 이름의 파일이 있다면 삭제
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            // 임시 파일을 지정한 destination으로 이동
            try fileManager.moveItem(at: downloadedLocation, to: destinationURL)
            streamContinuation?.yield(.finished(destinationURL))
        } catch {
            // 파일 이동 및 실패시 에러 던지기
            streamContinuation?.finish(throwing: error)
            return
        }
        streamContinuation?.finish()
        streamContinuation = nil
    }
}
