import Foundation
import Combine

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var isExtractingAudio: Bool = false
    @Published var audioProgress: Double = 0
    @Published var audioFileURL: URL?
    @Published var isTranscribing: Bool = false
    @Published var transcript: TranscriptDocument?
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var selectedSegmentID: UUID?

    var onAudioReady: ((URL) -> Void)?
    var onTranscriptReady: ((TranscriptDocument) -> Void)?

    private let audioService: AudioExtractionService
    private let transcriptService: TranscriptService
    private let settingsStore: SettingsStore

    init(audioService: AudioExtractionService, transcriptService: TranscriptService, settingsStore: SettingsStore) {
        self.audioService = audioService
        self.transcriptService = transcriptService
        self.settingsStore = settingsStore
    }

    func extractAudio(from video: VideoFileInfo, preferFFmpeg: Bool = false) async {
        isExtractingAudio = true
        audioProgress = 0
        errorMessage = nil
        statusMessage = "오디오 추출 중..."

        let baseFolder = settingsStore.settings.resolvedSaveFolder
            .appendingPathComponent("Working", isDirectory: true)
        let outputURL: URL
        do {
            try FileManager.default.ensureDirectory(at: baseFolder)
        } catch {
            errorMessage = error.localizedDescription
            isExtractingAudio = false
            return
        }

        let stem = video.fileURL.deletingPathExtension().lastPathComponent

        do {
            if preferFFmpeg, let ffmpeg = settingsStore.settings.resolvedFFmpegPath {
                outputURL = baseFolder.appendingPathComponent("\(stem)_audio.wav")
                _ = try await audioService.extractAudioWithFFmpeg(
                    from: video.fileURL,
                    outputURL: outputURL,
                    ffmpegPath: ffmpeg,
                    progress: { [weak self] value in
                        Task { @MainActor in self?.audioProgress = value }
                    }
                )
            } else {
                outputURL = baseFolder.appendingPathComponent("\(stem)_audio.m4a")
                _ = try await audioService.extractAudioWithAVFoundation(
                    from: video.fileURL,
                    outputURL: outputURL,
                    progress: { [weak self] value in
                        Task { @MainActor in self?.audioProgress = value }
                    }
                )
            }
            audioFileURL = outputURL
            statusMessage = "오디오 추출 완료: \(outputURL.lastPathComponent)"
            onAudioReady?(outputURL)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = ""
        }
        isExtractingAudio = false
    }

    func transcribe() async {
        guard let audioURL = audioFileURL else {
            errorMessage = "먼저 오디오를 추출해 주세요."
            return
        }
        isTranscribing = true
        errorMessage = nil
        statusMessage = "대본 추출 중... (최대 수 분 소요)"
        let settings = settingsStore.settings
        let result = await transcriptService.transcribe(
            audioURL: audioURL,
            apiKey: settings.geminiAPIKey,
            model: settings.geminiAudioModel
        )
        transcript = result.document
        statusMessage = result.isMock ? result.message : result.message
        onTranscriptReady?(result.document)
        isTranscribing = false
    }

    func updateSegmentText(id: UUID, text: String) {
        guard var document = transcript,
              let index = document.segments.firstIndex(where: { $0.id == id }) else { return }
        document.segments[index].text = text
        document.rebuildPlainText()
        transcript = document
        onTranscriptReady?(document)
    }

    var srtPreview: String {
        guard let transcript else { return "" }
        return SRTService.srt(from: transcript.segments)
    }

    func saveSRT() {
        guard let transcript else { return }
        let text = SRTService.srt(from: transcript.segments)
        saveText(text, defaultName: transcript.sourceVideoFileName + ".srt")
    }

    func saveTXT() {
        guard let transcript else { return }
        saveText(transcript.plainText, defaultName: transcript.sourceVideoFileName + ".txt")
    }

    private func saveText(_ text: String, defaultName: String) {
        let folder = settingsStore.settings.resolvedSaveFolder
        do {
            try FileManager.default.ensureDirectory(at: folder)
            let url = folder.appendingPathComponent(defaultName)
            try FileManager.default.writeAtomically(Data(text.utf8), to: url)
            statusMessage = "저장 완료: \(url.path)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
