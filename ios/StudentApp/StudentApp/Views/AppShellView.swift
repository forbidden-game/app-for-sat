import SwiftUI

struct AppShellView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedTab: MainTab = .home
    @State private var showFriends = false
    @State private var showProfile = false

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            if let session = vm.session, let sessionId = vm.sessionId, let studentId = vm.user?.id {
                PracticeFlowView(session: session, sessionId: sessionId, studentId: studentId) {
                    vm.exitSession()
                }
            } else {
                VStack(spacing: 0) {
                    AppTopBar(
                        title: selectedTab.title,
                        subtitle: selectedTab.subtitle,
                        displayName: displayName,
                        onProfile: { showProfile = true },
                        onSocial: { showFriends = true }
                    )

                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AppTabBar(selected: $selectedTab)
                }
            }
        }
        .sheet(isPresented: $showFriends) {
            if let userId = vm.user?.id {
                FriendsListView(userId: userId)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheetView(displayName: displayName, onSignOut: {
                Task { await vm.signOut() }
            })
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(vm: vm)
        case .coach:
            if let studentId = vm.user?.id {
                CoachChatView(studentId: studentId, showsHeader: false)
            } else {
                EmptyView()
            }
        case .review:
            if let studentId = vm.user?.id {
                ReviewContainerView(studentId: studentId, banks: vm.banks)
            } else {
                EmptyView()
            }
        }
    }

    private var displayName: String {
        if let email = vm.user?.email, !email.isEmpty {
            return email
        }
        return "Student"
    }
}
