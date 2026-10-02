import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        SettingsContentView(store: app.settingsStore, vm: app.settingsViewModel)
    }
}

private struct SettingsContentView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var vm: SettingsViewModel

    @State private var showGeminiKey: Bool = false
    @State private var showYouTubeKey: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "설정", subtitle: "API Key, FFmpeg 경로, 기본값을 관리합니다.")

                SafetyNotice(
                    text: "API Key는 로컬 설정 JSON에 저장됩니다. 또한 프로젝트 루트나 앱 번들에 있는 .env 파일(GEMINI_API_KEY / YOUTUBE_API_KEY)이 있으면 그 값이 우선 적용됩니다. 공용 PC에서는 사용 후 삭제하세요. (TODO: Keychain 저장)",
                    systemImage: "lock.shield"
                )

                geminiCard
                youTubeCard
                ffmpegCard
                defaultsCard
                safetyCard

                Card {
                    HStack {
                        Button {
                            store.save()
                        } label: {
                            Label("설정 저장", systemImage: "square.and.arrow.down")
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.reset()
                        } label: {
                            Label("기본값으로 초기화", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var geminiCard: some View {
        Card(title: "Google Gemini", subtitle: "대본 추출(STT)과 번역/재작성에 사용합니다.") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("Gemini API Key") {
                    HStack {
                        if showGeminiKey {
                            TextField("AIza... 또는 AQ...", text: $store.settings.geminiAPIKey).textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("AIza... 또는 AQ...", text: $store.settings.geminiAPIKey).textFieldStyle(.roundedBorder)
                        }
                        Toggle("표시", isOn: $showGeminiKey).toggleStyle(.checkbox)
                    }
                }
                HStack(spacing: 12) {
                    labeledField("텍스트 모델") {
                        TextField("gemini-3.8-flash", text: $store.settings.geminiTextModel).textFieldStyle(.roundedBorder)
                    }
                    labeledField("오디오(STT) 모델") {
                        TextField("gemini-3.8-flash", text: $store.settings.geminiAudioModel).textFieldStyle(.roundedBorder)
                    }
                }
                Text("무료 키 발급: https://aistudio.google.com/apikey   ·   신규 프로젝트는 gemini-3.8-flash 계열을 사용하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                testRow(buttonTitle: "Gemini 테스트", action: { Task { await vm.testGemini() } }, result: vm.geminiTestResult)
            }
        }
    }

    private var youTubeCard: some View {
        Card(title: "YouTube Data API", subtitle: "쇼츠 검색에 사용합니다.") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("YouTube API Key") {
                    HStack {
                        if showYouTubeKey {
                            TextField("AIza...", text: $store.settings.youTubeAPIKey).textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("AIza...", text: $store.settings.youTubeAPIKey).textFieldStyle(.roundedBorder)
                        }
                        Toggle("표시", isOn: $showYouTubeKey).toggleStyle(.checkbox)
                    }
                }
                testRow(buttonTitle: "YouTube 테스트", action: { Task { await vm.testYouTube() } }, result: vm.youTubeTestResult)
            }
        }
    }

    private var ffmpegCard: some View {
        Card(title: "FFmpeg", subtitle: "오디오 추출(wav)에 사용합니다. 선택 사항입니다.") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("FFmpeg 경로") {
                    TextField("/opt/homebrew/bin/ffmpeg", text: $store.settings.ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 12) {
                    Button {
                        if let path = AppSettings.ffmpegCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                            store.settings.ffmpegPath = path
                        }
                    } label: {
                        Label("자동 탐지", systemImage: "magnifyingglass")
                    }
                    testRow(buttonTitle: "FFmpeg 테스트", action: { Task { await vm.testFFmpeg() } }, result: vm.ffmpegTestResult)
                }
            }
        }
    }

    private var defaultsCard: some View {
        Card(title: "기본값") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("기본 저장 폴더") {
                    HStack {
                        Text(store.settings.defaultSaveFolder.isEmpty ? store.settings.resolvedSaveFolder.path : store.settings.defaultSaveFolder)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("선택") { vm.chooseSaveFolder() }
                    }
                }
                HStack(spacing: 16) {
                    labeledField("기본 번역 언어") {
                        Picker("", selection: $store.settings.defaultTranslateLanguage) {
                            ForEach(TranslateLanguage.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    labeledField("기본 검색 기간") {
                        Picker("", selection: $store.settings.defaultSearchPeriod) {
                            ForEach(SearchPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    labeledField("최소 조회수") {
                        TextField("10000", value: $store.settings.minViewCount, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    labeledField("쇼츠 길이 기준(초)") {
                        TextField("60", value: $store.settings.shortsMaxDuration, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
            }
        }
    }

    private var safetyCard: some View {
        Card(title: "안전 안내") {
            Toggle("앱 화면에 안전 안내 문구 표시", isOn: $store.settings.showSafetyNotice)
        }
    }

    private func testRow(buttonTitle: String, action: @escaping () -> Void, result: String) -> some View {
        HStack(spacing: 12) {
            Button(buttonTitle, action: action)
                .disabled(vm.isTesting)
            if !result.isEmpty {
                Text(result).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
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
