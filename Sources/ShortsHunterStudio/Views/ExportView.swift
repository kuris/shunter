import SwiftUI
import AppKit

struct ExportView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        ExportContentView(vm: app.exportViewModel, pipeline: PipelineSnapshot(app: app))
    }
}

/// 내보내기에 필요한 파이프라인 상태 스냅샷.
private struct PipelineSnapshot {
    var videoFileURL: URL?
    var videoDuration: Double
    var audioFileURL: URL?
    var transcript: TranscriptDocument?
    var translations: [TranslateLanguage: String]
    var rewrittenScript: String
    var titleCandidates: [String]
    var hooks: [String]

    @MainActor
    init(app: AppViewModel) {
        self.videoFileURL = app.currentVideo?.fileURL
        self.videoDuration = app.currentVideo?.duration ?? 0
        self.audioFileURL = app.audioFileURL
        self.transcript = app.currentTranscript
        self.translations = app.translations
        self.rewrittenScript = app.rewrittenScript
        self.titleCandidates = app.titleCandidates
        self.hooks = app.hooks
    }
}

private struct ExportContentView: View {
    @ObservedObject var vm: ExportViewModel
    let pipeline: PipelineSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "CapCut 내보내기", subtitle: "CapCut에서 바로 불러올 수 있는 파일 묶음을 폴더로 생성합니다.")

                SafetyNotice(text: "내보낸 SRT/TXT/영상 파일은 CapCut에서 직접 불러와 편집할 수 있습니다.")

                projectCard
                optionsCard
                sourceCard
                actionCard

                if let result = vm.result {
                    resultCard(result)
                }
            }
            .padding(24)
        }
    }

    private var projectCard: some View {
        Card(title: "프로젝트") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("프로젝트명").font(.caption).foregroundStyle(.secondary)
                    TextField("쇼츠 프로젝트", text: $vm.projectName).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("저장 위치").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(vm.outputDirectory.path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("변경", action: chooseFolder)
                    }
                }
                Text("폴더명: Project_키워드_\(DateFormatter.folderTimestamp.string(from: Date()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optionsCard: some View {
        Card(title: "포함할 파일") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("원본 영상 파일 복사 (original_video)", isOn: $vm.includeOriginalVideo)
                    .disabled(pipeline.videoFileURL == nil)
                Toggle("추출 오디오 복사 (audio_extract)", isOn: $vm.includeAudio)
                    .disabled(pipeline.audioFileURL == nil)
                Divider()
                includedRow("transcript_original.txt", available: pipeline.transcript != nil)
                includedRow("subtitle_original.srt", available: pipeline.transcript != nil)
                ForEach(Array(pipeline.translations.keys), id: \.self) { language in
                    includedRow("transcript_\(language.rawValue).txt / subtitle_\(language.rawValue).srt", available: true)
                }
                includedRow("rewritten_script.txt", available: !pipeline.rewrittenScript.isEmpty)
                includedRow("title_candidates.txt", available: !pipeline.titleCandidates.isEmpty)
                includedRow("hooks.txt", available: !pipeline.hooks.isEmpty)
                includedRow("source_notes.txt / project_metadata.json", available: true)
            }
        }
    }

    private func includedRow(_ name: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(available ? .green : .secondary)
            Text(name).font(.callout)
            Spacer()
            if !available {
                Text("데이터 없음").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var sourceCard: some View {
        Card(title: "출처 기록", subtitle: "권한 상태와 출처를 기록해 source_notes.txt에 저장합니다.") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    labeledField("플랫폼") {
                        TextField("TikTok / YouTube", text: $vm.sourcePlatform).textFieldStyle(.roundedBorder)
                    }
                    labeledField("원작자/계정") {
                        TextField("@creator", text: $vm.sourceCreator).textFieldStyle(.roundedBorder)
                    }
                }
                labeledField("원본 URL") {
                    TextField("https://...", text: $vm.sourceURL).textFieldStyle(.roundedBorder)
                }
                labeledField("사용 권한 상태") {
                    TextField("본인 영상 또는 사용 허락 받음", text: $vm.permissionStatus).textFieldStyle(.roundedBorder)
                }
                labeledField("메모") {
                    TextField("추가 메모", text: $vm.notes, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var actionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        Task { await runExport() }
                    } label: {
                        Label("CapCut용 내보내기", systemImage: "folder.badge.plus")
                    }
                    .disabled(vm.isExporting)

                    Button {
                        vm.openInFinder()
                    } label: {
                        Label("Finder에서 열기", systemImage: "folder")
                    }
                    .disabled(vm.result == nil)

                    Spacer()
                    if vm.isExporting { ProgressView().controlSize(.small) }
                }
                if !vm.statusMessage.isEmpty {
                    Text(vm.statusMessage).font(.caption).foregroundStyle(.secondary)
                }
                if let error = vm.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    private func resultCard(_ result: ExportResult) -> some View {
        Card(title: "내보내기 완료", subtitle: result.folderURL.lastPathComponent) {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.folderURL.path).font(.caption).foregroundStyle(.secondary)
                ForEach(result.files, id: \.self) { file in
                    HStack(spacing: 6) {
                        Image(systemName: "doc").foregroundStyle(.secondary)
                        Text(file).font(.callout)
                    }
                }
            }
        }
    }

    private func runExport() async {
        let input = ExportInput(
            projectName: vm.projectName,
            keyword: vm.projectName,
            outputDirectory: vm.outputDirectory,
            videoFileURL: pipeline.videoFileURL,
            audioFileURL: pipeline.audioFileURL,
            transcript: pipeline.transcript,
            videoDuration: pipeline.videoDuration,
            translations: pipeline.translations,
            rewrittenScript: pipeline.rewrittenScript,
            titleCandidates: pipeline.titleCandidates,
            hooks: pipeline.hooks,
            sourcePlatform: vm.sourcePlatform,
            sourceURL: vm.sourceURL,
            sourceCreator: vm.sourceCreator,
            permissionStatus: vm.permissionStatus,
            notes: vm.notes,
            includeOriginalVideo: vm.includeOriginalVideo,
            includeAudio: vm.includeAudio
        )
        await vm.export(input: input)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.outputDirectory = url
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
