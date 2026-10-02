import Foundation

/// 사용자가 불러온 로컬 영상 파일의 메타데이터.
struct VideoFileInfo: Identifiable, Codable, Hashable {
    var id: UUID
    var fileURL: URL
    var fileName: String
    var fileSize: Int64
    var duration: Double
    var width: Int
    var height: Int
    var frameRate: Double
    var audioTrackExists: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileURL: URL,
        fileName: String,
        fileSize: Int64,
        duration: Double,
        width: Int,
        height: Int,
        frameRate: Double,
        audioTrackExists: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.duration = duration
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.audioTrackExists = audioTrackExists
        self.createdAt = createdAt
    }

    var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    var aspectRatioText: String {
        guard height > 0 else { return "-" }
        return String(format: "%.3f", aspectRatio)
    }

    var resolutionText: String { "\(width) x \(height)" }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var durationText: String { TimecodeFormatter.durationText(seconds: Int(duration.rounded())) }

    /// 숏폼 적합 여부: 60초 이하 + 세로 비율(9:16 근접) + 권장 해상도.
    var isVertical: Bool { aspectRatio > 0 && aspectRatio < 1.0 }
    var isShortsLength: Bool { duration > 0 && duration <= 60 }
    var hasGoodResolution: Bool { min(width, height) >= 720 && max(width, height) >= 1280 }

    var isShortsEligible: Bool { isShortsLength && isVertical }

    var shortsFitDescription: String {
        switch (isShortsLength, isVertical, hasGoodResolution) {
        case (true, true, true):
            return "숏폼에 매우 적합 (길이/비율/해상도 모두 충족)"
        case (true, true, false):
            return "숏폼 적합 (해상도가 다소 낮음)"
        case (true, false, _):
            return "길이는 적합하나 세로 비율이 아님"
        case (false, true, _):
            return "세로 영상이지만 60초를 초과함"
        default:
            return "숏폼 가공이 필요함"
        }
    }
}
