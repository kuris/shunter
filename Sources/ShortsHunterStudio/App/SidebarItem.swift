import Foundation

/// 사이드바 메뉴 항목.
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "대시보드"
    case shortsSearch = "쇼츠 검색"
    case sourceFinder = "원본 후보 찾기"
    case videoImport = "영상 불러오기"
    case transcription = "자막 추출"
    case rewrite = "번역/재작성"
    case export = "CapCut 내보내기"
    case settings = "설정"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .shortsSearch: return "magnifyingglass"
        case .sourceFinder: return "point.3.connected.trianglepath.dotted"
        case .videoImport: return "square.and.arrow.down"
        case .transcription: return "waveform"
        case .rewrite: return "text.badge.checkmark"
        case .export: return "folder.badge.plus"
        case .settings: return "gearshape"
        }
    }
}
