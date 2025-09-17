//
//  FileDownloadView.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//


import SwiftUI

struct FileDownloadView: View {
    @StateObject private var viewModel = FileDownloadViewModel()
    
    // Sample 500 MB 파일
//    let downloadURL = "https://jsoncompare.org/LearningContainer/SampleFiles/PDF/sample-500mb-pdf-download.pdf"
    let downloadURL = "https://www.shilla.net/seoul/firsthand/download.do?filePath=notice&fileName=PB_SpecialGift.pdf"

    var body: some View {
        VStack(spacing: 20) {
            Text("Download Large File")
                .font(.title)
                .padding()
            Button(action: {
                viewModel.startDownload(urlString: downloadURL)
            }) {
                Text("Start Download")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            VStack {
                ProgressView(value: viewModel.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 250)

                Text("\(Int(viewModel.progress * 100))% completed")
                    .font(.caption)
                    .padding()
            }

            if let filePath = viewModel.downloadedFilePath {
                Text("Downloaded File: \(filePath)")
                    .font(.footnote)
                    .padding()
            }
        }
        .padding()
    }
}
