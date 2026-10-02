import Foundation

/// YouTube(또는 mock) 검색 결과 한 건.
struct VideoResult: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var url: String
    var thumbnailURL: String
    var channelTitle: String
    var channelId: String
    var publishedAt: Date
    var durationSeconds: Int
    var viewCount: Int
    var likeCount: Int
    var commentCount: Int
    var subscriberCount: Int
    var viralScore: Double
    var description: String
    var tags: [String]

    /// 구독자 대비 조회수. subscriberCount가 0이면 0.
    var subscriberRatio: Double {
        guard subscriberCount > 0 else { return 0 }
        return Double(viewCount) / Double(subscriberCount)
    }

    var likeRate: Double {
        guard viewCount > 0 else { return 0 }
        return Double(likeCount) / Double(viewCount)
    }

    var commentRate: Double {
        guard viewCount > 0 else { return 0 }
        return Double(commentCount) / Double(viewCount)
    }

    var durationText: String { TimecodeFormatter.durationText(seconds: durationSeconds) }

    var publishedText: String { DateFormatter.shortsDate.string(from: publishedAt) }

    var viralLabel: String { ViralScoreCalculator.label(for: viralScore) }
}
