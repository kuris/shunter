import Foundation

/// 하나의 영상에 대한 전체 대본 문서.
struct TranscriptDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var sourceVideoFileName: String
    var language: String
    var segments: [TranscriptSegment]
    var plainText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceVideoFileName: String,
        language: String = "en",
        segments: [TranscriptSegment] = [],
        plainText: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceVideoFileName = sourceVideoFileName
        self.language = language
        self.segments = segments
        self.plainText = plainText
        self.createdAt = createdAt
    }

    /// 세그먼트가 수정된 뒤 plainText를 다시 만든다.
    mutating func rebuildPlainText() {
        plainText = segments.map(\.text).joined(separator: " ")
    }
}
