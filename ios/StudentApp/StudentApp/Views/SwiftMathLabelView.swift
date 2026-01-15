import SwiftMath
import SwiftUI

struct SwiftMathLabelView: UIViewRepresentable {
    let payload: MathNativePayload

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        let fontManager = MTFontManager()
        let mathFont = fontManager.font(
            withName: MathFont.latinModernFont.rawValue,
            size: payload.style.fontSize
        )
        mathFont?.fallbackFont = UIFont.systemFont(
            ofSize: payload.style.fontSize,
            weight: uiFontWeight(from: payload.style.fontWeight)
        )

        uiView.font = mathFont
        uiView.textAlignment = mtTextAlignment(from: payload.style.textAlignment)
        uiView.textColor = MTColor(AppTheme.textPrimary)
        uiView.labelMode = payload.isDisplay ? .display : .text
        uiView.contentInsets = MTEdgeInsets()
        uiView.latex = payload.latex
        uiView.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MTMathUILabel,
        context: Context
    ) -> CGSize? {
        let size = proposal.replacingUnspecifiedDimensions()
        uiView.preferredMaxLayoutWidth = size.width
        return uiView.sizeThatFits(size)
    }
}

private func mtTextAlignment(from alignment: TextAlignment) -> MTTextAlignment {
    switch alignment {
    case .center:
        return .center
    case .trailing:
        return .right
    default:
        return .left
    }
}

private func uiFontWeight(from weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .bold:
        return .bold
    case .semibold:
        return .semibold
    case .medium:
        return .medium
    case .light:
        return .light
    default:
        return .regular
    }
}
