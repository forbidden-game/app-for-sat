import SwiftUI
import StudentCore

struct EnglishGrammarAnalysisSheet: View {
    let questionId: String

    @StateObject private var viewModel: EnglishGrammarAnalysisViewModel

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
                analysisCard(analysis)
            }
            .padding(.bottom, 24)
        }
    }

    private func analysisCard(_ analysis: EnglishGrammarAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("主干核心 / Core")
            sentencePairView(analysis.coreSentence)

            Divider()
                .overlay(AppTheme.divider)

            sectionTitle("简单句还原 / Simple Sentences")
            simpleSentenceList(analysis.simpleSentences ?? [])
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func sentencePairView(_ pair: EnglishGrammarSentencePair?) -> some View {
        let zh = pair?.zh.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let en = pair?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 6) {
            if !zh.isEmpty {
                Text(zh)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            if !en.isEmpty {
                Text(en)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if zh.isEmpty && en.isEmpty {
                Text("暂无 / Not available")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    private func simpleSentenceList(_ sentences: [EnglishGrammarSentencePair]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if sentences.isEmpty {
                Text("暂无 / Not available")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                    simpleSentenceRow(index: index + 1, sentence: sentence)
                }
            }
        }
    }

    private func simpleSentenceRow(index: Int, sentence: EnglishGrammarSentencePair) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index).")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                if !sentence.zh.isEmpty {
                    Text(sentence.zh)
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                if !sentence.en.isEmpty {
                    Text(sentence.en)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}
