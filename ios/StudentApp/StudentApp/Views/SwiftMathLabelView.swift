import SwiftMath
import SwiftUI
import UIKit

struct SwiftMathLabelView: UIViewRepresentable {
    let payload: MathNativePayload
    let textColor: Color
    let onError: (() -> Void)?

    init(payload: MathNativePayload, textColor: Color = AppTheme.textPrimary, onError: (() -> Void)? = nil) {
        self.payload = payload
        self.textColor = textColor
        self.onError = onError
    }

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.displayErrorInline = false
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        if context.coordinator.lastLatex != payload.latex {
            context.coordinator.lastLatex = payload.latex
            context.coordinator.didReportError = false
        }
        let fontManager = MTFontManager()
        let mathFont = fontManager.font(
            withName: MathFont.latinModernFont.rawValue,
            size: payload.style.fontSize
        )

        uiView.font = mathFont
        uiView.textAlignment = mtTextAlignment(from: payload.style.textAlignment)
        uiView.textColor = UIColor(textColor)
        uiView.labelMode = payload.isDisplay ? .display : .text
        uiView.contentInsets = MTEdgeInsets()
        uiView.latex = payload.latex
        if uiView.error != nil, context.coordinator.didReportError == false {
            context.coordinator.didReportError = true
            onError?()
        }
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var didReportError = false
        var lastLatex: String?
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
