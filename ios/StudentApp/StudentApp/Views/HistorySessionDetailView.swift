import SwiftUI
import StudentCore

struct HistorySessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let sessionId: String
    let studentId: String
    @StateObject private var vm: HistorySessionViewModel
    @State private var selectedQuestion: QuestionResult?

    init(sessionId: String, studentId: String) {
        self.sessionId = sessionId
        self.studentId = studentId
        _vm = StateObject(wrappedValue: HistorySessionViewModel(sessionId: sessionId))
    }

    var body: some View {
        Group {
            if let question = selectedQuestion {
                QuestionDetailView(
                    question: question,
                    studentId: studentId,
                    flowModel: vm,
                    onBack: {
                        selectedQuestion = nil
                    }
                )
            } else if let result = vm.sessionResult {
                SessionResultView(
                    result: result,
                    onSelectQuestion: { question in
                        selectedQuestion = question
                    },
                    onDismiss: {
                        dismiss()
                    }
                )
            } else {
                ZStack {
                    AppTheme.backgroundGradient
                        .ignoresSafeArea()

                    if vm.isLoading {
                        ProgressView()
                            .tint(AppTheme.accentStrong)
                    } else if let error = vm.errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(AppTheme.statusDanger)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        Text("暂无记录")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }
        }
        .task {
            if vm.sessionResult == nil && !vm.isLoading {
                await vm.load()
            }
        }
    }
}
