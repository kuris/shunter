import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "대시보드", subtitle: "숏폼 분석과 편집 준비 현황을 한눈에 확인하세요.")

                if app.settings.showSafetyNotice {
                    SafetyNotice(text: "이 앱은 본인 영상 또는 사용 허락을 받은 영상의 대본 추출과 편집 준비를 돕는 도구입니다. 타인의 콘텐츠를 무단 복제하거나 재업로드하지 마세요.")
                }

                HStack(spacing: 16) {
                    StatTile(title: "오늘 만든 프로젝트", value: "\(app.projectStore.todayCount)", systemImage: "calendar")
                    StatTile(title: "전체 프로젝트", value: "\(app.projectStore.projects.count)", systemImage: "folder", tint: .purple)
                    StatTile(title: "내보내기 완료", value: "\(app.projectStore.exportedCount)", systemImage: "checkmark.seal", tint: .green)
                    StatTile(title: "현재 영상", value: app.currentVideo == nil ? "-" : "1", systemImage: "film", tint: .orange)
                }

                Card(title: "빠른 시작", subtitle: "자주 쓰는 작업을 바로 시작하세요.") {
                    HStack(spacing: 12) {
                        quickButton("영상 불러오기", systemImage: "square.and.arrow.down", target: .videoImport)
                        quickButton("쇼츠 검색하기", systemImage: "magnifyingglass", target: .shortsSearch)
                        quickButton("원본 후보 찾기", systemImage: "point.3.connected.trianglepath.dotted", target: .sourceFinder)
                        quickButton("CapCut 내보내기", systemImage: "folder.badge.plus", target: .export)
                    }
                }

                Card(title: "최근 프로젝트", subtitle: "최근 작업한 프로젝트 기록입니다.") {
                    if app.projectStore.recentProjects.isEmpty {
                        Text("아직 프로젝트가 없습니다. 영상을 불러오고 대본을 추출해 보세요.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(app.projectStore.recentProjects) { project in
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name).font(.callout.weight(.medium))
                                        Text(project.updatedAt.relativeKorean)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(text: project.status.displayName, color: color(for: project.status))
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                        }
                    }
                }

                if let folder = app.lastExportFolder {
                    Card(title: "최근 내보내기 폴더", subtitle: folder.lastPathComponent) {
                        HStack {
                            Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Finder에서 열기") {
                                NSWorkspace.shared.activateFileViewerSelecting([folder])
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func quickButton(_ title: String, systemImage: String, target: SidebarItem) -> some View {
        Button {
            app.selectedItem = target
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func color(for status: ProjectStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .transcribing: return .orange
        case .transcribed: return .blue
        case .translated: return .purple
        case .exported: return .green
        }
    }
}
