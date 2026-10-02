import SwiftUI
import AppKit

struct TranscriptionView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        TranscriptionContentView(
            vm: app.transcriptionViewModel,
            video: app.currentVideo,
            settings: app.settingsStore.settings,
            onGoToImport: { app.selectedItem = .videoImport },
            onGoToRewrite: { app.selectedItem = .rewrite }
        )
    }
}

private struct TranscriptionContentView: View {
    @ObservedObject var vm: TranscriptionViewModel
    let video: VideoFileInfo?
    let settings: AppSettings
    let onGoToImport: () -> Void
    let onGoToRewrite: () -> Void

    @State private var plainText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "자막 추출", subtitle: "오디오를 추출하고 대본(STT)을 생성한 뒤 SRT로 저장하세요.")

                if !settings.hasGeminiKey {
                    SafetyNotice(
                        text: "Gemini API 키가 없어 데모 대본이 생성됩니다. 설정에서 키를 입력하면 실제 음성 인식(전사)을 사용할 수 있습니다.",
                        systemImage: "key"
                    )
                }

                if let video {
                    videoBar(video)
                    actionBar(video)
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("불러온 영상이 없습니다.").font(.headline)
                            Text("먼저 영상을 불러와 주세요.").foregroundStyle(.secondary)
                            Button { onGoToImport() } label: {
                                Label("영상 불러오기", systemImage: "square.and.arrow.down")
                            }
                        }
                    }
                }

                if let error = vm.errorMessage {
                    Card { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }

                if let transcript = vm.transcript {
                    segmentsCard(transcript)
                    plainTextCard(transcript)
                    srtCard
                    saveBar
                }
            }
            .padding(24)
        }
        .onChange(of: vm.transcript) { _, newValue in
            plainText = newValue?.plainText ?? ""
        }
    }

    private func videoBar(_ video: VideoFileInfo) -> some View {
        Card(title: "대상 영상", subtitle: video.fileName) {
            HStack(spacing: 16) {
                Text("길이 \(video.durationText)").font(.callout)
                Text("해상도 \(video.resolutionText)").font(.callout)
                Text("오디오 \(video.audioTrackExists ? "있음" : "없음")").font(.callout)
                Spacer()
                if vm.audioFileURL != nil {
                    StatusBadge(text: "오디오 추출 완료", color: .green)
                }
                if vm.transcript != nil {
                    StatusBadge(text: "대본 준비됨", color: .blue)
                }
            }
        }
    }

    private func actionBar(_ video: VideoFileInfo) -> some View {
        Card(title: "처리") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        Task { await vm.extractAudio(from: video) }
                    } label: {
                        Label("오디오 추출 (AVFoundation)", systemImage: "waveform")
                    }
                    .disabled(vm.isExtractingAudio)

                    Button {
                        Task { await vm.extractAudio(from: video, preferFFmpeg: true) }
                    } label: {
                        Label("FFmpeg로 추출 (wav)", systemImage: "terminal")
                    }
                    .disabled(vm.isExtractingAudio || settings.resolvedFFmpegPath == nil)

                    Button {
                        Task { await vm.transcribe() }
                    } label: {
                        Label("대본 추출", systemImage: "text.bubble")
                    }
                    .disabled(vm.isTranscribing || vm.audioFileURL == nil)

                    Spacer()
                    if vm.isTranscribing { ProgressView().controlSize(.small) }
                }

                if vm.isExtractingAudio {
                    ProgressCard(title: "오디오 추출 중", progress: vm.audioProgress)
                }
                if !vm.statusMessage.isEmpty {
                    Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func segmentsCard(_ transcript: TranscriptDocument) -> some View {
        Card(title: "세그먼트", subtitle: "총 \(transcript.segments.count)개 · 텍스트를 직접 수정할 수 있습니다.") {
            VStack(spacing: 8) {
                ForEach(transcript.segments) { segment in
                    HStack(alignment: .top, spacing: 10) {
                        Text(segment.timeRangeText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 210, alignment: .leading)
                        TextField("", text: Binding(
                            get: { segment.text },
                            set: { vm.updateSegmentText(id: segment.id, text: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func plainTextCard(_ transcript: TranscriptDocument) -> some View {
        Card(title: "원문 대본 편집", subtitle: "전체 텍스트를 확인/복사할 수 있습니다.") {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $plainText)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                HStack {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(plainText, forType: .string)
                    } label: {
                        Label("전체 복사", systemImage: "doc.on.doc")
                    }
                    Spacer()
                    Button { onGoToRewrite() } label: {
                        Label("번역/재작성으로 이동", systemImage: "arrow.right")
                    }
                }
            }
        }
    }

    private var srtCard: some View {
        Card(title: "SRT 미리보기") {
            ScrollView {
                Text(vm.srtPreview)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        }
    }

    private var saveBar: some View {
        Card {
            HStack {
                Button { vm.saveTXT() } label: {
                    Label("TXT 저장", systemImage: "doc.text")
                }
                Button { vm.saveSRT() } label: {
                    Label("SRT 저장", systemImage: "captions.bubble")
                }
                Spacer()
                if !vm.statusMessage.isEmpty {
                    Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}
