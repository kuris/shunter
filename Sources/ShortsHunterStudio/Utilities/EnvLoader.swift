import Foundation

/// .env 파일과 프로세스 환경변수에서 API 키를 읽는다.
///
/// 우선순위(먼저 발견된 값이 이김):
///   1. 프로세스 환경변수 (예: GEMINI_API_KEY)
///   2. 앱 번들 Resources/.env  (빌드 시 .env를 번들에 포함)
///   3. 현재 작업 디렉터리의 .env  (개발용)
///   4. ~/Library/Application Support/ShortsHunterStudio/.env
///
/// 지원 키: GEMINI_API_KEY, GEMINI_TEXT_MODEL, GEMINI_AUDIO_MODEL, YOUTUBE_API_KEY
enum EnvLoader {

    static func value(_ key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        return parse(fileAt: candidateFiles()).first { $0.key == key }?.value
    }

    /// 모든 후보 .env 값을 key:value로 병합한다(먼저 발견된 값 우선).
    static func parse(fileAt urls: [URL]) -> [String: String] {
        var result: [String: String] = [:]
        for url in urls {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (key, value) in parse(text) where result[key] == nil {
                result[key] = value
            }
        }
        return result
    }

    private static func candidateFiles() -> [URL] {
        var urls: [URL] = []
        if let resource = Bundle.main.resourceURL {
            urls.append(resource.appendingPathComponent(".env"))
        }
        urls.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"))
        urls.append(FileManager.default.applicationSupportDirectory.appendingPathComponent(".env"))
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(executableDir.appendingPathComponent(".env"))
        }
        return urls
    }

    private static func parse(_ text: String) -> [String: String] {
        var dict: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let equalsIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty {
                dict[key] = value
            }
        }
        return dict
    }
}
