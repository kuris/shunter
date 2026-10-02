import Foundation
import Combine

/// 프로젝트 기록 저장소. JSON 기반.
///
/// Repository 패턴의 최소 구현이며, 이후 SwiftData로 교체할 수 있도록
/// 저장/조회/삭제 인터페이스를 분리해 둔다.
@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [ProjectItem] = []

    private let fileManager = FileManager.default

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileManager.projectsFileURL) else {
            projects = []
            return
        }
        do {
            projects = try JSONDecoder().decode([ProjectItem].self, from: data)
            projects.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            print("[ProjectStore] 로드 실패: \(error)")
            projects = []
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(projects)
            try fileManager.writeAtomically(data, to: fileManager.projectsFileURL)
        } catch {
            print("[ProjectStore] 저장 실패: \(error)")
        }
    }

    @discardableResult
    func upsert(_ project: ProjectItem) -> ProjectItem {
        var updated = project
        updated.updatedAt = Date()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = updated
        } else {
            projects.append(updated)
        }
        projects.sort { $0.updatedAt > $1.updatedAt }
        save()
        return updated
    }

    func delete(_ project: ProjectItem) {
        projects.removeAll { $0.id == project.id }
        save()
    }

    var todayCount: Int {
        let calendar = Calendar.current
        return projects.filter { calendar.isDateInToday($0.createdAt) }.count
    }

    var exportedCount: Int {
        projects.filter { $0.status == .exported }.count
    }

    var recentProjects: [ProjectItem] {
        Array(projects.prefix(5))
    }
}
