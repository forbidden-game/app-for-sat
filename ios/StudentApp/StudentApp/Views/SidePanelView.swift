import Foundation
import SwiftUI

struct SidePanelView: View {
    let displayName: String
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(AppTheme.divider)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.surfaceRaised)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text(initials)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    )

                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            Button(action: onSignOut) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sign Out")
                        .font(.headline)
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(versionString)
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadowStrong, radius: 22, x: 0, y: 12)
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        let text = letters.map { String($0) }.joined()
        return text.isEmpty ? "S" : text.uppercased()
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

struct SidePanelHost<Content: View, Panel: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    let panel: Panel
    @State private var dragOffset: CGFloat = 0

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder panel: () -> Panel) {
        self._isPresented = isPresented
        self.content = content()
        self.panel = panel()
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let panelWidth = min(width * 0.78, 320)

            ZStack(alignment: .trailing) {
                content

                if isPresented {
                    AppTheme.shadowStrong.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }
                }

                panel
                    .frame(width: panelWidth)
                    .offset(x: isPresented ? max(dragOffset, 0) : panelWidth)
                    .gesture(panelDragGesture(width: panelWidth))
                    .allowsHitTesting(isPresented)
                    .animation(.easeOut(duration: 0.25), value: isPresented)
            }
            .animation(.easeOut(duration: 0.2), value: dragOffset)
        }
    }

    private func panelDragGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard isPresented else { return }
                dragOffset = max(value.translation.width, 0)
            }
            .onEnded { value in
                guard isPresented else {
                    dragOffset = 0
                    return
                }
                let shouldClose = value.translation.width > width * 0.35
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                    if shouldClose {
                        isPresented = false
                    }
                }
            }
    }
}
