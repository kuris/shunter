import Foundation
import Combine

@MainActor
final class RewriteViewModel: ObservableObject {
    @Published var originalText: String = ""
    @Published var targetLanguage: TranslateLanguage = .korean
    @Published var style: RewriteStyle = .informative

    @Published var translatedText: String = ""
    @Published var rewrittenText: String = ""
    @Published var titleCandidates: [String] = []
    @Published var hooks: [String] = []

    @Published var isWorking: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    var onTranslated: ((TranslateLanguage, String) -> Void)?
    var onRewritten: ((String) -> Void)?
    var onTitlesGenerated: (([String]) -> Void)?
    var onHooksGenerated: (([String]) -> Void)?

    private let geminiService: GeminiService
    private let settingsStore: SettingsStore

    init(geminiService: GeminiService, settingsStore: SettingsStore) {
        self.geminiService = geminiService
        self.settingsStore = settingsStore
    }

    func translate(sourceText: String, document: TranscriptDocument?) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "번역할 대본이 없습니다."
            return
        }
        isWorking = true
        errorMessage = nil
        statusMessage = "번역 중..."
        let settings = settingsStore.settings

        if settings.hasGeminiKey {
            do {
                let result = try await geminiService.translate(
                    text: text,
                    to: targetLanguage,
                    apiKey: settings.geminiAPIKey,
                    model: settings.geminiTextModel
                )
                translatedText = result
                statusMessage = "번역 완료 (\(targetLanguage.displayName))"
                onTranslated?(targetLanguage, result)
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = ""
            }
        } else if let document {
            let result = MockData.translation(for: document, language: targetLanguage)
            translatedText = result
            statusMessage = "API Key가 없어 데모 번역을 표시합니다."
            onTranslated?(targetLanguage, result)
        } else {
            errorMessage = "Gemini API 키가 없고 대본도 없습니다."
        }
        isWorking = false
    }

    func rewrite(sourceText: String) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "재작성할 대본이 없습니다."
            return
        }
        isWorking = true
        errorMessage = nil
        statusMessage = "재작성 중..."
        let settings = settingsStore.settings

        if settings.hasGeminiKey {
            do {
                let result = try await geminiService.rewrite(
                    text: text,
                    style: style,
                    apiKey: settings.geminiAPIKey,
                    model: settings.geminiTextModel
                )
                rewrittenText = result
                statusMessage = "재작성 완료 (\(style.rawValue))"
                onRewritten?(result)
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = ""
            }
        } else {
            let result = MockData.rewrittenScript(style: style, source: text)
            rewrittenText = result
            statusMessage = "API Key가 없어 데모 재작성 결과를 표시합니다."
            onRewritten?(result)
        }
        isWorking = false
    }

    func generateTitles(sourceText: String) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        errorMessage = nil
        statusMessage = "제목 후보 생성 중..."
        let settings = settingsStore.settings
        if settings.hasGeminiKey, !text.isEmpty {
            do {
                let titles = try await geminiService.generateTitles(
                    from: text,
                    apiKey: settings.geminiAPIKey,
                    model: settings.geminiTextModel
                )
                titleCandidates = titles
                statusMessage = "제목 후보 \(titles.count)개 생성"
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            titleCandidates = MockData.titleCandidates(from: text)
            statusMessage = "데모 제목 후보 \(titleCandidates.count)개를 생성했습니다."
        }
        onTitlesGenerated?(titleCandidates)
        isWorking = false
    }

    func generateHooks(sourceText: String) async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        errorMessage = nil
        statusMessage = "후킹 문장 생성 중..."
        let settings = settingsStore.settings
        if settings.hasGeminiKey, !text.isEmpty {
            do {
                let hooks = try await geminiService.generateHooks(
                    from: text,
                    apiKey: settings.geminiAPIKey,
                    model: settings.geminiTextModel
                )
                self.hooks = hooks
                statusMessage = "후킹 문장 \(hooks.count)개 생성"
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            hooks = MockData.hooks()
            statusMessage = "데모 후킹 문장 \(hooks.count)개를 생성했습니다."
        }
        onHooksGenerated?(hooks)
        isWorking = false
    }
}
