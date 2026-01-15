import SwiftUI

struct UiRefactorDemoView: View {
    private let styles: [DemoStyle] = [.paperFocus, .calmAcademic, .vibrantProgress]
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
                DemoStylePage(style: style)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color(.systemGroupedBackground))
    }
}

private struct DemoStylePage: View {
    let style: DemoStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoStyleHeader(style: style)
                DemoScreen(style: style)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct DemoStyleHeader: View {
    let style: DemoStyle

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

private struct DemoScreen: View {
    let style: DemoStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(style.background)

            VStack(spacing: 16) {
                DemoTopBar(style: style)
                DemoQuestionCard(style: style)
                DemoOptions(style: style)
                DemoCoachCallout(style: style)
                DemoActionBar(style: style)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .shadow(color: style.shadow, radius: 16, x: 0, y: 12)
    }
}

private struct DemoTopBar: View {
    let style: DemoStyle

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(style.surface)
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(style.accent.opacity(0.9))
                            .frame(width: 16, height: 3)
                    )
                Spacer()
                Text("SAT Math - Practice")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Spacer()
                Circle()
                    .fill(style.surface)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(style.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Question 12")
                        .font(style.fontLabel)
                        .foregroundStyle(style.textSecondary)
                    Spacer()
                    Text("3 left")
                        .font(style.fontLabel)
                        .foregroundStyle(style.textSecondary)
                }
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(style.progressTrack)
                        .frame(height: 6)
                    Capsule()
                        .fill(style.progressFill)
                        .frame(width: 140, height: 6)
                }
            }
        }
    }
}

private struct DemoQuestionCard: View {
    let style: DemoStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("If 3x + 5 = 26, what is the value of x?")
                .font(style.fontTitle)
                .foregroundStyle(style.textPrimary)

