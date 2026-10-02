import Foundation
import Combine

/// 원본 후보 찾기 보조 ViewModel.
/// 검색어 세트 생성과 후보 유사도 비교를 제공한다.
@MainActor
final class SourceFinderViewModel: ObservableObject {
    // 입력
    @Published var url: String = ""
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var script: String = ""
    @Published var hashtags: String = ""
    @Published var memo: String = ""

    // 생성 결과
    @Published var keywords: [String] = []
    @Published var keySentences: [String] = []
    @Published var tiktokQueries: [String] = []
    @Published var googleQueries: [String] = []
    @Published var japaneseQueries: [String] = []
    @Published var englishQueries: [String] = []
    @Published var chineseQueries: [String] = []
    @Published var checklist: [String] = []
    @Published var generationMessage: String = ""

    // 후보 비교
    @Published var candidateTitle: String = ""
    @Published var candidateScript: String = ""
    @Published var candidatePublishedAt: Date = Date()
    @Published var sourcePublishedAt: Date = Date()
    @Published var comparison: CandidateComparison?

    // TikTok URL 출처 기록
    @Published var tiktokURL: String = ""
    @Published var tiktokPlatform: String = "TikTok"
    @Published var tiktokCreator: String = ""
    @Published var tiktokMemo: String = ""
    @Published var tiktokTitle: String = ""
    @Published var tiktokStatus: String = "미확인"
    @Published var isFetchingTikTok: Bool = false

    private let tikTokService = TikTokMetadataService()

    let disclaimer = "이 분석은 공개 정보와 텍스트 유사도 기반 추정이며, 실제 원본 여부는 업로드 날짜, 원제작자 정보, 워터마크, 설명란, 댓글 등을 추가 확인해야 합니다."

    func generate() {
        let combined = [title, description, script, hashtags].joined(separator: " ")
        let orderedKeywords = topKeywords(in: combined, limit: 10)
        keywords = orderedKeywords
        keySentences = topSentences(in: script.isEmpty ? description : script, limit: 5)

        let primary = orderedKeywords.prefix(5).map { $0 }
        let translatedPlaceholder: (String) -> [String] = { keyword in
            ["\(keyword) shorts", "\(keyword) tiktok"]
        }

        tiktokQueries = [
            primary.joined(separator: " "),
            primary.prefix(2).joined(separator: " "),
            keywords.prefix(3).joined(separator: " ") + " 원본"
        ].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        googleQueries = [
            "site:tiktok.com \"\(keySentences.first ?? primary.joined(separator: " "))\"",
            "site:tiktok.com \(primary.prefix(2).joined(separator: " "))",
            "\"\(title)\"",
            "\"\(keySentences.first ?? "")\""
        ].filter { !$0.isEmpty }

        englishQueries = primary.prefix(3).flatMap(translatedPlaceholder)
        japaneseQueries = primary.prefix(3).map { "\($0) 豆知識 ショート" }
        chineseQueries = primary.prefix(3).map { "\($0) 科普 短视频" }

        checklist = [
            "업로드 날짜를 비교했는가? (후보가 더 이르면 원본 가능성↑)",
            "원제작자 계정 정보/설명란을 확인했는가?",
            "워터마크 또는 로고 흔적이 있는가?",
            "댓글에서 원본 출처를 언급하는가?",
            "동일 대사의 타임코드/구성이 일치하는가?",
            "본인 또는 허락받은 영상인지 권한을 확인했는가?"
        ]

        generationMessage = keywords.isEmpty
            ? "입력 텍스트가 부족합니다. 제목/대본을 추가해 주세요."
            : "검색어 세트를 생성했습니다. (MVP 규칙 기반, API Key 입력 시 번역 확장 가능)"
    }

    func compare() {
        let result = SimilarityService.compare(
            sourceTitle: title,
            candidateTitle: candidateTitle,
            sourceScript: script,
            candidateScript: candidateScript,
            sourcePublishedAt: sourcePublishedAt,
            candidatePublishedAt: candidatePublishedAt
        )
        comparison = CandidateComparison(
            sourceTitle: title,
            candidateTitle: candidateTitle,
            sourceScript: script,
            candidateScript: candidateScript,
            titleSimilarity: result.titleSimilarity,
            scriptSimilarity: result.scriptSimilarity,
            keywordSimilarity: result.keywordSimilarity,
            dateScore: result.dateScore,
            watermarkEvidence: "",
            totalSimilarity: result.totalSimilarity,
            notes: ""
        )
    }

    // MARK: - TikTok

    /// 공개 oEmbed 정보만 조회한다. 실패해도 앱은 수동 입력 모드로 계속 동작한다.
    func fetchTikTokMetadata() async {
        let trimmed = tiktokURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tiktokStatus = "URL을 입력해 주세요."
            return
        }
        isFetchingTikTok = true
        tiktokStatus = "공개 메타데이터 조회 중..."
        let result = await tikTokService.fetchMetadata(for: trimmed)
        if let metadata = result.metadata {
            if !metadata.title.isEmpty { tiktokTitle = metadata.title }
            if !metadata.authorName.isEmpty { tiktokCreator = metadata.authorName }
        }
        if result.isFallback {
            tiktokStatus = "자동 조회 실패 · 수동 입력 모드 (네트워크/공개정보 없음)"
        } else {
            tiktokStatus = "공개 메타데이터 조회 완료"
        }
        isFetchingTikTok = false
    }

    // MARK: - Helpers

    private func topKeywords(in text: String, limit: Int) -> [String] {
        let stopwords: Set<String> = ["그리고", "하지만", "그래서", "정말", "그냥", "이거", "저거", "하는", "있습니다", "합니다", "이", "그", "저", "것", "수", "때", "더", "the", "and", "for", "you", "that", "this", "with", "shorts", "tiktok"]
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "가-힣")).inverted)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 && !stopwords.contains($0) }
        let counts = words.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }.prefix(limit).map(\.key)
    }

    private func topSentences(in text: String, limit: Int) -> [String] {
        let delimiters = CharacterSet(charactersIn: ".!?。！？\n")
        let sentences = text
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.count <= limit { return sentences }
        let sorted = sentences.sorted { $0.count > $1.count }
        return Array(sorted.prefix(limit)).sorted { lhs, rhs in
            (sentences.firstIndex(of: lhs) ?? 0) < (sentences.firstIndex(of: rhs) ?? 0)
        }
    }
}
