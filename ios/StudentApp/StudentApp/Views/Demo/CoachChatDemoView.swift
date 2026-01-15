import SwiftUI

struct CoachChatDemoView: View {
    private let styles: [CoachChatDemoStyle] = [.warmScholar, .focusMode, .auroraMentor]
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
                CoachChatDemoPage(style: style)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color(.systemGroupedBackground))
    }
}

private struct CoachChatDemoPage: View {
    let style: CoachChatDemoStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CoachChatDemoHeader(style: style)
                CoachChatDemoScreen(style: style)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct CoachChatDemoHeader: View {
    let style: CoachChatDemoStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(style.name)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
            Text(style.tagline)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(style.swatches.indices, id: \.self) { index in
                    Circle()
                        .fill(style.swatches[index])
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(style.border, lineWidth: 1)
                        )
                }
            }
            .padding(10)
            .background(style.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct CoachChatDemoScreen: View {
    let style: CoachChatDemoStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(style.background)

            if style.variant == .auroraMentor {
                AuroraGlowBackground()
            }

            VStack(spacing: 16) {
                CoachChatDemoTopBar(style: style)
                CoachChatDemoCoachCard(style: style)
                CoachChatDemoMessages(style: style)
                CoachChatDemoComposer(style: style)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 610)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .shadow(color: style.shadow, radius: 16, x: 0, y: 12)
    }
}

#Preview {
    CoachChatDemoView()
}
