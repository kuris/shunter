import SwiftUI

struct RewriteView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        RewriteContentView(
            vm: app.rewriteViewModel,
            transcript: app.currentTranscript,
            defaultLanguage: app.settingsStore.settings.defaultTranslateLanguage
        )
    }
}

private struct RewriteContentView: View {
    @ObservedObject var vm: RewriteViewModel
    let transcript: TranscriptDocument?
    let defaultLanguage: TranslateLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "번역 / 재작성", subtitle: "대본을 번역하고, 숏폼 스타일에 맞게 새롭게 재작성하세요.")

                SafetyNotice(text: "재작성은 원문을 그대로 복제하지 않고 구조와 아이디어만 참고해 새롭게 작성하는 기능입니다. 원작과 혼동될 정도의 유사성을 만들지 마세요.")

                inputCard
                controlCard
                resultCards
            }
            .padding(24)
        }
        .onAppear {
            if vm.originalText.isEmpty, let transcript {
                vm.originalText = transcript.plainText
            }
        }
        .onChange(of: transcript) { _, newValue in
            if let newValue, vm.originalText.isEmpty {
                vm.originalText = newValue.plainText
            }
        }
    }

    private var inputCard: some View {
        Card(title: "원문 대본", subtitle: transcript.map { "불러온 대본: \($0.sourceVideoFileName)" } ?? "직접 입력하거나 대본 추출 후 사용하세요.") {
            VStack(alignment: .leading, spacing: 8) {
                if let transcript {
                    Button {
                        vm.originalText = transcript.plainText
                    } label: {
                        Label("불러온 대본 사용", systemImage: "arrow.down.doc")
                    }
                }
                TextEditor(text: $vm.originalText)
                    .frame(minHeight: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
            }
        }
    }

    private var controlCard: some View {
        Card(title: "작업 설정") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("타겟 언어").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $vm.targetLanguage) {
                            ForEach(TranslateLanguage.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("재작성 스타일").font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $vm.style) {
                            ForEach(RewriteStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    Spacer()
                    if vm.isWorking { ProgressView().controlSize(.small) }
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await vm.translate(sourceText: resolvedSource(), document: transcript) }
                    } label: {
                        Label("번역", systemImage: "character.book.closed")
                    }
                    Button {
                        Task { await vm.rewrite(sourceText: resolvedSource()) }
                    } label: {
                        Label("대본 재작성", systemImage: "wand.and.stars")
                    }
                    Button {
                        Task { await vm.generateTitles(sourceText: resolvedSource()) }
                    } label: {
                        Label("제목 후보 10개", systemImage: "list.number")
                    }
                    Button {
                        Task { await vm.generateHooks(sourceText: resolvedSource()) }
                    } label: {
                        Label("후킹 문장 10개", systemImage: "bolt")
                    }
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

    private var resultCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                resultEditor("번역 결과 (\(vm.targetLanguage.displayName))", text: $vm.translatedText)
                resultEditor("재작성 결과 (\(vm.style.rawValue))", text: $vm.rewrittenText)
            }
            HStack(alignment: .top, spacing: 16) {
                Card(title: "제목 후보") {
                    itemList(vm.titleCandidates)
                }
                Card(title: "후킹 문장") {
                    itemList(vm.hooks)
                }
            }
        }
    }

    private func resultEditor(_ title: String, text: Binding<String>) -> some View {
        Card(title: title) {
            TextEditor(text: text)
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
        }
    }

    private func itemList(_ items: [String]) -> some View {
        Group {
            if items.isEmpty {
                Text("아직 생성된 항목이 없습니다.").font(.caption).foregroundStyle(.secondary)
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

    private func resolvedSource() -> String {
        if !vm.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return vm.originalText
        }
        return transcript?.plainText ?? ""
    }
}
