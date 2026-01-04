import SwiftUI

struct SessionSummaryView: View {
    let total: Int
    let correct: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Session Complete").font(.title)
            Text("Score: \(correct)/\(total)")
        }
        .padding()
    }
}
