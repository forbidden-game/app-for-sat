import SwiftMath
import SwiftUI
import UIKit

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

        uiView.font = mathFont
        uiView.textAlignment = mtTextAlignment(from: payload.style.textAlignment)
        uiView.textColor = UIColor(AppTheme.textPrimary)
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
