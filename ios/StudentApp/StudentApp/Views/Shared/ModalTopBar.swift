import SwiftUI

struct ModalTopBar: View {
    let title: String
    let showsClose: Bool
    let leadingSystemImage: String
    let onClose: () -> Void
    let trailing: AnyView?

    init(
        title: String,
        showsClose: Bool = true,
        leadingSystemImage: String = "xmark",
        onClose: @escaping () -> Void,
        trailing: AnyView? = nil
    ) {
        self.title = title
        self.showsClose = showsClose
        self.leadingSystemImage = leadingSystemImage
        self.onClose = onClose
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if showsClose {
                    Button(action: onClose) {
                        Image(systemName: leadingSystemImage)
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
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if let trailing {
                    trailing
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }
            .frame(height: AppMetrics.topBarHeight)
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .background(AppTheme.chromeBackground)
            .safeAreaPadding(.top, 6)

            Rectangle()
                .fill(AppTheme.chromeDivider)
                .frame(height: 1)
        }
    }
}
