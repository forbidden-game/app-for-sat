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
    @State private var pendingOpenFriendThreadId: String?

    private let friendService = SupabaseFriendsService()
    private let pendingInviteKey = "friendInvite.pendingCode"
    private let pendingThreadKey = "friendInvite.pendingThreadId"

    var body: some View {
        Group {
            if vm.user != nil {
                AppShellView(vm: vm, pendingOpenFriendThreadId: $pendingOpenFriendThreadId)
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
            restorePendingThreadIfNeeded()
        }
        .onChange(of: vm.user?.id) { _, newValue in
            pushTokenManager.updateAuth(userId: newValue)
            if newValue != nil {
                redeemPendingInviteIfNeeded()
                restorePendingThreadIfNeeded()
            }
        }
        .onOpenURL { url in
            handleInviteURL(url)
        }
        .onChange(of: pendingOpenFriendThreadId) { _, newValue in
            if newValue == nil {
                UserDefaults.standard.removeObject(forKey: pendingThreadKey)
            }
        }
    }

    private func handleInviteURL(_ url: URL) {
        guard let code = inviteCode(from: url) else { return }
        handleInviteCode(code)
    }

    private func inviteCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []
        let inviteCode = items.first(where: { $0.name == "inviteCode" })?.value
        if let inviteCode, !inviteCode.isEmpty {
            return inviteCode
        }
        let fallback = items.first(where: { $0.name == "code" })?.value
        return fallback?.isEmpty == false ? fallback : nil
    }

    private func handleInviteCode(_ code: String) {
        guard vm.user?.id != nil else {
            UserDefaults.standard.set(code, forKey: pendingInviteKey)
            return
        }
        Task { @MainActor in
            await redeemInvite(code)
        }
    }

    @MainActor
    private func redeemInvite(_ code: String) async {
        do {
            let result = try await friendService.redeemFriendInvite(code: code)
            pendingOpenFriendThreadId = result.threadId
            UserDefaults.standard.removeObject(forKey: pendingInviteKey)
            UserDefaults.standard.set(result.threadId, forKey: pendingThreadKey)
        } catch {
            return
        }
    }

    private func redeemPendingInviteIfNeeded() {
        guard let code = UserDefaults.standard.string(forKey: pendingInviteKey), !code.isEmpty else {
            return
        }
        Task { @MainActor in
            await redeemInvite(code)
        }
    }

    private func restorePendingThreadIfNeeded() {
        guard pendingOpenFriendThreadId == nil else { return }
        guard let threadId = UserDefaults.standard.string(forKey: pendingThreadKey), !threadId.isEmpty else {
            return
        }
        pendingOpenFriendThreadId = threadId
    }
}

#Preview {
    ContentView()
}
