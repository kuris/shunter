import Foundation
import AVFoundation

enum VideoMetadataError: LocalizedError {
    case unreadable
    case noVideoTrack

    var errorDescription: String? {
        switch self {
        case .unreadable: return "영상 파일을 읽을 수 없습니다."
        case .noVideoTrack: return "영상 트랙을 찾을 수 없습니다."
        }
    }
}

/// AVFoundation으로 로컬 영상 파일의 메타데이터를 읽는다.
final class VideoMetadataService {
    func loadInfo(at url: URL) async throws -> VideoFileInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw VideoMetadataError.noVideoTrack }

        let size = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let frameRate = try await videoTrack.load(.nominalFrameRate)

        // 회전 변환을 반영해 실제 표시 크기를 계산한다.
        let transformed = size.applying(transform)
        let width = Int(abs(transformed.width).rounded())
        let height = Int(abs(transformed.height).rounded())

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        let fileSize = FileManager.default.fileSize(at: url)
        let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()

        if durationSeconds.isNaN || durationSeconds.isInfinite {
            throw VideoMetadataError.unreadable
        }

        return VideoFileInfo(
            fileURL: url,
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            duration: durationSeconds,
            width: width,
            height: height,
            frameRate: Double(frameRate),
            audioTrackExists: !audioTracks.isEmpty,
            createdAt: createdAt
        )
    }
}
