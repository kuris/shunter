import Foundation
import Combine

@MainActor
final class VideoImportViewModel: ObservableObject {
    @Published var video: VideoFileInfo?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""

    var onImported: ((VideoFileInfo) -> Void)?

    private let service: VideoMetadataService

    init(service: VideoMetadataService) {
        self.service = service
    }

    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "webm"]

    func isSupported(_ url: URL) -> Bool {
        Self.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func importVideo(from url: URL) async {
        guard isSupported(url) else {
            errorMessage = "지원하지 않는 형식입니다. (mp4, mov, m4v, webm)"
            return
        }
        isProcessing = true
        errorMessage = nil
        statusMessage = "영상 정보를 읽는 중..."
        do {
            let info = try await service.loadInfo(at: url)
            video = info
            statusMessage = "영상 정보를 불러왔습니다."
            onImported?(info)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = ""
        }
        isProcessing = false
    }
}
