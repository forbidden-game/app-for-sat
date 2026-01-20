import SwiftUI

struct BoardTextureView: View {
    var squareSize: CGFloat = 48
    var opacity: CGFloat = 0.05

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let cols = Int(size.width / squareSize) + 1
                let rows = Int(size.height / squareSize) + 1
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isLight = (row + col) % 2 == 0
                        let color = isLight ? AppTheme.boardLight.opacity(opacity) : AppTheme.boardDark.opacity(opacity)
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct PracticeBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
            BoardTextureView()
        }
        .ignoresSafeArea()
    }
}
