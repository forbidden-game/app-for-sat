import Foundation

public struct ScrollBoundaryState: Equatable, Sendable {
    public let isScrollable: Bool
    public let atTop: Bool
    public let atBottom: Bool

    public static let neutral = ScrollBoundaryState(isScrollable: false, atTop: true, atBottom: true)
}

public enum ScrollBoundaryCalculator {
    public static func calculate(
        contentHeight: Double,
        viewportHeight: Double,
        offsetY: Double,
        insetTop: Double,
        insetBottom: Double,
        epsilon: Double = 2
    ) -> ScrollBoundaryState {
        guard viewportHeight > 0 else { return .neutral }
        let isShortContent = contentHeight <= viewportHeight
        let maxOffsetY = max(0, contentHeight - viewportHeight + insetBottom)
        let atTop = offsetY <= -insetTop + epsilon
        let atBottom = isShortContent || offsetY >= maxOffsetY - epsilon
        let isScrollable = contentHeight > viewportHeight
        return ScrollBoundaryState(isScrollable: isScrollable, atTop: atTop, atBottom: atBottom)
    }
}
