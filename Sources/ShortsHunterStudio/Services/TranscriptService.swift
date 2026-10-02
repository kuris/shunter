import Foundation

/// 대본(음성→텍스트) 추출 서비스.
///
/// Gemini의 멀티모달 오디오 이해 기능을 사용한다(별도 STT 유료 서비스 불필요).
/// API 키가 없거나 실패하면 데모 대본으로 안전하게 폴백한다.
final class TranscriptService {
    private let gemini: GeminiService

    init(gemini: GeminiService = GeminiService()) {
        self.gemini = gemini
    }

    func transcribe(
        audioURL: URL,
        apiKey: String?,
        model: String
    ) async -> (document: TranscriptDocument, isMock: Bool, message: String) {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmedKey.isEmpty else {
            return (
                MockData.transcript(for: audioURL.deletingPathExtension().lastPathComponent),
                true,
                "Gemini API 키가 없어 데모 대본을 표시합니다."
            )
        }

        do {
            let document = try await gemini.transcribeAudio(audioURL: audioURL, apiKey: trimmedKey, model: model)
            return (document, false, "Gemini 전사 완료 (\(model))")
        } catch {
            return (
                MockData.transcript(for: audioURL.deletingPathExtension().lastPathComponent),
                true,
                "전사 실패로 데모 대본을 표시합니다. (\(error.localizedDescription))"
            )
        }
    }
}
