import Foundation

/// 바이럴 점수 계산기.
///
/// viralScore =
///   subscriberRatioScore * 0.40
/// + likeRateScore        * 0.20
/// + commentRateScore     * 0.15
/// + freshnessScore       * 0.15
/// + shortsFitScore       * 0.10
///
/// 0 ~ 100 사이로 clamp 된다.
enum ViralScoreCalculator {
    struct Breakdown {
        var subscriberRatioScore: Double
        var likeRateScore: Double
        var commentRateScore: Double
        var freshnessScore: Double
        var shortsFitScore: Double
        var total: Double
    }

    static func calculate(
        viewCount: Int,
        likeCount: Int,
        commentCount: Int,
        subscriberCount: Int,
        publishedAt: Date,
        durationSeconds: Int
    ) -> Double {
        breakdown(
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            subscriberCount: subscriberCount,
            publishedAt: publishedAt,
            durationSeconds: durationSeconds
        ).total
    }

    static func score(for video: VideoResult) -> Double {
        calculate(
            viewCount: video.viewCount,
            likeCount: video.likeCount,
            commentCount: video.commentCount,
            subscriberCount: video.subscriberCount,
            publishedAt: video.publishedAt,
            durationSeconds: video.durationSeconds
        )
    }

    static func breakdown(
        viewCount: Int,
        likeCount: Int,
        commentCount: Int,
        subscriberCount: Int,
        publishedAt: Date,
        durationSeconds: Int
    ) -> Breakdown {
        let subscriberRatio = Double(viewCount) / Double(max(subscriberCount, 1000))
        let subscriberRatioScore = clamp01(subscriberRatio / 5.0)

        let likeRate = Double(likeCount) / Double(max(viewCount, 1))
        let likeRateScore = clamp01(likeRate / 0.10)

        let commentRate = Double(commentCount) / Double(max(viewCount, 1))
        let commentRateScore = clamp01(commentRate / 0.02)

        let freshnessScore = freshness(publishedAt: publishedAt)

        let shortsFitScore: Double
        switch durationSeconds {
        case ..<1: shortsFitScore = 0.3
        case 1...60: shortsFitScore = 1.0
        case 61...180: shortsFitScore = 0.5
        default: shortsFitScore = 0.2
        }

        let total = (
            subscriberRatioScore * 0.40
            + likeRateScore * 0.20
            + commentRateScore * 0.15
            + freshnessScore * 0.15
            + shortsFitScore * 0.10
        ) * 100

        return Breakdown(
            subscriberRatioScore: subscriberRatioScore * 100,
            likeRateScore: likeRateScore * 100,
            commentRateScore: commentRateScore * 100,
            freshnessScore: freshnessScore * 100,
            shortsFitScore: shortsFitScore * 100,
            total: min(100, max(0, total))
        )
    }

    static func freshness(publishedAt: Date) -> Double {
        switch publishedAt.daysSinceNow {
        case ..<8: return 1.0
        case 8...30: return 0.75
        case 31...90: return 0.5
        default: return 0.25
        }
    }

    /// 점수 해석 라벨.
    static func label(for score: Double) -> String {
        switch score {
        case 90...: return "매우 강한 바이럴"
        case 75..<90: return "참고 가치 높음"
        case 60..<75: return "보통 이상"
        default: return "약함"
        }
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
