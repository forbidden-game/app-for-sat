import SwiftUI

struct AvatarView: View {
    let avatarUrl: String?
    let placeholder: String
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(AppTheme.divider, lineWidth: 1)
                )

            if let avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Text(placeholder)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Text(placeholder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}