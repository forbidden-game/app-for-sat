import SwiftUI
import StudentCore

struct FriendsListView: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = FriendsListViewModel()
    @State private var searchText: String = ""
    @State private var profileFriend: FriendThreadSummary?
    @State private var chatFriend: FriendThreadSummary?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ModalTopBar(
                    title: "好友",
                    showsClose: true,
                    leadingSystemImage: "xmark",
                    onClose: { dismiss() },
                    trailing: AnyView(shareLink)
                )

                searchField

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("好友")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("\(filteredFriends.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textOnAccent)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 8)
                                .background(AppTheme.surfaceRaised)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, AppMetrics.screenHorizontalPadding)

                        if vm.isLoading {
                            ProgressView()
                                .tint(AppTheme.accentStrong)
                                .frame(maxWidth: .infinity)
                        } else if filteredFriends.isEmpty {
                            // ✅ Using FriendsEmptyStateView component
                            FriendsEmptyStateView(onInvite: {
                                showShareSheet = true
                            })
                            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                        } else {
                            ForEach(filteredFriends) { friend in
                                FriendRowView(
                                    friend: friend,
                                    onAvatarTap: { profileFriend = friend },
                                    onChatTap: { chatFriend = friend }
                                )
                                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(item: $profileFriend) { friend in
                FriendProfileView(friend: friend)
            }
            .navigationDestination(item: $chatFriend) { friend in
                FriendChatView(friend: friend, userId: userId)
            }
            .task {
                await vm.load()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [InviteLinkBuilder.build(userId: userId)])
            }
        }
    }

    private var filteredFriends: [FriendThreadSummary] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return vm.friends
        }
        let query = searchText.lowercased()
        return vm.friends.filter { friend in
            friend.username.lowercased().contains(query)
        }
    }

    private var shareLink: some View {
        let inviteURL = InviteLinkBuilder.build(userId: userId)
        return ShareLink(item: inviteURL) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            TextField("搜索好友", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
    }
}

private struct FriendRowView: View {
    let friend: FriendThreadSummary
    let onAvatarTap: () -> Void
    let onChatTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAvatarTap) {
                AvatarView(avatarUrl: friend.avatarUrl, placeholder: initials)
            }
            .buttonStyle(.plain)

            Button(action: onChatTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let lastMessage = friend.lastMessage, !lastMessage.isEmpty {
                        Text(lastMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("点击聊天")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    if let rating = friend.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.statusWarning)
                            Text("\(rating)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .appSurface(fill: AppTheme.surface, stroke: AppTheme.divider)
    }

    private var initials: String {
        let parts = friend.username.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        let text = letters.map { String($0) }.joined()
        return text.isEmpty ? "?" : text.uppercased()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
