import Foundation

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case transcribing
    case transcribed
    case translated
    case exported

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "작성 중"
        case .transcribing: return "대본 추출 중"
        case .transcribed: return "대본 완료"
        case .translated: return "번역 완료"
        case .exported: return "내보내기 완료"
        }
    }
}

/// 로컬에 저장되는 프로젝트 기록.
struct ProjectItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sourceURL: String
    var sourcePlatform: String
    var videoFileURL: URL?
    var transcript: String
    var translatedTranscript: String
    var exportFolderURL: URL?
    var notes: String
    var status: ProjectStatus

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sourceURL: String = "",
        sourcePlatform: String = "",
        videoFileURL: URL? = nil,
        transcript: String = "",
        translatedTranscript: String = "",
        exportFolderURL: URL? = nil,
        notes: String = "",
        status: ProjectStatus = .draft
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceURL = sourceURL
        self.sourcePlatform = sourcePlatform
        self.videoFileURL = videoFileURL
        self.transcript = transcript
        self.translatedTranscript = translatedTranscript
        self.exportFolderURL = exportFolderURL
        self.notes = notes
        self.status = status
    }
}
