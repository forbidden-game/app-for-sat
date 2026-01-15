import Foundation

struct CoachChatAudioPayload {
    static let prefix = "audio://"

    let fileName: String
    let duration: TimeInterval

    var encodedText: String {
        "\(Self.prefix)\(fileName)|\(String(format: "%.2f", duration))"
    }

    static func parse(from text: String) -> CoachChatAudioPayload? {
        guard text.hasPrefix(prefix) else { return nil }
        let body = text.dropFirst(prefix.count)
        let parts = body.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count >= 1 else { return nil }
        let fileName = String(parts[0])
        let duration = parts.count == 2 ? TimeInterval(parts[1]) ?? 0 : 0
        return CoachChatAudioPayload(fileName: fileName, duration: duration)
    }
}
