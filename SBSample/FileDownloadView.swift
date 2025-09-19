import QuickLook
import SwiftUI

struct FileDownloadView: View {
    @ObservedObject var viewModel: FileDownloadViewModel

    // Sample file URLs
    let sampleURLs = [
        "https://www.shilla.net/seoul/firsthand/download.do?filePath=notice&fileName=PB_SpecialGift.pdf",
        "https://www.shillahotels.com/membership/resources/images/download/shilla_rewards_guide_ko.pdf",
        "https://jsoncompare.org/LearningContainer/SampleFiles/PDF/sample-500mb-pdf-download.pdf",
        "https://yavuzceliker.github.io/sample-images/image-1021.jpg",
    ]

    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
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
    @State private var isPreviewing = false

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
                if item.localFileLocation != nil {
                    HStack {
                        Text("Finished")
                            .font(.footnote)
                            .foregroundColor(.green)
                        Spacer()
                        Button("파일 보기") {
                            self.isPreviewing = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Finished (No file location)")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            case .failed(let error):
                Text("Failed: \(error.localizedDescription)").font(.footnote).foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $isPreviewing) {
            if let url = item.localFileLocation {
                // 표준 #available 구문을 사용하여 버전을 확인하도록 수정합니다.
                let preview = QuickLookPreview(url: url)
                if #available(iOS 16.0, *) {
                    preview.presentationDetents([.medium, .large])
                } else {
                    preview
                }
            }
        }
    }
}

// SwiftUI에서 QLPreviewController를 사용하기 위한 Wrapper입니다. (변경 없음)
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview

        init(parent: QuickLookPreview) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            self.parent.url as QLPreviewItem
        }
    }
}

