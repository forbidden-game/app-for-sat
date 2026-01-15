import SwiftUI

enum CoachChatDemoVariant {
    case warmScholar
    case focusMode
    case auroraMentor
}

struct CoachChatDemoStyle {
    let variant: CoachChatDemoVariant
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
    let border: Color
    let shadow: Color
    let userBubble: AnyShapeStyle
    let assistantBubble: AnyShapeStyle
    let assistantStroke: Color
    let chipBackground: Color
    let chipStroke: Color
    let fontTitle: Font
    let fontBody: Font
    let fontLabel: Font
    let fontCaption: Font
    let bubbleCorner: CGFloat
    let cardCorner: CGFloat
    let messageSpacing: CGFloat
}

enum CoachChatDemoMessageContent {
    case text(String)
    case audio(duration: String)
    case image(caption: String?)
}

struct CoachChatDemoMessage: Identifiable {
    let id = UUID()
    let role: CoachChatDemoRole
    let content: CoachChatDemoMessageContent
    let isStreaming: Bool
}

enum CoachChatDemoRole {
    case user
    case assistant
}

extension CoachChatDemoMessage {
    static func samples(for variant: CoachChatDemoVariant) -> [CoachChatDemoMessage] {
        switch variant {
        case .warmScholar:
            return [
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("我们先看第 12 题。把 5 移到右边，你会写成什么？"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .user,
                    content: .text("3x = 21"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("很好，所以 x = 7。写等式再移项，可以减少符号错误。"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .user,
                    content: .text("我可以写成 26 - 5 吗？"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("可以，本质一样。注意把常数移项时符号改变。"),
                    isStreaming: true
                )
            ]
        case .focusMode:
            return [
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("Focus rule：先列式，再移项。"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .user,
                    content: .audio(duration: "0:18"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("听到啦。你已经把等式结构写对了。"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .user,
                    content: .image(caption: "题目截图"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("这题下一步把 5 移到右侧，记得变号。"),
                    isStreaming: true
                )
            ]
        case .auroraMentor:
            return [
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("我们先看第 12 题。把 5 移到右边，你会写成什么？"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .user,
                    content: .text("3x = 21"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("很好，所以 x = 7。写等式再移项，可以减少符号错误。"),
                    isStreaming: false
                ),
                CoachChatDemoMessage(
                    role: .assistant,
                    content: .text("要不要来一道类似题？"),
                    isStreaming: false
                )
            ]
        }
    }
}

extension CoachChatDemoStyle {
    static let warmScholar = CoachChatDemoStyle(
        variant: .warmScholar,
        name: "Warm Scholar",
        tagline: "Soft UI warmth with clear structure",
        swatches: [
            Color(red: 0.31, green: 0.27, blue: 0.90),
            Color(red: 0.51, green: 0.55, blue: 0.98),
            Color(red: 0.98, green: 0.55, blue: 0.25),
            Color(red: 0.93, green: 0.95, blue: 1.0),
            Color(red: 0.78, green: 0.82, blue: 0.98)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.99, green: 0.98, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        surface: Color.white,
        surfaceAlt: Color(red: 0.94, green: 0.95, blue: 1.0),
        textPrimary: Color(red: 0.12, green: 0.11, blue: 0.29),
        textSecondary: Color(red: 0.32, green: 0.30, blue: 0.48),
        textOnAccent: .white,
        accent: Color(red: 0.31, green: 0.27, blue: 0.90),
        border: Color(red: 0.78, green: 0.82, blue: 0.98),
        shadow: Color.black.opacity(0.10),
        userBubble: AnyShapeStyle(Color(red: 0.31, green: 0.27, blue: 0.90)),
        assistantBubble: AnyShapeStyle(Color.white),
        assistantStroke: Color(red: 0.78, green: 0.82, blue: 0.98),
        chipBackground: Color(red: 0.93, green: 0.95, blue: 1.0),
        chipStroke: Color(red: 0.78, green: 0.82, blue: 0.98),
        fontTitle: .system(size: 22, weight: .semibold, design: .rounded),
        fontBody: .system(size: 15, weight: .regular, design: .rounded),
        fontLabel: .system(size: 13, weight: .semibold, design: .rounded),
        fontCaption: .system(size: 12, weight: .medium, design: .rounded),
        bubbleCorner: 18,
        cardCorner: 18,
        messageSpacing: 12
    )

    static let focusMode = CoachChatDemoStyle(
        variant: .focusMode,
        name: "Focus Mode",
        tagline: "Minimal distraction, exam-ready",
        swatches: [
            Color(red: 0.06, green: 0.09, blue: 0.15),
            Color(red: 0.98, green: 0.45, blue: 0.21),
            Color(red: 0.95, green: 0.96, blue: 0.98),
            Color(red: 0.99, green: 0.99, blue: 0.99),
            Color(red: 0.89, green: 0.91, blue: 0.94)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.99, blue: 1.0), Color(red: 0.97, green: 0.98, blue: 0.99)],
                startPoint: .top,
                endPoint: .bottom
            )
        ),
        surface: Color.white,
        surfaceAlt: Color(red: 0.95, green: 0.96, blue: 0.98),
        textPrimary: Color(red: 0.06, green: 0.09, blue: 0.15),
        textSecondary: Color(red: 0.33, green: 0.36, blue: 0.41),
        textOnAccent: .white,
        accent: Color(red: 0.98, green: 0.45, blue: 0.21),
        border: Color(red: 0.89, green: 0.91, blue: 0.94),
        shadow: Color.black.opacity(0.08),
        userBubble: AnyShapeStyle(Color(red: 0.06, green: 0.09, blue: 0.15)),
        assistantBubble: AnyShapeStyle(Color.white),
        assistantStroke: Color(red: 0.89, green: 0.91, blue: 0.94),
        chipBackground: Color.white,
        chipStroke: Color(red: 0.89, green: 0.91, blue: 0.94),
        fontTitle: .system(size: 22, weight: .semibold, design: .serif),
        fontBody: .system(size: 15, weight: .regular, design: .serif),
        fontLabel: .system(size: 13, weight: .medium, design: .serif),
        fontCaption: .system(size: 12, weight: .regular, design: .serif),
        bubbleCorner: 10,
        cardCorner: 12,
        messageSpacing: 10
    )

    static let auroraMentor = CoachChatDemoStyle(
        variant: .auroraMentor,
        name: "Aurora Mentor",
        tagline: "Luminous gradients with a premium coach feel",
        swatches: [
            Color(red: 0.00, green: 0.50, blue: 1.0),
            Color(red: 0.00, green: 0.85, blue: 0.95),
            Color(red: 0.98, green: 0.20, blue: 0.60),
            Color(red: 0.94, green: 0.96, blue: 1.0),
            Color(red: 0.84, green: 0.90, blue: 1.0)
        ],
        background: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        surface: Color.white.opacity(0.92),
        surfaceAlt: Color(red: 0.93, green: 0.96, blue: 1.0),
        textPrimary: Color(red: 0.08, green: 0.10, blue: 0.18),
        textSecondary: Color(red: 0.36, green: 0.40, blue: 0.52),
        textOnAccent: .white,
        accent: Color(red: 0.00, green: 0.50, blue: 1.0),
        border: Color(red: 0.84, green: 0.90, blue: 1.0),
        shadow: Color.black.opacity(0.12),
        userBubble: AnyShapeStyle(
            LinearGradient(
                colors: [Color(red: 0.00, green: 0.55, blue: 1.0), Color(red: 0.00, green: 0.78, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        assistantBubble: AnyShapeStyle(Color.white.opacity(0.95)),
        assistantStroke: Color(red: 0.84, green: 0.90, blue: 1.0),
        chipBackground: Color.white.opacity(0.9),
        chipStroke: Color(red: 0.84, green: 0.90, blue: 1.0),
        fontTitle: .system(size: 22, weight: .bold, design: .rounded),
        fontBody: .system(size: 15, weight: .medium, design: .rounded),
        fontLabel: .system(size: 13, weight: .semibold, design: .rounded),
        fontCaption: .system(size: 12, weight: .medium, design: .rounded),
        bubbleCorner: 20,
        cardCorner: 20,
        messageSpacing: 12
    )
}
