import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $app.selectedItem)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            detailView
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch app.selectedItem {
        case .dashboard: DashboardView()
        case .shortsSearch: ShortsSearchView()
        case .sourceFinder: SourceFinderView()
        case .videoImport: VideoImportView()
        case .transcription: TranscriptionView()
        case .rewrite: RewriteView()
        case .export: ExportView()
        case .settings: SettingsView()
        }
    }
}
