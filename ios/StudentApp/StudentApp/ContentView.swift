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
                MainContainerView(vm: vm)
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
        .fontDesign(.serif)
        .onAppear {
            pushTokenManager.updateAuth(userId: vm.user?.id)
        }
        .onChange(of: vm.user?.id) { _, newValue in
            pushTokenManager.updateAuth(userId: newValue)
        }
    }
}

#Preview {
    ContentView()
}

private struct MainContainerView: View {
    @ObservedObject var vm: AppViewModel
    @State private var showPanel = false
    @State private var showCoach = false
    @State private var showReports = false
    @State private var showUiDemo = false

    var body: some View {
        SidePanelHost(isPresented: $showPanel) {
            ZStack(alignment: .topTrailing) {
                contentView

                if !isInSession {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showPanel = true
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
            }
        } panel: {
            SidePanelView(displayName: displayName, onCoach: {
                showCoach = true
                showPanel = false
            }, onReports: {
                showReports = true
                showPanel = false
            }, onSignOut: {
                Task { await vm.signOut() }
            }, onUiDemo: uiDemoAction)
        }
        .sheet(isPresented: $showCoach) {
            if let studentId = vm.user?.id {
                CoachChatView(studentId: studentId)
            }
        }
        .sheet(isPresented: $showReports) {
            if let studentId = vm.user?.id {
                CoachReportsView(studentId: studentId)
            }
        }
#if DEBUG
        .sheet(isPresented: $showUiDemo) {
            UiRefactorDemoView()
        }
#endif
        .onChange(of: isInSession) { _, newValue in
            if newValue {
                showPanel = false
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let session = vm.session, let sessionId = vm.sessionId, let studentId = vm.user?.id {
            PracticeFlowView(session: session, sessionId: sessionId, studentId: studentId, headerTitle: vm.selectedBank?.title) {
                vm.exitSession()
            }
        } else {
            QuestionBankSelectionView(banks: vm.banks, isLoading: vm.isLoading, errorMessage: vm.errorMessage) { bank in
                Task { await vm.startSession(for: bank) }
            }
        }
    }

    private var isInSession: Bool {
        vm.session != nil && vm.sessionId != nil
    }

    private var displayName: String {
        if let email = vm.user?.email, !email.isEmpty {
            return email
        }
        return "Student"
    }

#if DEBUG
    private var uiDemoAction: (() -> Void)? {
        {
            showUiDemo = true
            showPanel = false
        }
    }
#else
    private var uiDemoAction: (() -> Void)? { nil }
#endif
}
