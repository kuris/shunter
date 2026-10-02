import Foundation
import Combine

/// 앱 전역 상태 + 기능별 ViewModel 소유자.
@MainActor
final class AppViewModel: ObservableObject {
    let settingsStore: SettingsStore
    let projectStore: ProjectStore

    let searchViewModel: ShortsSearchViewModel
    let sourceFinderViewModel: SourceFinderViewModel
    let videoImportViewModel: VideoImportViewModel
    let transcriptionViewModel: TranscriptionViewModel
    let rewriteViewModel: RewriteViewModel
    let exportViewModel: ExportViewModel
    let settingsViewModel: SettingsViewModel

    // 파이프라인 공유 상태
    @Published var selectedItem: SidebarItem = .dashboard
    @Published var currentVideo: VideoFileInfo?
    @Published var currentTranscript: TranscriptDocument?
    @Published var audioFileURL: URL?
    @Published var translations: [TranslateLanguage: String] = [:]
    @Published var rewrittenScript: String = ""
    @Published var titleCandidates: [String] = []
    @Published var hooks: [String] = []
    @Published var lastExportFolder: URL?

    var settings: AppSettings { settingsStore.settings }

    init() {
        let settingsStore = SettingsStore()
        let projectStore = ProjectStore()
        self.settingsStore = settingsStore
        self.projectStore = projectStore

        self.searchViewModel = ShortsSearchViewModel(settingsStore: settingsStore)
        self.sourceFinderViewModel = SourceFinderViewModel()
        self.videoImportViewModel = VideoImportViewModel(service: VideoMetadataService())
        self.transcriptionViewModel = TranscriptionViewModel(
            audioService: AudioExtractionService(),
            transcriptService: TranscriptService(),
            settingsStore: settingsStore
        )
        self.rewriteViewModel = RewriteViewModel(
            geminiService: GeminiService(),
            settingsStore: settingsStore
        )
        self.exportViewModel = ExportViewModel(
            service: ExportService(),
            projectStore: projectStore,
            settingsStore: settingsStore
        )
        self.settingsViewModel = SettingsViewModel(settingsStore: settingsStore)

        // 기능 ViewModel의 결과를 공유 상태로 연결한다.
        videoImportViewModel.onImported = { [weak self] info in
            self?.currentVideo = info
        }
        transcriptionViewModel.onAudioReady = { [weak self] url in
            self?.audioFileURL = url
        }
        transcriptionViewModel.onTranscriptReady = { [weak self] document in
            self?.currentTranscript = document
        }
        rewriteViewModel.onRewritten = { [weak self] text in
            self?.rewrittenScript = text
        }
        rewriteViewModel.onTranslated = { [weak self] language, text in
            self?.translations[language] = text
        }
        rewriteViewModel.onTitlesGenerated = { [weak self] titles in
            self?.titleCandidates = titles
        }
        rewriteViewModel.onHooksGenerated = { [weak self] hooks in
            self?.hooks = hooks
        }
        exportViewModel.onExported = { [weak self] folder in
            self?.lastExportFolder = folder
        }

        searchViewModel.loadDefaults(from: settingsStore.settings)
        exportViewModel.loadDefaults(from: settingsStore.settings)
    }
}
