import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShortsSearchView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        ShortsSearchContentView(
            vm: app.searchViewModel,
            settings: app.settingsStore.settings,
            onSendToSourceFinder: { video in
                let finder = app.sourceFinderViewModel
                finder.title = video.title
                finder.description = video.description
                finder.url = video.url
                finder.hashtags = video.tags.joined(separator: " ")
                finder.generate()
                app.selectedItem = .sourceFinder
            }
        )
    }
}

private struct ShortsSearchContentView: View {
    @ObservedObject var vm: ShortsSearchViewModel
    let settings: AppSettings
    let onSendToSourceFinder: (VideoResult) -> Void
    @State private var selection: VideoResult.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "쇼츠 검색", subtitle: "키워드로 유튜브 쇼츠 후보를 찾고 바이럴 점수로 비교하세요.")

                if !settings.hasYouTubeKey {
                    SafetyNotice(
                        text: "YouTube API Key가 없어 데모 데이터로 동작합니다. 설정에서 본인의 API Key를 입력하면 실제 검색 결과를 사용할 수 있습니다.",
                        systemImage: "key"
                    )
                }

                Card(title: "검색 조건") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            labeledField("키워드") {
                                TextField("예: 아침 스트레칭", text: $vm.keyword)
                            }
                            labeledField("국가/지역") {
                                TextField("KR", text: $vm.regionCode).frame(width: 80)
                            }
                            labeledField("기간") {
                                Picker("", selection: $vm.period) {
                                    ForEach(SearchPeriod.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .labelsHidden()
                            }
                            labeledField("정렬") {
                                Picker("", selection: $vm.sort) {
                                    ForEach(SearchSort.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .labelsHidden()
                            }
                        }
                        HStack(spacing: 12) {
                            labeledField("최소 조회수") {
                                TextField("10000", value: $vm.minViewCount, format: .number).frame(width: 120)
                            }
                            labeledField("최대 길이(초)") {
                                TextField("60", value: $vm.maxDuration, format: .number).frame(width: 90)
                            }
                            Spacer()
                            Button {
                                Task { await vm.search() }
                            } label: {
                                Label("검색", systemImage: "magnifyingglass")
                            }
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(vm.isSearching)

                            Button {
                                exportCSV()
                            } label: {
                                Label("CSV 내보내기", systemImage: "square.and.arrow.up")
                            }
                            .disabled(vm.results.isEmpty)
                        }
                    }
                }

                Card(title: "검색 결과", subtitle: vm.statusMessage.isEmpty ? "총 \(vm.results.count)건" : vm.statusMessage) {
                    if vm.isSearching {
                        HStack { ProgressView(); Text("검색 중...").foregroundStyle(.secondary) }
                    } else if vm.results.isEmpty {
                        Text("검색 결과가 없습니다. 검색을 실행해 주세요.").foregroundStyle(.secondary)
                    } else {
                        resultsTable
                    }
                }

                if let video = vm.selectedVideo {
                    analysisPanel(video)
                }
            }
            .padding(24)
        }
    }

    private var resultsTable: some View {
        Table(vm.results, selection: $selection) {
            TableColumn("제목") { video in
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title).lineLimit(1)
                    Text(video.channelTitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .width(min: 220, ideal: 280)

            TableColumn("업로드일") { Text($0.publishedText) }
                .width(90)
            TableColumn("길이") { Text($0.durationText).monospacedDigit() }
                .width(60)
            TableColumn("조회수") { Text($0.viewCount.formatted()).monospacedDigit() }
                .width(90)
            TableColumn("좋아요") { Text($0.likeCount.formatted()).monospacedDigit() }
                .width(80)
            TableColumn("댓글") { Text($0.commentCount.formatted()).monospacedDigit() }
                .width(70)
            TableColumn("구독자") { Text($0.subscriberCount.formatted()).monospacedDigit() }
                .width(80)
            TableColumn("구독자 대비") { Text(String(format: "%.2fx", $0.subscriberRatio)).monospacedDigit() }
                .width(80)
            TableColumn("바이럴 점수") { ViralScoreBadge(score: $0.viralScore) }
                .width(150)
            TableColumn("작업") { video in
                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: video.url) { NSWorkspace.shared.open(url) }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderless)
                    .help("YouTube에서 열기")

                    Button("분석") { vm.selectedVideo = video }
                        .buttonStyle(.borderless)
                }
            }
            .width(80)
        }
        .frame(minHeight: 320)
    }

    private func analysisPanel(_ video: VideoResult) -> some View {
        Card(title: "선택 영상 분석", subtitle: video.title) {
            let breakdown = ViralScoreCalculator.breakdown(
                viewCount: video.viewCount,
                likeCount: video.likeCount,
                commentCount: video.commentCount,
                subscriberCount: video.subscriberCount,
                publishedAt: video.publishedAt,
                durationSeconds: video.durationSeconds
            )
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ViralScoreBadge(score: video.viralScore)
                    Spacer()
                    Button {
                        if let url = URL(string: video.url) { NSWorkspace.shared.open(url) }
                    } label: {
                        Label("YouTube에서 열기", systemImage: "arrow.up.right.square")
                    }
                    Button {
                        onSendToSourceFinder(video)
                    } label: {
                        Label("원본 후보 찾기로 보내기", systemImage: "arrow.right.doc.on.clipboard")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    metricRow("구독자 대비 조회수 점수 (40%)", breakdown.subscriberRatioScore)
                    metricRow("좋아요 비율 점수 (20%)", breakdown.likeRateScore)
                    metricRow("댓글 비율 점수 (15%)", breakdown.commentRateScore)
                    metricRow("최신성 점수 (15%)", breakdown.freshnessScore)
                    metricRow("숏폼 적합도 점수 (10%)", breakdown.shortsFitScore)
                }

                if !video.description.isEmpty {
                    Divider()
                    Text("설명").font(.caption.bold())
                    Text(video.description).font(.callout).foregroundStyle(.secondary).lineLimit(4)
                }
                if !video.tags.isEmpty {
                    Text(video.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricRow(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(String(format: "%.1f", value)).font(.caption.monospacedDigit())
            ProgressView(value: value, total: 100).frame(width: 140)
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "shorts_search_results.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            try? Data(vm.exportCSV().utf8).write(to: url, options: .atomic)
        }
    }
}
