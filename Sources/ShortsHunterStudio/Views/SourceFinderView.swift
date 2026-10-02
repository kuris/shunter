import SwiftUI
import AppKit

struct SourceFinderView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        SourceFinderContentView(
            vm: app.sourceFinderViewModel,
            onOpenImport: { app.selectedItem = .videoImport }
        )
    }
}

private struct SourceFinderContentView: View {
    @ObservedObject var vm: SourceFinderViewModel
    let onOpenImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "원본 후보 찾기", subtitle: "쇼츠 정보로 검색어 세트를 만들고 TikTok/Google에서 원본 후보를 찾아보세요.")

                SafetyNotice(text: "TikTok 링크는 출처 기록과 검색어 생성에만 사용됩니다. 영상 처리는 권한 있는 파일을 직접 불러온 경우에만 가능합니다.")

                tiktokSection
                inputSection

                if !vm.keywords.isEmpty || !vm.keySentences.isEmpty {
                    generatedSection
                }

                comparisonSection

                SafetyNotice(text: vm.disclaimer, systemImage: "info.circle")
            }
            .padding(24)
        }
    }

    private var tiktokSection: some View {
        Card(title: "TikTok / 출처 기록", subtitle: "TikTok 링크는 출처 기록과 분석용입니다.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TikTok URL").font(.caption).foregroundStyle(.secondary)
                        TextField("https://www.tiktok.com/@.../video/...", text: $vm.tiktokURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("플랫폼").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $vm.tiktokPlatform) {
                            Text("TikTok").tag("TikTok")
                            Text("YouTube").tag("YouTube")
                            Text("Instagram").tag("Instagram")
                            Text("기타").tag("기타")
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("원작자/계정명").font(.caption).foregroundStyle(.secondary)
                        TextField("@creator", text: $vm.tiktokCreator)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("메모").font(.caption).foregroundStyle(.secondary)
                        TextField("출처 확인 메모", text: $vm.tiktokMemo)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                HStack(spacing: 12) {
                    Button {
                        Task { await vm.fetchTikTokMetadata() }
                    } label: {
                        Label("공개 메타데이터 조회", systemImage: "cloud")
                    }
                    .disabled(vm.isFetchingTikTok)

                    Button {
                        if let url = URL(string: vm.tiktokURL) { NSWorkspace.shared.open(url) }
                    } label: {
                        Label("브라우저에서 열기", systemImage: "safari")
                    }
                    .disabled(vm.tiktokURL.isEmpty)

                    Button {
                        onOpenImport()
                    } label: {
                        Label("권한 있는 영상 파일 불러오기", systemImage: "square.and.arrow.down")
                    }

                    Spacer()
                    StatusBadge(text: vm.tiktokStatus, color: vm.tiktokStatus.contains("완료") ? .green : .orange)
                }
                if !vm.tiktokTitle.isEmpty {
                    Text("제목: \(vm.tiktokTitle)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var inputSection: some View {
        Card(title: "쇼츠 정보 입력", subtitle: "제목/설명/대본/해시태그를 입력하면 검색어 세트를 생성합니다.") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("유튜브 쇼츠 URL") {
                    TextField("https://www.youtube.com/watch?v=...", text: $vm.url).textFieldStyle(.roundedBorder)
                }
                labeledField("제목") {
                    TextField("영상 제목", text: $vm.title).textFieldStyle(.roundedBorder)
                }
                labeledField("설명") {
                    TextField("설명", text: $vm.description, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
                labeledField("대본 텍스트") {
                    TextEditor(text: $vm.script)
                        .frame(minHeight: 100)
                        .font(.body)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                }
                labeledField("해시태그") {
                    TextField("#태그1 #태그2", text: $vm.hashtags).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button {
                        vm.generate()
                    } label: {
                        Label("검색어 생성", systemImage: "wand.and.stars")
                    }
                    Spacer()
                    if !vm.generationMessage.isEmpty {
                        Text(vm.generationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var generatedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                listCard("핵심 키워드", items: vm.keywords, icon: "number")
                listCard("핵심 문장", items: vm.keySentences, icon: "text.quote")
            }
            HStack(spacing: 16) {
                listCard("TikTok 검색어", items: vm.tiktokQueries, icon: "music.note")
                listCard("Google 검색어", items: vm.googleQueries, icon: "globe")
            }
            HStack(spacing: 16) {
                listCard("영어 검색어", items: vm.englishQueries, icon: "character.book.closed")
                listCard("일본어 검색어", items: vm.japaneseQueries, icon: "character.book.closed")
                listCard("중국어 검색어", items: vm.chineseQueries, icon: "character.book.closed")
            }
            listCard("후보 확인 체크리스트", items: vm.checklist, icon: "checklist")
        }
    }

    private func listCard(_ title: String, items: [String], icon: String) -> some View {
        Card(title: title) {
            if items.isEmpty {
                Text("내용 없음").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(index + 1).").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text(item).font(.callout).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private var comparisonSection: some View {
        Card(title: "원본 후보 유사도 비교", subtitle: "후보 영상의 제목/대본을 입력해 유사도를 비교합니다.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    labeledField("소스 업로드일") {
                        DatePicker("", selection: $vm.sourcePublishedAt, displayedComponents: .date).labelsHidden()
                    }
                    labeledField("후보 업로드일") {
                        DatePicker("", selection: $vm.candidatePublishedAt, displayedComponents: .date).labelsHidden()
                    }
                }
                labeledField("후보 제목") {
                    TextField("후보 영상 제목", text: $vm.candidateTitle).textFieldStyle(.roundedBorder)
                }
                labeledField("후보 대본") {
                    TextEditor(text: $vm.candidateScript)
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                }
                Button {
                    vm.compare()
                } label: {
                    Label("유사도 비교", systemImage: "arrow.triangle.branch")
                }

                if let comparison = vm.comparison {
                    Divider()
                    HStack {
                        Text("종합 유사도").font(.headline)
                        Spacer()
                        Text(String(format: "%.1f", comparison.totalSimilarity))
                            .font(.title2.bold().monospacedDigit())
                        StatusBadge(text: comparison.verdict, color: verdictColor(comparison.totalSimilarity))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        metricRow("제목 유사도", comparison.titleSimilarity)
                        metricRow("대본 유사도", comparison.scriptSimilarity)
                        metricRow("키워드 유사도", comparison.keywordSimilarity)
                        metricRow("업로드 날짜 점수", comparison.dateScore)
                    }
                }
            }
        }
    }

    private func metricRow(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(String(format: "%.1f", value)).font(.caption.monospacedDigit())
            ProgressView(value: value, total: 100).frame(width: 160)
        }
    }

    private func verdictColor(_ score: Double) -> Color {
        switch score {
        case 85...: return .green
        case 70..<85: return .mint
        case 50..<70: return .orange
        default: return .gray
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
