import Foundation

/// 원본 후보와의 유사도 비교 결과.
struct CandidateComparison: Identifiable, Codable, Hashable {
    var id: UUID
    var sourceTitle: String
    var candidateTitle: String
    var sourceScript: String
    var candidateScript: String
    var titleSimilarity: Double
    var scriptSimilarity: Double
    var keywordSimilarity: Double
    var dateScore: Double
    var watermarkEvidence: String
    var totalSimilarity: Double
    var notes: String

    init(
        id: UUID = UUID(),
        sourceTitle: String,
        candidateTitle: String,
        sourceScript: String,
        candidateScript: String,
        titleSimilarity: Double = 0,
        scriptSimilarity: Double = 0,
        keywordSimilarity: Double = 0,
        dateScore: Double = 0,
        watermarkEvidence: String = "",
        totalSimilarity: Double = 0,
        notes: String = ""
    ) {
        self.id = id
        self.sourceTitle = sourceTitle
        self.candidateTitle = candidateTitle
        self.sourceScript = sourceScript
        self.candidateScript = candidateScript
        self.titleSimilarity = titleSimilarity
        self.scriptSimilarity = scriptSimilarity
        self.keywordSimilarity = keywordSimilarity
        self.dateScore = dateScore
        self.watermarkEvidence = watermarkEvidence
        self.totalSimilarity = totalSimilarity
        self.notes = notes
    }

    var verdict: String {
        switch totalSimilarity {
        case 85...: return "원본 후보 가능성 높음"
        case 70..<85: return "유사 후보"
        case 50..<70: return "일부 유사"
        default: return "원본 가능성 낮음"
        }
    }
}
