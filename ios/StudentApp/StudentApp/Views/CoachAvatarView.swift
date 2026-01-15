import SwiftUI

struct CoachAvatarView: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accentStrong)
            Circle()
                .stroke(AppTheme.dividerStrong, lineWidth: 1)

            HStack(spacing: size * 0.1) {
                eyeView(isLeft: true)
                eyeView(isLeft: false)
            }

            Capsule()
                .fill(AppTheme.textOnAccent.opacity(0.9))
                .frame(width: size * 0.32, height: size * 0.08)
                .offset(y: size * 0.18)
        }
        .frame(width: size, height: size)
    }

    private func eyeView(isLeft: Bool) -> some View {
        let eyeSize = isLeft ? size * 0.28 : size * 0.24
        let pupilSize = eyeSize * 0.32
        let pupilOffsetX = isLeft ? -eyeSize * 0.08 : eyeSize * 0.12
        let pupilOffsetY = isLeft ? -eyeSize * 0.04 : eyeSize * 0.06

        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: eyeSize, height: eyeSize)
                .shadow(color: AppTheme.shadowSoft, radius: 1, x: 0, y: 1)

            Circle()
                .fill(AppTheme.textPrimary)
                .frame(width: pupilSize, height: pupilSize)
                .offset(x: pupilOffsetX, y: pupilOffsetY)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CoachAvatarView(size: 28)
        CoachAvatarView(size: 40)
    }
    .padding()
    .background(AppTheme.backgroundGradient)
}
