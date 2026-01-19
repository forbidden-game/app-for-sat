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
    @StateObject private var pushTokenManager = PushTokenManager()

    var body: some View {
        Group {
            if vm.user != nil {
                AppShellView(vm: vm)
            } else if vm.isLoading {
                ZStack {
                    AppTheme.backgroundGradient
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(AppTheme.accentStrong)
                }
            } else {
                AuthView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            pushTokenManager.updateAuth(userId: vm.user?.id)
            MathTextView.prewarm()
        }
        .onChange(of: vm.user?.id) { _, newValue in
            pushTokenManager.updateAuth(userId: newValue)
        }
    }
}

#Preview {
    ContentView()
}
