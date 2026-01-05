import Foundation

struct QuestionBank: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let questionLimit: Int

    static let samples: [QuestionBank] = [
        QuestionBank(id: "daily", title: "Daily Mix", subtitle: "Warm up", icon: "sun.max.fill", questionLimit: 8),
        QuestionBank(id: "logic", title: "Logic Drills", subtitle: "Reasoning", icon: "puzzlepiece.fill", questionLimit: 10),
        QuestionBank(id: "reading", title: "Reading", subtitle: "Passages", icon: "book.closed.fill", questionLimit: 10),
        QuestionBank(id: "writing", title: "Writing", subtitle: "Style", icon: "pencil.circle.fill", questionLimit: 10),
        QuestionBank(id: "math", title: "Math Core", subtitle: "Algebra", icon: "function", questionLimit: 10),
        QuestionBank(id: "data", title: "Data", subtitle: "Charts", icon: "chart.bar.fill", questionLimit: 8),
        QuestionBank(id: "vocab", title: "Vocab", subtitle: "Words", icon: "textformat.abc", questionLimit: 8),
        QuestionBank(id: "mixed", title: "Mixed Set", subtitle: "Full", icon: "square.grid.2x2.fill", questionLimit: 12)
    ]
}
