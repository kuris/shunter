import Foundation

/// CapCut 내보내기 입력.
struct ExportInput {
    var projectName: String
    var keyword: String
    var outputDirectory: URL
    var videoFileURL: URL?
    var audioFileURL: URL?
    var transcript: TranscriptDocument?
    var videoDuration: Double = 0
    var translations: [TranslateLanguage: String] = [:]
    var rewrittenScript: String = ""
    var titleCandidates: [String] = []
    var hooks: [String] = []
    var sourcePlatform: String = ""
    var sourceURL: String = ""
    var sourceCreator: String = ""
    var permissionStatus: String = "본인 영상 또는 사용 허락 받음"
    var notes: String = ""
    var includeOriginalVideo: Bool = true
    var includeAudio: Bool = true
}

struct ExportResult {
    var folderURL: URL
    var files: [String]
}

enum ExportError: LocalizedError {
    case noOutputDirectory
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noOutputDirectory: return "저장 위치를 지정할 수 없습니다."
        case .writeFailed(let message): return "내보내기 실패: \(message)"
        }
    }
}

/// CapCut에서 바로 불러올 수 있는 파일 묶음을 폴더로 내보낸다.
/// 실제로 폴더와 txt/srt/json 파일을 생성한다.
final class ExportService {
    private let fileManager = FileManager.default

    func export(_ input: ExportInput) async throws -> ExportResult {
        let folderName = makeFolderName(projectName: input.projectName, keyword: input.keyword)
        let folderURL = input.outputDirectory.appendingPathComponent(folderName, isDirectory: true)

        do {
            try fileManager.ensureDirectory(at: input.outputDirectory)
            try fileManager.ensureDirectory(at: folderURL)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }

        var exportedFiles: [String] = []

        func write(_ text: String, to name: String) throws {
            let url = folderURL.appendingPathComponent(name)
            try fileManager.writeAtomically(Data(text.utf8), to: url)
            exportedFiles.append(name)
        }

        func copyFile(_ source: URL, preferredName: String) throws {
            let ext = source.pathExtension
            let named = ext.isEmpty ? preferredName : "\(preferredName).\(ext)"
            let destination = fileManager.uniqueFileURL(in: folderURL, preferredName: named)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            exportedFiles.append(destination.lastPathComponent)
        }

        do {
            // 원본 영상
            if input.includeOriginalVideo, let video = input.videoFileURL {
                try copyFile(video, preferredName: "original_video")
            }

            // 오디오
            if input.includeAudio, let audio = input.audioFileURL {
                try copyFile(audio, preferredName: "audio_extract")
            }

            // 대본 텍스트
            if let transcript = input.transcript {
                try write(transcript.plainText, to: "transcript_original.txt")

                for (language, text) in input.translations where !text.isEmpty {
                    try write(text, to: "transcript_\(language.rawValue).txt")
                }

                // 원문 SRT
                try write(SRTService.srt(from: transcript.segments), to: "subtitle_original.srt")

                // 번역 SRT: 번역문이 세그먼트 수와 일치하면 타임코드에 맞춰 생성한다.
                for (language, text) in input.translations where !text.isEmpty {
                    let lines = text
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && !$0.hasPrefix("[") }
                    guard lines.count == transcript.segments.count else { continue }
                    var translatedSegments = transcript.segments
                    for index in translatedSegments.indices {
                        translatedSegments[index].translatedText = lines[index]
                    }
                    try write(
                        SRTService.srt(from: translatedSegments, useTranslation: true),
                        to: "subtitle_\(language.rawValue).srt"
                    )
                }
            }

            // 재작성/제목/후킹
            if !input.rewrittenScript.isEmpty {
                try write(input.rewrittenScript, to: "rewritten_script.txt")
            }
            if !input.titleCandidates.isEmpty {
                try write(input.titleCandidates.joined(separator: "\n"), to: "title_candidates.txt")
            }
            if !input.hooks.isEmpty {
                try write(input.hooks.joined(separator: "\n"), to: "hooks.txt")
            }

            // 출처 메모
            try write(sourceNotes(input), to: "source_notes.txt")

            // 메타데이터 JSON
            let metadata = ProjectMetadata(
                projectName: input.projectName,
                createdAt: Date(),
                sourcePlatform: input.sourcePlatform,
                sourceURL: input.sourceURL,
                sourceCreator: input.sourceCreator,
                permissionStatus: input.permissionStatus,
                videoFileName: input.videoFileURL?.lastPathComponent ?? "",
                duration: input.videoDuration,
                language: input.transcript?.language ?? "",
                exportedFiles: exportedFiles,
                notes: input.notes
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let metadataData = try encoder.encode(metadata)
            try fileManager.writeAtomically(metadataData, to: folderURL.appendingPathComponent("project_metadata.json"))
            exportedFiles.append("project_metadata.json")

            return ExportResult(folderURL: folderURL, files: exportedFiles)
        } catch let error as ExportError {
            throw error
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }

    private func sourceNotes(_ input: ExportInput) -> String {
        """
        [출처 정보]
        플랫폼: \(input.sourcePlatform)
        원본 URL: \(input.sourceURL)
        원작자/계정: \(input.sourceCreator)
        사용 권한 상태: \(input.permissionStatus)
        메모: \(input.notes)

        [안내]
        이 앱은 본인 영상 또는 사용 허락을 받은 영상의 대본 추출과 편집 준비를 돕는 도구입니다.
        타인의 콘텐츠를 무단 복제하거나 재업로드하지 마세요.
        재작성 결과는 원문의 구조와 아이디어만 참고해 새롭게 작성한 것입니다.
        """
    }

    private func makeFolderName(projectName: String, keyword: String) -> String {
        let base = keyword.isEmpty ? projectName : keyword
        let sanitized = base
            .replacingOccurrences(of: "[^0-9A-Za-z가-힣\\-\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
        let safeBase = sanitized.isEmpty ? "Project" : sanitized
        let timestamp = DateFormatter.folderTimestamp.string(from: Date())
        return "Project_\(safeBase)_\(timestamp)"
    }

    private struct ProjectMetadata: Encodable {
        let projectName: String
        let createdAt: Date
        let sourcePlatform: String
        let sourceURL: String
        let sourceCreator: String
        let permissionStatus: String
        let videoFileName: String
        let duration: Double
        let language: String
        let exportedFiles: [String]
        let notes: String
    }
}
