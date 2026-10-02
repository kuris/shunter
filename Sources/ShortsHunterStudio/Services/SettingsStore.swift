import Foundation
import Combine

/// 설정을 로컬 JSON에 저장/로드한다.
///
/// NOTE: MVP에서는 API Key를 로컬 JSON에 저장한다. 설정 화면에 보안 경고를 표시한다.
/// TODO: Keychain(Security.framework) 연동으로 이전.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    private let fileManager = FileManager.default

    init() {
        if let data = try? Data(contentsOf: fileManager.settingsFileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
        applyEnvironmentOverrides()
    }

    /// .env / 환경변수의 키가 있으면 설정값을 덮어쓴다.
    /// (개발/테스트 편의를 위해 .env를 source of truth로 사용)
    private func applyEnvironmentOverrides() {
        var updated = settings
        if let key = EnvLoader.value("GEMINI_API_KEY"), !key.isEmpty { updated.geminiAPIKey = key }
        if let model = EnvLoader.value("GEMINI_TEXT_MODEL"), !model.isEmpty { updated.geminiTextModel = model }
        if let model = EnvLoader.value("GEMINI_AUDIO_MODEL"), !model.isEmpty { updated.geminiAudioModel = model }
        if let key = EnvLoader.value("YOUTUBE_API_KEY"), !key.isEmpty { updated.youTubeAPIKey = key }
        if updated != settings {
            settings = updated
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try fileManager.writeAtomically(data, to: fileManager.settingsFileURL)
        } catch {
            print("[SettingsStore] 저장 실패: \(error)")
        }
    }

    func reset() {
        settings = AppSettings()
    }
}
