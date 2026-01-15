import SwiftUI
import StudentCore

struct CoachStepSheet: View {
    enum Phase {
        case selectStep
        case loadingInsight
        case ready
    }

    struct Step: Identifiable {
        let id: Int
        let title: String
    }

    @Binding var coachAttempt: CoachAttemptContext?
    @ObservedObject var flowModel: PracticeFlowViewModel

    let studentId: String
    let attemptId: String
    let onContinue: () -> Void

    @State private var phase: Phase = .selectStep
    @State private var selectedStepIndex: Int?
    @State private var selectedUnknown = false
    @State private var insight: AttemptInsight?
    @State private var errorMessage: String?

    @State private var showCoachChat = false
    @State private var coachDraftText: String = ""

    private let steps: [Step] = [
        Step(id: 0, title: "识别目标与已知条件"),
        Step(id: 1, title: "建模：列式/设变量"),
        Step(id: 2, title: "变形：整理到可求解形式"),
        Step(id: 3, title: "求解：得到目标量"),
        Step(id: 4, title: "校验：代回与检查约束"),
        Step(id: 5, title: "映射：匹配选项并排除陷阱"),
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                switch phase {
                case .selectStep:
                    stepSelection
                case .loadingInsight:
                    loadingView
                case .ready:
                    insightView
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled(phase == .selectStep)
        .fullScreenCover(isPresented: $showCoachChat) {
            CoachChatView(studentId: studentId, linkedAttemptId: attemptId, initialDraftText: coachDraftText)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CoachAvatarView(size: 30)
                Text("王校长")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text("你在哪一步开始不确定？（默认必选，可选不确定）")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepSelection: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(steps) { step in
                Button {
                    selectedUnknown = false
                    selectedStepIndex = step.id
                    errorMessage = nil
                    submitSelection()
                } label: {
                    HStack {
                        Text(step.title)
                            .font(.body)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        if selectedStepIndex == step.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .appSurface(
                        fill: AppTheme.surfaceRaised,
                        stroke: AppTheme.dividerStrong,
                        cornerRadius: 14,
                        shadowRadius: 6,
                        shadowY: 2
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                selectedUnknown = true
                selectedStepIndex = nil
                errorMessage = nil
                submitSelection()
            } label: {
                HStack {
                    Text("不确定")
                        .font(.body)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    if selectedUnknown {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .appSurface(
                    fill: AppTheme.surfaceRaised,
                    stroke: AppTheme.dividerStrong,
                    cornerRadius: 14,
                    shadowRadius: 6,
                    shadowY: 2
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)

            Text("正在生成精要讲解…")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var insightView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let insight {
                Text(insight.explanationShort)
                    .font(.body)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .appSurface(
                        fill: AppTheme.surfaceRaised,
                        stroke: AppTheme.dividerStrong,
                        cornerRadius: 14,
                        shadowRadius: 6,
                        shadowY: 2
                    )

                if !insight.followups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("我想确认一下：")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textSecondary)

                        ForEach(insight.followups) { item in
                            Text("• \(item.question)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("讲解还在生成中，你也可以先继续做题。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(.top, 6)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                openCoachChat()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text("去问王校长")
                        .font(.headline)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .appSurface(
                    fill: AppTheme.surfaceRaised,
                    stroke: AppTheme.dividerStrong,
                    cornerRadius: 14,
                    shadowRadius: 6,
                    shadowY: 2
                )
            }
            .buttonStyle(.plain)
            .disabled(phase == .selectStep)

            Button {
                coachAttempt = nil
                onContinue()
            } label: {
                Text("继续")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Text("提示：后续你可以在“王校长”对话里继续追问。")
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    private func submitSelection() {
        phase = .loadingInsight

        if let cached = flowModel.cachedAttemptInsight(attemptId: attemptId) {
            insight = cached
            phase = .ready
        }

        Task {
            do {
                try await flowModel.setAttemptStepSelection(
                    attemptId: attemptId,
                    selectedStepIndex: selectedStepIndex,
                    isUnknown: selectedUnknown
                )

                for _ in 0..<20 {
                    if let insight = try await flowModel.fetchAttemptInsight(attemptId: attemptId) {
                        self.insight = insight
                        phase = .ready
                        return
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }

                phase = .ready
            } catch {
                if self.insight == nil {
                    errorMessage = error.localizedDescription
                    phase = .selectStep
                }
            }
        }
    }

    private func openCoachChat() {
        coachDraftText = ""
        showCoachChat = true
    }
}
