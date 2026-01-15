import Foundation

final class SwiftMathRenderer: MathNativeRendering {
    func payload(
        latex: String,
        plainText: String,
        style: MathTextStyle,
        isDisplay: Bool
    ) -> MathNativePayload? {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return MathNativePayload(
            latex: trimmed,
            plainText: plainText,
            style: style,
            isDisplay: isDisplay
        )
    }
}
