import Foundation
import Combine
import AppKit

@MainActor
final class ExportViewModel: ObservableObject {
    @Published var projectName: String = "쇼츠 프로젝트"
    @Published var outputDirectory: URL
    @Published var includeOriginalVideo: Bool = true
    @Published var includeAudio: Bool = true
    @Published var sourcePlatform: String = ""
    @Published var sourceURL: String = ""
    @Published var sourceCreator: String = ""
    @Published var permissionStatus: String = "본인 영상 또는 사용 허락 받음"
    @Published var notes: String = ""

    @Published var isExporting: Bool = false
    @Published var result: ExportResult?
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""

    var onExported: ((URL) -> Void)?

    private let service: ExportService
    private let projectStore: ProjectStore
    private let settingsStore: SettingsStore

    init(service: ExportService, projectStore: ProjectStore, settingsStore: SettingsStore) {
        self.service = service
        self.projectStore = projectStore
        self.settingsStore = settingsStore
        self.outputDirectory = settingsStore.settings.resolvedSaveFolder
    }

    func loadDefaults(from settings: AppSettings) {
        outputDirectory = settings.resolvedSaveFolder
    }

    func export(input: ExportInput) async {
        isExporting = true
        errorMessage = nil
        statusMessage = "CapCut용 파일을 생성하는 중..."
        do {
            let exportResult = try await service.export(input)
            result = exportResult
            statusMessage = "내보내기 완료: \(exportResult.folderURL.lastPathComponent) (\(exportResult.files.count)개 파일)"
            onExported?(exportResult.folderURL)

            let project = ProjectItem(
                name: input.projectName,
                sourceURL: input.sourceURL,
                sourcePlatform: input.sourcePlatform,
                videoFileURL: input.videoFileURL,
                transcript: input.transcript?.plainText ?? "",
                translatedTranscript: input.translations[settingsStore.settings.defaultTranslateLanguage] ?? "",
                exportFolderURL: exportResult.folderURL,
                notes: input.notes,
                status: .exported
            )
            projectStore.upsert(project)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = ""
        }
        isExporting = false
    }

    func openInFinder() {
        guard let folder = result?.folderURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}
