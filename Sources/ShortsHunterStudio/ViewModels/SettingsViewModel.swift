import Foundation
import Combine
import AppKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var ffmpegTestResult: String = ""
    @Published var youTubeTestResult: String = ""
    @Published var geminiTestResult: String = ""
    @Published var isTesting: Bool = false

    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func testFFmpeg() async {
        isTesting = true
        defer { isTesting = false }
        guard let path = settingsStore.settings.resolvedFFmpegPath else {
            ffmpegTestResult = "FFmpeg를 찾을 수 없습니다. 경로를 확인해 주세요."
            return
        }
        do {
            let result = try await ProcessRunner.run(executable: path, arguments: ["-version"])
            if result.exitCode == 0, let firstLine = result.standardOutput.components(separatedBy: .newlines).first {
                ffmpegTestResult = "정상: \(firstLine)"
            } else {
                ffmpegTestResult = "실행 실패 (exit \(result.exitCode))"
            }
        } catch {
            ffmpegTestResult = "실행 실패: \(error.localizedDescription)"
        }
    }

    func testYouTube() async {
        isTesting = true
        defer { isTesting = false }
        let key = settingsStore.settings.youTubeAPIKey
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            youTubeTestResult = "API Key를 입력해 주세요."
            return
        }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        components?.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "part", value: "id"),
            URLQueryItem(name: "chart", value: "mostPopular"),
            URLQueryItem(name: "maxResults", value: "1")
        ]
        guard let url = components?.url else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                youTubeTestResult = "정상 (HTTP \(http.statusCode))"
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                youTubeTestResult = "실패 (HTTP \(code))"
            }
        } catch {
            youTubeTestResult = "실패: \(error.localizedDescription)"
        }
    }

    func testGemini() async {
        isTesting = true
        defer { isTesting = false }
        let settings = settingsStore.settings
        guard settings.hasGeminiKey else {
            geminiTestResult = "API Key를 입력해 주세요."
            return
        }
        do {
            let reply = try await GeminiService().chat(
                system: "Reply with the single word: OK",
                user: "ping",
                apiKey: settings.geminiAPIKey,
                model: settings.geminiTextModel
            )
            geminiTestResult = "정상 (\(settings.geminiTextModel)): \(reply.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))"
        } catch {
            geminiTestResult = "실패: \(error.localizedDescription)"
        }
    }

    func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.settings.defaultSaveFolder = url.path
        }
    }
}
