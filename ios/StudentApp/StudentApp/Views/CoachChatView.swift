import SwiftUI
import StudentCore

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: CoachChatViewModel

    init(studentId: String, linkedAttemptId: String? = nil, initialDraftText: String? = nil) {
        _vm = StateObject(
            wrappedValue: CoachChatViewModel(
                studentId: studentId,
                linkedAttemptId: linkedAttemptId,
                initialDraftText: initialDraftText
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                composer
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .task {
            await vm.load()
        }
        .onDisappear {
            Task { await vm.stop() }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("王校长")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    private func messageBubble(_ msg: CoachThreadMessage) -> some View {
        let isUser = msg.role == .user
        let bg = isUser ? AppTheme.accentStrong : AppTheme.surfaceRaised
        let fg = isUser ? AppTheme.textOnAccent : AppTheme.textPrimary

        return HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 6) {
                Text(msg.content.text)
                    .font(.body)
                    .foregroundStyle(fg)
                    .fixedSize(horizontal: false, vertical: true)

                if msg.role == .assistant, msg.content.status == "streaming" {
                    Text("…")
                        .font(.footnote)
                        .foregroundStyle(fg.opacity(0.8))
                }
            }
            .padding(12)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isUser ? AppTheme.accent.opacity(0.4) : AppTheme.dividerStrong, lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let error = vm.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                TextField("问老师一个问题…", text: $vm.draftText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...4)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(AppTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.dividerStrong, lineWidth: 1)
                    )

                Button {
                    Task { await vm.send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(vm.isSending)
            }
            .padding(.horizontal, 16)
        }
    }
}
