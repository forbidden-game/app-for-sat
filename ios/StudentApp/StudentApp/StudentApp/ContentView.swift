//
//  ContentView.swift
//  StudentApp
//
//  Created by ForbiddenGame on 2026/1/4.
//

import SwiftUI
import StudentCore

struct ContentView: View {
    @StateObject private var vm = AppViewModel()

    var body: some View {
        Group {
            if let user = vm.user, let session = vm.session, let sessionId = vm.sessionId {
                PracticeFlowView(session: session, sessionId: sessionId, studentId: user.id)
            } else if vm.isLoading {
                ProgressView()
            } else {
                AuthView(vm: vm)
            }
        }
    }
}

#Preview {
    ContentView()
}
