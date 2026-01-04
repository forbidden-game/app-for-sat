//
//  ContentView.swift
//  StudentApp
//
//  Created by ForbiddenGame on 2026/1/4.
//

import SwiftUI
import StudentCore

struct ContentView: View {
    var body: some View {
        let sample = PracticeSession(id: "S1", questions: [
            Question(
                id: "Q1",
                questionType: "mcq",
                stem: "2 + 2 = ?",
                options: [
                    QuestionOption(label: "A", content: "3"),
                    QuestionOption(label: "B", content: "4"),
                    QuestionOption(label: "C", content: "5"),
                    QuestionOption(label: "D", content: "6")
                ],
                answerKey: AnswerKey(correct: "B")
            ),
            Question(
                id: "Q2",
                questionType: "numeric",
                stem: "Solve: 5x = 20. x = ?",
                options: nil,
                answerKey: AnswerKey(correct: 4.0)
            )
        ])
        QuestionFeedView(vm: QuestionFeedViewModel(session: sample))
    }
}

#Preview {
    ContentView()
}
