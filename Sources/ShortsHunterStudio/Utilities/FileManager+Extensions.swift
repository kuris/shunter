import Foundation

extension FileManager {
    var applicationSupportDirectory: URL {
        let base = urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ShortsHunterStudio", isDirectory: true)
    }

    var projectsFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("projects.json")
    }

    var settingsFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("settings.json")
    }

    /// 디렉터리가 없으면 생성한다.
    @discardableResult
    func ensureDirectory(at url: URL) throws -> URL {
        if !fileExists(atPath: url.path) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// 파일을 안전하게 덮어써 쓴다.
    func writeAtomically(_ data: Data, to url: URL) throws {
        try ensureDirectory(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    /// 중복되지 않는 파일명을 만든다 (예: name 2.txt).
    func uniqueFileURL(in directory: URL, preferredName: String) -> URL {
        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(preferredName)
        var index = 2
        while fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        }
        return candidate
    }
}
