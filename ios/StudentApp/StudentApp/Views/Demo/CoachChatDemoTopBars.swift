import SwiftUI

struct CoachChatDemoTopBar: View {
    let style: CoachChatDemoStyle

    var body: some View {
        switch style.variant {
        case .warmScholar:
            WarmTopBar(style: style)
        case .focusMode:
            FocusTopBar(style: style)
        case .auroraMentor:
            AuroraTopBar(style: style)
        }
    }
}

private struct WarmTopBar: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack {
            Circle()
                .fill(style.surface)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(style.textPrimary)
                )
                .overlay(
                    Circle()
                        .stroke(style.border, lineWidth: 1)
                )

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(style.accent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("AI")
                            .font(style.fontLabel)
                            .foregroundStyle(style.textOnAccent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("王校长")
                        .font(style.fontLabel)
                        .foregroundStyle(style.textPrimary)
                    Text("耐心讲解 + 追问")
                        .font(style.fontCaption)
                        .foregroundStyle(style.textSecondary)
                }
            }

            Spacer()

            Text("数学")
                .font(style.fontCaption)
                .foregroundStyle(style.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(style.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(style.border, lineWidth: 1)
                )
        }
    }
}

private struct FocusTopBar: View {
    let style: CoachChatDemoStyle

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Coach Chat")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Spacer()
                Text("Focus 12:30")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
            }
            Divider()
                .background(style.border)
        }
    }
}

private struct AuroraTopBar: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack {
            Circle()
                .fill(style.surface)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(style.textPrimary)
                )
                .overlay(
                    Circle()
                        .stroke(style.border, lineWidth: 1)
                )

            Spacer()

            Text("Streak 4")
                .font(style.fontCaption)
                .foregroundStyle(style.textOnAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.00, green: 0.55, blue: 1.0), Color(red: 0.98, green: 0.20, blue: 0.60)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(style.accent)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("AI")
                            .font(style.fontCaption)
                            .foregroundStyle(style.textOnAccent)
                    )
                Text("Aurora Coach")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textPrimary)
            }
        }
    }
}

struct AuroraGlowBackground: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.00, green: 0.65, blue: 1.0), Color(red: 0.00, green: 0.90, blue: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 35)
                .opacity(0.35)
                .offset(x: -90, y: -120)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.20, blue: 0.60), Color(red: 0.40, green: 0.20, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .opacity(0.25)
                .offset(x: 110, y: -60)

            Circle()
                .fill(Color(red: 0.20, green: 0.55, blue: 1.0))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .opacity(0.18)
                .offset(x: 70, y: 140)
        }
    }
}
