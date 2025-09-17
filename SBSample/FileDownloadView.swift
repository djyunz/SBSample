//
//  FileDownloadView.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//

import SwiftUI

struct FileDownloadView: View {
    @ObservedObject var viewModel: FileDownloadViewModel

    // Sample file URLs
    let sampleURLs = [
        "https://www.shilla.net/seoul/firsthand/download.do?filePath=notice&fileName=PB_SpecialGift.pdf",
        "https://www.shillahotels.com/membership/resources/images/download/shilla_rewards_guide_ko.pdf", // 존재하지 않는 url
        "https://jsoncompare.org/LearningContainer/SampleFiles/PDF/sample-500mb-pdf-download.pdf",
        "https://yavuzceliker.github.io/sample-images/image-1021.jpg"
    ]

    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    // Add a new download from the sample URLs
                    if let urlString = sampleURLs.randomElement() {
                        viewModel.startDownload(urlString: urlString)
                    }
                }) {
                    Text("Start New Download")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()

                List(viewModel.downloadItems) { item in
                    DownloadRowView(item: item)
                }
            }
            .navigationTitle("Concurrent Downloads")
        }
    }
}

struct DownloadRowView: View {
    @ObservedObject var item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.url.lastPathComponent)
                .font(.headline)
            
            HStack {
                ProgressView(value: item.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(item.progress * 100))%")
                    .font(.caption)
            }

            switch item.state {
            case .waiting:
                Text("Waiting...").font(.footnote).foregroundColor(.gray)
            case .downloading:
                Text("Downloading...").font(.footnote).foregroundColor(.blue)
            case .finished:
                if let location = item.localFileLocation {
                    Text("Finished: \(location.path)").font(.footnote).foregroundColor(.green)
                }
            case .failed(let error):
                Text("Failed: \(error.localizedDescription)").font(.footnote).foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}
