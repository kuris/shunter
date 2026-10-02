import Foundation

/// 대본의 한 세그먼트(타임코드 + 텍스트 + 번역).
struct TranscriptSegment: Identifiable, Codable, Hashable {
    var id: UUID
    var startTime: Double
    var endTime: Double
    var text: String
    var translatedText: String?
    var confidence: Double?

    init(
        id: UUID = UUID(),
        startTime: Double,
        endTime: Double,
        text: String,
        translatedText: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.translatedText = translatedText
        self.confidence = confidence
    }

    var timeRangeText: String {
        "\(TimecodeFormatter.srtTimecode(startTime)) → \(TimecodeFormatter.srtTimecode(endTime))"
    }

    var duration: Double { max(0, endTime - startTime) }
}
