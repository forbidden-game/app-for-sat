import Combine
import SwiftUI
import StudentCore

struct ReviewContainerView: View {
    let studentId: String
    let banks: [QuestionBank]
    @State private var selection: ReviewSection = .history

    var body: some View {
        VStack(spacing: 12) {
            Picker("复盘", selection: $selection) {
                ForEach(ReviewSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .padding(.top, 12)

            Group {
                switch selection {
                case .history:
                    PracticeHistoryView(banks: banks, studentId: studentId, showsHeader: false)
                case .reports:
                    CoachReportsView(studentId: studentId, showsHeader: false)
                }
            }
        }
    }
}

private enum ReviewSection: String, CaseIterable, Identifiable {
    case history
    case reports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history:
            return "做题记录"
        case .reports:
            return "报告"
        }
    }
}

