import Foundation

enum SearchPeriod: String, Codable, CaseIterable, Identifiable {
    case last7 = "최근 7일"
    case last30 = "최근 30일"
    case last90 = "최근 90일"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .last7: return 7
        case .last30: return 30
        case .last90: return 90
        }
    }
}

enum SearchSort: String, Codable, CaseIterable, Identifiable {
    case viralScore = "바이럴 점수"
    case viewCount = "조회수"
    case latest = "최신순"

    var id: String { rawValue }
}

enum TranslateLanguage: String, Codable, CaseIterable, Identifiable {
    case korean = "ko"
    case japanese = "ja"
    case english = "en"
    case chinese = "zh"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .japanese: return "일본어"
        case .english: return "영어"
        case .chinese: return "중국어"
        }
    }
}

enum RewriteStyle: String, Codable, CaseIterable, Identifiable {
    case emotional = "감동형"
    case informative = "정보형"
    case twist = "반전형"
    case story = "썰형"
    case news = "뉴스형"
    case aiNarration = "AI 내레이션형"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

/// 앱 전체 설정. JSON으로 로컬 저장된다.
/// Gemini API를 사용하며, 키가 없으면 각 기능은 데모(mock) 데이터로 동작한다.
struct AppSettings: Codable, Equatable {
    var geminiAPIKey: String = ""
    var geminiTextModel: String = "gemini-3.8-flash"
    var geminiAudioModel: String = "gemini-3.8-flash"
    var youTubeAPIKey: String = ""
    var ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
    var defaultSaveFolder: String = ""
    var defaultTranslateLanguage: TranslateLanguage = .korean
    var defaultSearchPeriod: SearchPeriod = .last30
    var minViewCount: Int = 10_000
    var shortsMaxDuration: Int = 60
    var showSafetyNotice: Bool = true

    init() {}

    /// 필드가 추가/변경되어도 기존 settings.json을 안전하게 읽도록 유연하게 디코딩한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        geminiAPIKey = try container.decodeIfPresent(String.self, forKey: .geminiAPIKey) ?? ""
        geminiTextModel = try container.decodeIfPresent(String.self, forKey: .geminiTextModel) ?? "gemini-3.8-flash"
        geminiAudioModel = try container.decodeIfPresent(String.self, forKey: .geminiAudioModel) ?? "gemini-3.8-flash"
        youTubeAPIKey = try container.decodeIfPresent(String.self, forKey: .youTubeAPIKey) ?? ""
        ffmpegPath = try container.decodeIfPresent(String.self, forKey: .ffmpegPath) ?? "/opt/homebrew/bin/ffmpeg"
        defaultSaveFolder = try container.decodeIfPresent(String.self, forKey: .defaultSaveFolder) ?? ""
        defaultTranslateLanguage = try container.decodeIfPresent(TranslateLanguage.self, forKey: .defaultTranslateLanguage) ?? .korean
        defaultSearchPeriod = try container.decodeIfPresent(SearchPeriod.self, forKey: .defaultSearchPeriod) ?? .last30
        minViewCount = try container.decodeIfPresent(Int.self, forKey: .minViewCount) ?? 10_000
        shortsMaxDuration = try container.decodeIfPresent(Int.self, forKey: .shortsMaxDuration) ?? 60
        showSafetyNotice = try container.decodeIfPresent(Bool.self, forKey: .showSafetyNotice) ?? true
    }

    static let ffmpegCandidates = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]

    /// Gemini API 키가 .env/환경변수에서 주입되었는지 여부(표시용).
    var hasGeminiKey: Bool { !geminiAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasYouTubeKey: Bool { !youTubeAPIKey.trimmingCharacters(in: .whitespaces).isEmpty }

    var resolvedSaveFolder: URL {
        if !defaultSaveFolder.isEmpty {
            return URL(fileURLWithPath: defaultSaveFolder)
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortsHunterStudio", isDirectory: true)
    }

    var resolvedFFmpegPath: String? {
        let candidate = ffmpegPath.trimmingCharacters(in: .whitespaces)
        if !candidate.isEmpty, FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return AppSettings.ffmpegCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
