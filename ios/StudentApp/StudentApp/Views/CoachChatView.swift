import SwiftUI
import UIKit
import StudentCore

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pendingImage: UIImage?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false

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
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(image: $pendingImage, sourceType: .camera)
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(image: $pendingImage, sourceType: .photoLibrary)
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

            HStack(spacing: 8) {
                CoachAvatarView(size: 28)
                Text("王校长")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    private func messageBubble(_ msg: CoachThreadMessage) -> some View {
        let isUser = msg.role == .user
        let bg = isUser ? AppTheme.accentStrong : AppTheme.surface
        let fg = isUser ? AppTheme.textOnAccent : AppTheme.textPrimary
        let stroke = isUser ? AppTheme.accentStrong : AppTheme.divider

        return HStack(alignment: .top, spacing: 10) {
            if !isUser {
                CoachAvatarView(size: 24)
                    .padding(.top, 2)
            }

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
                    .stroke(stroke, lineWidth: 1)
            )

            if isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
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

            if let pendingImage {
                pendingImagePreview(pendingImage)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                cameraButton

                TextField(
                    "",
                    text: $vm.draftText,
                    prompt: Text(vm.promptText)
                        .foregroundStyle(AppTheme.textSecondary),
                    axis: .vertical
                )
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await vm.send() }
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1.5)
                    )

                micButton
            }
            .padding(.horizontal, 16)
        }
    }

    private var cameraButton: some View {
        let tap = TapGesture().onEnded {
            openCamera()
        }
        let longPress = LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            openLibrary()
        }

        return Image(systemName: "camera")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 44, height: 44)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .gesture(longPress.exclusively(before: tap))
            .accessibilityLabel("拍照或相册")
            .accessibilityAddTraits(.isButton)
    }

    private var micButton: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.textOnAccent)
            .frame(width: 44, height: 44)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.accentStrong, lineWidth: 1.5)
            )
            .accessibilityLabel("语音输入")
            .accessibilityAddTraits(.isButton)
    }

    private func pendingImagePreview(_ image: UIImage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1.5)
                )
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("已选择图片")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("可继续输入问题")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                pendingImage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1.5)
        )
    }

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            showLibraryPicker = true
        }
    }

    private func openLibrary() {
        showLibraryPicker = true
    }
}
