import SwiftUI

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    AppTheme.surfaceRaised,
                    AppTheme.surfaceRaised.opacity(0.5),
                    AppTheme.surfaceRaised
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * 2)
            .offset(x: -proxy.size.width + phase * proxy.size.width * 3)
        }
        .mask(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Card Skeleton View

struct CardSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ShimmerView()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    ShimmerView()
                        .frame(height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    ShimmerView()
                        .frame(width: 100, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                Spacer()

                ShimmerView()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .appSurface(
            fill: AppTheme.surface,
            stroke: AppTheme.divider
        )
    }
}

// MARK: - Profile Skeleton View

struct ProfileSkeletonView: View {
    var body: some View {
        VStack(spacing: 12) {
            ShimmerView()
                .frame(width: 72, height: 72)
                .clipShape(Circle())

            ShimmerView()
                .frame(width: 100, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Score Skeleton View

struct ScoreSkeletonView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ShimmerView()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())

                ShimmerView()
                    .frame(width: 100, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ShimmerView()
                .frame(width: 150, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

// MARK: - Question Option Skeleton

struct QuestionOptionSkeletonView: View {
    var body: some View {
        HStack(spacing: 12) {
            ShimmerView()
                .frame(width: AppMetrics.badgeSize, height: AppMetrics.badgeSize)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                ShimmerView()
                    .frame(height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                ShimmerView()
                    .frame(height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                ShimmerView()
                    .frame(width: "60%", height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer()
        }
        .padding(.vertical, AppMetrics.rowPaddingVertical)
        .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
        .appSurface(
            fill: AppTheme.surface,
            stroke: AppTheme.divider
        )
    }
}

// MARK: - Skeleton Loading Container

struct SkeletonLoadingView<Content: View, LoadingView: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let loadingView: () -> LoadingView

    var body: some View {
        if isLoading {
            loadingView()
        } else {
            content()
        }
    }
}

// MARK: - Chat Message Skeleton

struct ChatMessageSkeletonView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ShimmerView()
                .frame(width: 26, height: 26)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                ShimmerView()
                    .frame(width: 80, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                ShimmerView()
                    .frame(height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 52)
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.vertical, 6)
    }
}

// MARK: - Friend Row Skeleton

struct FriendRowSkeletonView: View {
    var body: some View {
        HStack(spacing: 12) {
            ShimmerView()
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                ShimmerView()
                    .frame(width: 100, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                ShimmerView()
                    .frame(width: 180, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer()

            ShimmerView()
                .frame(width: 16, height: 16)
                .clipShape(Circle())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
    }
}

// MARK: - Preview

#Preview("Skeleton Loading") {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                ProfileSkeletonView()

                Text("好友列表")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(0..<3, id: \.self) { _ in
                    FriendRowSkeletonView()
                }

                Text("题目选项")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(0..<4, id: \.self) { _ in
                    QuestionOptionSkeletonView()
                }

                Text("聊天消息")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(0..<3, id: \.self) { _ in
                    ChatMessageSkeletonView()
                }
            }
            .padding(20)
        }
    }
}
