import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case audioTooLarge
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Gemini API 키가 필요합니다."
        case .invalidResponse: return "Gemini 응답을 해석할 수 없습니다."
        case .audioTooLarge: return "오디오 파일이 너무 큽니다. FFmpeg로 wav(16kHz mono)로 추출한 뒤 다시 시도해 주세요."
        case .http(let code, let message):
            return "Gemini API 오류 (HTTP \(code)): \(message.prefix(240))"
        }
    }
}

/// Google Gemini API 연동 서비스.
///
/// - 엔드포인트: `https://generativelanguage.googleapis.com/{version}/models/{model}:generateContent`
/// - 인증: `?key=API_KEY` (쿼리 파라미터)
/// - 텍스트/번역/재작성/제목/후킹 + 오디오 전사(STT)를 모두 담당한다.
///
/// `gemini-3.8-flash`는 텍스트와 오디오 입력을 모두 지원한다(JSON 모드 포함).
/// 503/429(혼잡/쿼터) 시 재시도하고, 버전(v1beta→v1) 폴백을 시도한다.
final class GeminiService {
    private let session: URLSession
    private let baseURL = "https://generativelanguage.googleapis.com"
    private let versions = ["v1beta", "v1"]

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - High level (텍스트)

    func chat(system: String, user: String, apiKey: String, model: String) async throws -> String {
        try await generateText(
            system: system,
            user: user,
            apiKey: apiKey,
            model: model,
            json: false,
            temperature: 0.7
        )
    }

    func translate(text: String, to language: TranslateLanguage, apiKey: String, model: String) async throws -> String {
        let system = "You are a professional subtitle translator. Translate the user's transcript into \(language.displayName). Keep it natural and concise for short-form video subtitles. Return only the translated text."
        return try await generateText(system: system, user: text, apiKey: apiKey, model: model, json: false, temperature: 0.3)
    }

    func rewrite(text: String, style: RewriteStyle, apiKey: String, model: String) async throws -> String {
        let system = """
        You rewrite short-form video scripts. Style: \(style.rawValue).
        Rules:
        - Do NOT copy the original wording.
        - Only reuse the structure and the idea.
        - Create new expressions, examples and sentences.
        - Avoid similarity that could confuse viewers about the original author.
        - Remove any unique expression that could cause copyright issues.
        Return the rewritten script in Korean.
        """
        return try await generateText(system: system, user: text, apiKey: apiKey, model: model, json: false, temperature: 0.8)
    }

    func generateTitles(from text: String, apiKey: String, model: String) async throws -> [String] {
        let system = "Generate 10 catchy Korean short-form video title candidates. Return one title per line, no numbering."
        let response = try await generateText(system: system, user: text, apiKey: apiKey, model: model, json: false, temperature: 0.9)
        return splitLines(response)
    }

    func generateHooks(from text: String, apiKey: String, model: String) async throws -> [String] {
        let system = "Generate 10 Korean hooking opening lines for a short-form video. Return one line each, no numbering."
        let response = try await generateText(system: system, user: text, apiKey: apiKey, model: model, json: false, temperature: 0.9)
        return splitLines(response)
    }

    func extractSearchTerms(title: String, description: String, script: String, apiKey: String, model: String) async throws -> String {
        let system = """
        You help find the original source of a short-form video.
        From the provided title/description/transcript, extract:
        - 10 core keywords
        - 5 key sentences
        - TikTok search queries
        - Google search queries (including site:tiktok.com operators)
        - queries translated into English, Japanese and Chinese
        Organize the answer with clear section headers in Korean.
        """
        let user = "제목: \(title)\n설명: \(description)\n대본: \(script)"
        return try await generateText(system: system, user: user, apiKey: apiKey, model: model, json: false, temperature: 0.5)
    }

    // MARK: - Audio transcription (STT)

    /// 로컬 오디오 파일을 Gemini에 인라인으로 보내 대본(세그먼트 포함)을 받는다.
    func transcribeAudio(audioURL: URL, apiKey: String, model: String) async throws -> TranscriptDocument {
        let data = try Data(contentsOf: audioURL)
        guard data.count <= 15 * 1024 * 1024 else { throw GeminiError.audioTooLarge }

        let base64 = data.base64EncodedString()
        let mimeType = Self.mimeType(for: audioURL)
        let prompt = """
        Transcribe this audio in its original language.
        Return ONLY minified JSON with this shape:
        {"language":"ko","segments":[{"start":0.0,"end":2.4,"text":"..."}],"text":"full transcript"}
        Times are seconds. Do not add commentary.
        """

        let parts: [Part] = [
            .init(text: prompt, inlineData: nil),
            .init(text: nil, inlineData: .init(mimeType: mimeType, data: base64))
        ]

        let raw: String
        do {
            raw = try await generate(apiKey: apiKey, model: model, parts: parts, system: nil, json: true, temperature: 0.1)
        } catch {
            // 일부 모델은 JSON 모드 미지원 → 일반 모드로 재시도 후 파싱
            raw = try await generate(apiKey: apiKey, model: model, parts: parts, system: nil, json: false, temperature: 0.1)
        }
        return Self.parseTranscript(raw, fileName: audioURL.lastPathComponent)
    }

    // MARK: - Core

