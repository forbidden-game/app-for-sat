import SwiftUI

struct RemoteImageView: View {
    let url: URL
    var cornerRadius: CGFloat = 12

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Image failed to load")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            @unknown default:
                EmptyView()
            }
        }
    }
}
