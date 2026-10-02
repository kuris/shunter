import Foundation

/// 원본 후보 유사도 비교 서비스.
/// 텍스트 유사도 기반 추정치만 제공한다.
enum SimilarityService {

    struct Result {
        var titleSimilarity: Double
        var scriptSimilarity: Double
        var keywordSimilarity: Double
        var dateScore: Double
        var totalSimilarity: Double
    }

    /// 날짜 점수: 후보가 원본(소스)보다 이르면 높다.
    static func dateScore(sourcePublishedAt: Date?, candidatePublishedAt: Date?) -> Double {
        guard let source = sourcePublishedAt, let candidate = candidatePublishedAt else { return 0.5 }
        let days = Calendar.current.dateComponents([.day], from: candidate, to: source).day ?? 0
        switch days {
        case 8...: return 1.0        // 후보가 8일 이상 이르면 원본 가능성 높음
        case 1...7: return 0.8
        case 0: return 0.6
        case -7 ... -1: return 0.4
        default: return 0.2
        }
    }

    static func compare(
        sourceTitle: String,
        candidateTitle: String,
        sourceScript: String,
        candidateScript: String,
        sourcePublishedAt: Date? = nil,
        candidatePublishedAt: Date? = nil
    ) -> Result {
        let title = jaccard(tokens(sourceTitle), tokens(candidateTitle))
        let script = jaccard(tokens(sourceScript), tokens(candidateScript))
        let keyword = jaccard(keywords(sourceScript), keywords(candidateScript))
        let date = dateScore(sourcePublishedAt: sourcePublishedAt, candidatePublishedAt: candidatePublishedAt)

        let total = (
            title * 0.25
            + script * 0.45
            + keyword * 0.20
            + date * 0.10
        ) * 100

        return Result(
            titleSimilarity: title * 100,
            scriptSimilarity: script * 100,
            keywordSimilarity: keyword * 100,
            dateScore: date * 100,
            totalSimilarity: min(100, max(0, total))
        )
    }

    // MARK: - Helpers

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^0-9a-z가-힣\\s]", with: " ", options: .regularExpression)
    }

    static func tokens(_ text: String) -> Set<String> {
        Set(
            normalize(text)
                .split(whereSeparator: { $0 == " " || $0 == "\n" })
                .map(String.init)
                .filter { $0.count >= 2 }
        )
    }

    /// 불용어를 제거한 상위 빈도 키워드.
    static func keywords(_ text: String, limit: Int = 30) -> Set<String> {
        let stopwords: Set<String> = ["그리고", "하지만", "그래서", "정말", "그냥", "이거", "저거", "하는", "있습니다", "합니다", "the", "and", "for", "you", "that", "this", "with"]
        let counts = tokens(text).reduce(into: [String: Int]()) { result, token in
            guard !stopwords.contains(token) else { return }
            result[token, default: 0] += 1
        }
        return Set(counts.sorted { $0.value > $1.value }.prefix(limit).map(\.key))
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
}
