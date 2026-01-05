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
                ZStack(alignment: .topTrailing) {
                    PracticeFlowView(session: session, sessionId: sessionId, studentId: user.id)

                    Button {
                        Task { await vm.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
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
