import Foundation
import AVFoundation

enum AudioExtractionError: LocalizedError {
    case noAudioTrack
    case cannotCreateSession
    case unsupportedOutput
    case exportFailed(String)
    case ffmpegNotFound

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "영상에 오디오 트랙이 없습니다."
        case .cannotCreateSession: return "오디오 추출 세션을 만들 수 없습니다."
        case .unsupportedOutput: return "이 형식으로 오디오를 내보낼 수 없습니다."
        case .exportFailed(let message): return "오디오 추출 실패: \(message)"
        case .ffmpegNotFound: return "FFmpeg를 찾을 수 없습니다. 설정에서 경로를 지정해 주세요."
        }
    }
}

/// 오디오 추출 서비스.
///
/// 1순위: AVFoundation(AVAssetExportSession)으로 m4a 추출.
/// 2순위: FFmpeg 외부 바이너리로 wav 추출.
final class AudioExtractionService {

    /// AVFoundation으로 오디오를 m4a로 추출한다.
    func extractAudioWithAVFoundation(
        from url: URL,
        outputURL: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw AudioExtractionError.noAudioTrack }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioExtractionError.cannotCreateSession
        }
        guard session.supportedFileTypes.contains(.m4a) else {
            throw AudioExtractionError.unsupportedOutput
        }

        try FileManager.default.ensureDirectory(at: outputURL.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: outputURL)

        session.outputURL = outputURL
        session.outputFileType = .m4a

        let progressTask = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }

        defer { progressTask.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: AudioExtractionError.exportFailed(session.error?.localizedDescription ?? "알 수 없는 오류"))
                case .cancelled:
                    continuation.resume(throwing: AudioExtractionError.exportFailed("취소됨"))
                default:
                    continuation.resume(throwing: AudioExtractionError.exportFailed("예기치 않은 상태"))
                }
            }
        }

        progress(1.0)
        return outputURL
    }

    /// FFmpeg로 오디오를 wav(16kHz mono)로 추출한다.
    func extractAudioWithFFmpeg(
        from url: URL,
        outputURL: URL,
        ffmpegPath: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard FileManager.default.isExecutableFile(atPath: ffmpegPath) else {
            throw AudioExtractionError.ffmpegNotFound
        }
        try FileManager.default.ensureDirectory(at: outputURL.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: outputURL)

        let arguments = [
            "-y",
            "-i", url.path,
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1",
            outputURL.path
        ]

        progress(0.1)
        let result = try await ProcessRunner.run(executable: ffmpegPath, arguments: arguments)
        guard result.exitCode == 0 else {
            throw AudioExtractionError.exportFailed(result.errorOutput.isEmpty ? "FFmpeg 오류" : result.errorOutput)
        }
        progress(1.0)
        return outputURL
    }
}

/// 외부 프로세스를 안전하게 실행하고 출력을 수집한다.
struct ProcessRunner {
    struct Result {
        var exitCode: Int32
        var standardOutput: String
        var errorOutput: String
    }

    static func run(executable: String, arguments: [String]) async throws -> Result {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { finishedProcess in
                let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                let result = Result(
                    exitCode: finishedProcess.terminationStatus,
                    standardOutput: String(data: outData, encoding: .utf8) ?? "",
                    errorOutput: String(data: errData, encoding: .utf8) ?? ""
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