    private func generateText(system: String, user: String, apiKey: String, model: String, json: Bool, temperature: Double) async throws -> String {
        let parts = [Part(text: user, inlineData: nil)]
        return try await generate(apiKey: apiKey, model: model, parts: parts, system: system, json: json, temperature: temperature)
    }

    private func generate(apiKey: String, model: String, parts: [Part], system: String?, json: Bool, temperature: Double) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { throw GeminiError.missingAPIKey }

        let contents = [Content(role: "user", parts: parts)]
        var lastError: Error = GeminiError.invalidResponse

        for version in versions {
            for attempt in 0..<3 {
                do {
                    return try await perform(
                        version: version,
                        model: model,
                        apiKey: trimmedKey,
                        contents: contents,
                        system: system,
                        json: json,
                        temperature: temperature
                    )
                } catch let error as GeminiError {
                    lastError = error
                    guard case .http(let code, _) = error else { break }
                    if code == 429 || code == 503 {
                        if attempt < 2 {
                            try? await Task.sleep(nanoseconds: UInt64(1_500_000_000) * UInt64(attempt + 1))
                            continue
                        }
                        break
                    }
                    // 404(모델/버전 불가), 400 등은 다음 버전 시도
                    break
                }
            }
        }
        throw lastError
    }

    private func perform(
        version: String,
        model: String,
        apiKey: String,
        contents: [Content],
        system: String?,
        json: Bool,
        temperature: Double
    ) async throws -> String {
        var components = URLComponents(string: "\(baseURL)/\(version)/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw GeminiError.invalidResponse }

        let payload = GenerateRequest(
            contents: contents,
            systemInstruction: system.map { SystemInstruction(parts: [TextPart(text: $0)]) },
            generationConfig: GenerationConfig(
                temperature: temperature,
                responseMimeType: json ? "application/json" : nil
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 180

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GeminiError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(GenerateResponse.self, from: data)
            let message = decoded?.error?.message ?? String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.http(http.statusCode, message)
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        let text = decoded.candidates?.first?.content?.parts?.compactMap { $0.text }.joined() ?? ""
        guard !text.isEmpty else {
            if let block = decoded.promptFeedback?.blockReason {
                throw GeminiError.http(200, "응답이 차단되었습니다: \(block)")
            }
            throw GeminiError.invalidResponse
        }
        return text
    }

    // MARK: - Helpers

    private func splitLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line -> String in
                // "1. 제목", "- 제목", "제목:" 같은 접두 제거
                var cleaned = line
                if let range = cleaned.range(of: "^\\s*[0-9]+[.)]\\s*", options: .regularExpression) {
                    cleaned.removeSubrange(range)
                }
                if cleaned.hasPrefix("- ") || cleaned.hasPrefix("• ") {
                    cleaned = String(cleaned.dropFirst(2))
                }
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4": return "audio/mp4"
        case "aac": return "audio/aac"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        case "aiff", "aif": return "audio/aiff"
        default: return "audio/mp4"
        }
    }

    /// Gemini가 돌려준 JSON 문자열을 TranscriptDocument로 변환한다.
    static func parseTranscript(_ raw: String, fileName: String) -> TranscriptDocument {
        let jsonString = extractJSONObject(from: raw)
        if let data = jsonString.data(using: .utf8),
           let payload = try? JSONDecoder().decode(TranscriptPayload.self, from: data) {
            let segments = (payload.segments ?? []).compactMap { item -> TranscriptSegment? in
                guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                return TranscriptSegment(startTime: item.start ?? 0, endTime: item.end ?? ((item.start ?? 0) + 2), text: text)
            }
            var document = TranscriptDocument(
                sourceVideoFileName: fileName,
                language: payload.language ?? "unknown",
                segments: segments,
                plainText: payload.text ?? segments.map(\.text).joined(separator: " ")
            )
            if document.plainText.isEmpty { document.rebuildPlainText() }
            return document
        }

        // JSON 파싱 실패 시 전체 텍스트를 한 세그먼트로 저장
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var document = TranscriptDocument(
            sourceVideoFileName: fileName,
            language: "unknown",
            segments: [TranscriptSegment(startTime: 0, endTime: 3, text: cleaned)],
            plainText: cleaned
        )
        if document.plainText.isEmpty { document.rebuildPlainText() }
        return document
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }

    // MARK: - Request / Response DTO

    struct Part: Encodable {
        var text: String?
        var inlineData: InlineData?
    }

    struct InlineData: Encodable {
        let mimeType: String
        let data: String
    }

    private struct Content: Encodable {
        let role: String?
        let parts: [Part]
    }

    private struct TextPart: Encodable {
        let text: String
    }

    private struct SystemInstruction: Encodable {
        let parts: [TextPart]
    }

    private struct GenerationConfig: Encodable {
        var temperature: Double?
        var responseMimeType: String?
    }

    private struct GenerateRequest: Encodable {
        let contents: [Content]
        var systemInstruction: SystemInstruction?
        var generationConfig: GenerationConfig?
    }

    private struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
            let finishReason: String?
        }
        struct PromptFeedback: Decodable { let blockReason: String? }
        struct APIError: Decodable {
            let code: Int?
            let message: String?
            let status: String?
        }
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
        let error: APIError?
    }

    private struct TranscriptPayload: Decodable {
        struct Segment: Decodable {
            let start: Double?
            let end: Double?
            let text: String?
        }
        let language: String?
        let segments: [Segment]?
        let text: String?
    }
}