            HStack(spacing: 8) {
                Text("Target skill")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Text("Linear equations")
                    .font(style.fontTag)
                    .foregroundStyle(style.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(style.accentSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DemoOptions: View {
    let style: DemoStyle

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4) { index in
                HStack(spacing: 12) {
                    Text(["A", "B", "C", "D"][index])
                        .font(style.fontLabel)
                        .foregroundStyle(style.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(style.surfaceAlt)
                        .clipShape(Circle())

                    Text(["5", "7", "9", "11"][index])
                        .font(style.fontBody)
                        .foregroundStyle(style.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(index == 1 ? style.accentSoft : style.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(index == 1 ? style.accent : style.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct DemoCoachCallout: View {
    let style: DemoStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(style.accent)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("AI")
                        .font(style.fontLabel)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("Coach explains the mistake, then offers a short follow-up question.")
                    .font(style.fontBody)
                    .foregroundStyle(style.textPrimary)
                Text("Review the step where you moved 5 to the other side.")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(style.surfaceAlt)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DemoActionBar: View {
    let style: DemoStyle

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Confidence check")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Text("How sure are you?")
                    .font(style.fontBody)
                    .foregroundStyle(style.textPrimary)
            }
            Spacer()
            Text("Submit")
                .font(style.fontLabel)
                .foregroundStyle(style.textOnAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(style.accentStrong)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DemoStyle: Identifiable {
    let id = UUID()
    let name: String
    let tagline: String
    let swatches: [Color]
    let background: AnyShapeStyle
    let surface: Color
    let surfaceAlt: Color
    let textPrimary: Color
    let textSecondary: Color
    let textOnAccent: Color
    let accent: Color
    let accentStrong: Color
    let accentSoft: Color
    let border: Color
    let shadow: Color
    let progressTrack: Color
    let progressFill: Color
    let fontTitle: Font
    let fontBody: Font
    let fontLabel: Font
    let fontTag: Font
}

private extension DemoStyle {
    static let paperFocus = DemoStyle(
        name: "Paper Focus",
        tagline: "E-ink calm, low distraction",
        swatches: [
            Color(red: 0.12, green: 0.28, blue: 0.28),
            Color(red: 0.18, green: 0.36, blue: 0.36),
            Color(red: 0.86, green: 0.90, blue: 0.90),
            Color(red: 0.99, green: 0.99, blue: 0.98),
            Color(red: 0.83, green: 0.83, blue: 0.80)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.97, blue: 0.95), Color(red: 0.96, green: 0.95, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        surface: Color(red: 0.99, green: 0.99, blue: 0.98),
        surfaceAlt: Color(red: 0.96, green: 0.95, blue: 0.93),
        textPrimary: Color(red: 0.10, green: 0.10, blue: 0.10),
        textSecondary: Color(red: 0.35, green: 0.35, blue: 0.35),
        textOnAccent: .white,
        accent: Color(red: 0.18, green: 0.36, blue: 0.36),
        accentStrong: Color(red: 0.12, green: 0.28, blue: 0.28),
        accentSoft: Color(red: 0.86, green: 0.90, blue: 0.90),
        border: Color(red: 0.83, green: 0.83, blue: 0.80),
        shadow: Color.black.opacity(0.08),
        progressTrack: Color(red: 0.86, green: 0.86, blue: 0.84),
        progressFill: Color(red: 0.18, green: 0.36, blue: 0.36),
        fontTitle: .system(size: 22, weight: .semibold, design: .serif),
        fontBody: .system(size: 16, weight: .regular, design: .serif),
        fontLabel: .system(size: 13, weight: .medium, design: .serif),
        fontTag: .system(size: 12, weight: .medium, design: .serif)
    )

    static let calmAcademic = DemoStyle(
        name: "Calm Academic",
        tagline: "Soft teal + teacher clarity",
        swatches: [
            Color(red: 0.02, green: 0.48, blue: 0.44),
            Color(red: 0.05, green: 0.58, blue: 0.53),
            Color(red: 0.78, green: 0.93, blue: 0.90),
            Color(red: 0.92, green: 0.97, blue: 0.96),
            Color(red: 0.74, green: 0.89, blue: 0.86)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.99, blue: 0.98), Color(red: 0.88, green: 0.97, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        surface: Color.white.opacity(0.96),
        surfaceAlt: Color(red: 0.92, green: 0.97, blue: 0.96),
        textPrimary: Color(red: 0.08, green: 0.20, blue: 0.20),
        textSecondary: Color(red: 0.20, green: 0.35, blue: 0.35),
        textOnAccent: .white,
        accent: Color(red: 0.05, green: 0.58, blue: 0.53),
        accentStrong: Color(red: 0.02, green: 0.48, blue: 0.44),
        accentSoft: Color(red: 0.78, green: 0.93, blue: 0.90),
        border: Color(red: 0.74, green: 0.89, blue: 0.86),
        shadow: Color.black.opacity(0.10),
        progressTrack: Color(red: 0.80, green: 0.92, blue: 0.90),
        progressFill: Color(red: 0.02, green: 0.48, blue: 0.44),
        fontTitle: .system(size: 22, weight: .semibold, design: .serif),
        fontBody: .system(size: 16, weight: .regular, design: .rounded),
        fontLabel: .system(size: 13, weight: .medium, design: .rounded),
        fontTag: .system(size: 12, weight: .medium, design: .rounded)
    )

    static let vibrantProgress = DemoStyle(
        name: "Vibrant Progress",
        tagline: "Energy + clear progress cues",
        swatches: [
            Color(red: 0.20, green: 0.33, blue: 0.95),
            Color(red: 0.28, green: 0.44, blue: 0.98),
            Color(red: 0.84, green: 0.88, blue: 1.0),
            Color(red: 0.93, green: 0.95, blue: 1.0),
            Color(red: 0.76, green: 0.82, blue: 0.97)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.93, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        surface: Color.white,
        surfaceAlt: Color(red: 0.93, green: 0.95, blue: 1.0),
        textPrimary: Color(red: 0.08, green: 0.10, blue: 0.18),
        textSecondary: Color(red: 0.32, green: 0.35, blue: 0.45),
        textOnAccent: .white,
        accent: Color(red: 0.28, green: 0.44, blue: 0.98),
        accentStrong: Color(red: 0.20, green: 0.33, blue: 0.95),
        accentSoft: Color(red: 0.84, green: 0.88, blue: 1.0),
        border: Color(red: 0.76, green: 0.82, blue: 0.97),
        shadow: Color.black.opacity(0.12),
        progressTrack: Color(red: 0.83, green: 0.88, blue: 0.98),
        progressFill: Color(red: 0.20, green: 0.33, blue: 0.95),
        fontTitle: .system(size: 22, weight: .bold, design: .rounded),
        fontBody: .system(size: 16, weight: .medium, design: .rounded),
        fontLabel: .system(size: 13, weight: .medium, design: .rounded),
        fontTag: .system(size: 12, weight: .semibold, design: .rounded)
    )
}

#Preview {
    UiRefactorDemoView()
}
