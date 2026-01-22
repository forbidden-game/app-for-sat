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

private struct PracticeNoiseView: View {
    private let step: CGFloat = 4

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let cols = Int(size.width / step) + 1
                let rows = Int(size.height / step) + 1

                for row in 0..<rows {
                    for col in 0..<cols {
                        let value = noiseValue(x: col, y: row)
                        let rect = CGRect(
                            x: CGFloat(col) * step,
                            y: CGFloat(row) * step,
                            width: step,
                            height: step
                        )
                        context.fill(Path(rect), with: .color(Color(white: value)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func noiseValue(x: Int, y: Int) -> Double {
        var value = UInt64(x) &* 374761393 &+ UInt64(y) &* 668265263
        value = (value ^ (value >> 13)) &* 1274126177
        return Double(value & 0xFF) / 255.0
    }
}

struct PracticeBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height) * 0.75

            ZStack {
                RadialGradient(
                    colors: [AppTheme.backgroundPrimary, AppTheme.backgroundSecondary],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )

                PracticeNoiseView()
                    .blendMode(.overlay)
                    .opacity(0.025)
            }
            .ignoresSafeArea()
        }
    }
}
