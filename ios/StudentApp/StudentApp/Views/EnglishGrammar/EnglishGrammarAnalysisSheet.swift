import SwiftUI
import StudentCore

struct EnglishGrammarAnalysisSheet: View {
    let questionId: String

    @StateObject private var viewModel: EnglishGrammarAnalysisViewModel
    @State private var selectedComponentId: String?

    init(questionId: String) {
        self.questionId = questionId
        _viewModel = StateObject(wrappedValue: EnglishGrammarAnalysisViewModel())
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            content
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.top, AppMetrics.screenTopPadding)
                .padding(.bottom, AppMetrics.screenBottomPaddingLarge)
        }
        .onAppear {
            viewModel.start(questionId: questionId)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            loadingView(status: nil)
        case .loading(let status):
            loadingView(status: status)
        case .failed(let message):
            errorView(message: message)
        case .ready(let analysis):
            analysisView(analysis)
        }
    }

    private func loadingView(status: EnglishGrammarAnalysisStatus?) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accentStrong)
            Text(statusText(status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("生成中，请稍等… Generating analysis")
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusText(_ status: EnglishGrammarAnalysisStatus?) -> String {
        switch status {
        case .queued:
            return "已排队 / Queued"
        case .running:
            return "分析中 / Running"
        case .done:
            return "完成 / Done"
        case .error:
            return "失败 / Error"
        case .none:
            return "准备中 / Preparing"
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.statusDanger)
            Text("语法分析失败 Grammar analysis failed")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Retry") {
                viewModel.retry(questionId: questionId)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(AppTheme.divider, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func analysisView(_ analysis: EnglishGrammarAnalysis) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("语法分析 Grammar Analysis")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let passage = analysis.passage, !passage.isEmpty {
                    textCard(title: "段落 / Passage", body: passage)
                }

                textCard(title: "题干 / Prompt", body: analysis.prompt)

                VStack(alignment: .leading, spacing: 12) {
                    Text("句子结构 / Sentences")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)

                    ForEach(analysis.sentences) { sentence in
                        EnglishGrammarSentenceCard(
                            sentence: sentence,
                            selectedComponentId: $selectedComponentId
                        )
                    }
                }

                if !analysis.importantWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("重点词汇 / Important Words")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(analysis.importantWords) { word in
                            ImportantWordCard(word: word)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func textCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
            Text(body)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.dividerStrong,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.cardShadowRadius,
            shadowY: AppMetrics.cardShadowY
        )
    }
}

private struct EnglishGrammarSentenceCard: View {
    let sentence: EnglishGrammarSentence
    @Binding var selectedComponentId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(attributedSentence())
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(sentence.components) { component in
                componentRow(component)
            }
        }
        .padding(AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.divider,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.cardShadowRadius,
            shadowY: AppMetrics.cardShadowY
        )
    }

    private func attributedSentence() -> AttributedString {
        var attributed = AttributedString(sentence.text)
        guard let selected = sentence.components.first(where: { $0.id == selectedComponentId }) else {
            return attributed
        }

        if let stringRange = stringRange(for: selected),
           let attrRange = Range(stringRange, in: attributed) {
            attributed[attrRange].backgroundColor = AppTheme.accentStrong.opacity(0.25)
            attributed[attrRange].foregroundColor = AppTheme.textPrimary
        }
        return attributed
    }

    private func stringRange(for component: EnglishGrammarComponent) -> Range<String.Index>? {
        guard component.start >= 0, component.end > component.start else { return nil }
        let utf16Count = sentence.text.utf16.count
        guard component.start <= utf16Count, component.end <= utf16Count else { return nil }
        let startIndex = String.Index(utf16Offset: component.start, in: sentence.text)
        let endIndex = String.Index(utf16Offset: component.end, in: sentence.text)
        return startIndex..<endIndex
    }

    private func componentRow(_ component: EnglishGrammarComponent) -> some View {
        Button {
            selectedComponentId = component.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(component.labelZh)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(component.labelEn)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(component.type)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(AppTheme.surface)
                        .clipShape(Capsule())
                }

                if let zh = component.explanationZh, !zh.isEmpty {
                    Text(zh)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let en = component.explanationEn, !en.isEmpty {
                    Text(en)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(selectedComponentId == component.id ? AppTheme.accentStrong.opacity(0.1) : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ImportantWordCard: View {
    let word: EnglishImportantWord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(word.word)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                if let pos = word.partOfSpeech, !pos.isEmpty {
                    Text(pos)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(AppTheme.surface)
                        .clipShape(Capsule())
                }
            }

            if let zh = word.meaningZh, !zh.isEmpty {
                Text(zh)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let en = word.meaningEn, !en.isEmpty {
                Text(en)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            }
            if let zh = word.whyZh, !zh.isEmpty {
                Text(zh)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let en = word.whyEn, !en.isEmpty {
                Text(en)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.divider,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.cardShadowRadius,
            shadowY: AppMetrics.cardShadowY
        )
    }
}
