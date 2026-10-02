import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VideoImportView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        VideoImportContentView(
            vm: app.videoImportViewModel,
            onGoToTranscription: { app.selectedItem = .transcription }
        )
    }
}

private struct VideoImportContentView: View {
    @ObservedObject var vm: VideoImportViewModel
    let onGoToTranscription: () -> Void

    @State private var isTargeted: Bool = false
    @State private var showImporter: Bool = false

    private var webmType: UTType { UTType(filenameExtension: "webm") ?? .movie }
    private var allowedTypes: [UTType] { [.mpeg4Movie, .quickTimeMovie, .movie, webmType] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "영상 불러오기", subtitle: "본인 영상 또는 사용 허락을 받은 파일을 불러오세요.")

                SafetyNotice(text: "이 앱은 본인 영상 또는 사용 허락을 받은 영상의 대본 추출과 편집 준비를 돕는 도구입니다. 타인의 콘텐츠를 무단 복제하거나 재업로드하지 마세요.")

                dropZone

                if vm.isProcessing {
                    Card { HStack { ProgressView(); Text(vm.statusMessage).foregroundStyle(.secondary) } }
                }

                if let error = vm.errorMessage {
                    Card { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }

                if let video = vm.video {
                    videoInfoCard(video)
                }
            }
            .padding(24)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: allowedTypes) { result in
            switch result {
            case .success(let url):
                Task { await vm.importVideo(from: url) }
            case .failure(let error):
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 40))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("영상 파일을 여기에 드래그 앤 드롭")
                .font(.headline)
            Text("지원 형식: mp4, mov, m4v, webm")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                showImporter = true
            } label: {
                Label("파일 선택", systemImage: "folder")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.gray.opacity(0.35))
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                await vm.importVideo(from: url)
            }
        }
        return true
    }

    private func videoInfoCard(_ video: VideoFileInfo) -> some View {
        Card(title: "영상 정보", subtitle: video.fileName) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    infoItem("길이", video.durationText)
                    infoItem("해상도", video.resolutionText)
                    infoItem("비율", video.aspectRatioText)
                    infoItem("파일 크기", video.fileSizeText)
                    infoItem("오디오", video.audioTrackExists ? "있음" : "없음")
                    infoItem("프레임레이트", String(format: "%.1f", video.frameRate))
                }

                Divider()

                HStack {
                    StatusBadge(
                        text: video.isShortsEligible ? "숏폼 적합" : "숏폼 부적합",
                        color: video.isShortsEligible ? .green : .orange
                    )
                    Text(video.shortsFitDescription).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        onGoToTranscription()
                    } label: {
                        Label("자막 추출로 이동", systemImage: "arrow.right")
                    }
                }
            }
        }
    }

    private func infoItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
