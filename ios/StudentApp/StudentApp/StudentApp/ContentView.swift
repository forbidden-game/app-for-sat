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
            Question(id: "Q1", questionType: "mcq", stem: "2+2?", options: nil, answerKey: AnswerKey(correct: "B"))
        ])
        QuestionFeedView(vm: QuestionFeedViewModel(session: sample))
    }
}

#Preview {
    ContentView()
}
