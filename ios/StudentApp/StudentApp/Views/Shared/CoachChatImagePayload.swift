import Foundation
import CoreGraphics

struct CoachChatImagePayload {
    static let prefix = "image://"

    let fileName: String
    let width: CGFloat
    let height: CGFloat
    let caption: String?

    var encodedText: String {
        var parts: [String] = [
            fileName,
            String(format: "%.0f", width),
            String(format: "%.0f", height)
        ]
        if let caption, let encoded = caption.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            parts.append(encoded)
        }
        return "\(Self.prefix)\(parts.joined(separator: "|"))"
    }

    static func parse(from text: String) -> CoachChatImagePayload? {
        guard text.hasPrefix(prefix) else { return nil }
        let body = text.dropFirst(prefix.count)
        let parts = body.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 1 else { return nil }
        let fileName = String(parts[0])
        let width = parts.count >= 2 ? CGFloat(Double(parts[1]) ?? 0) : 0
        let height = parts.count >= 3 ? CGFloat(Double(parts[2]) ?? 0) : 0
        let caption: String?
        if parts.count >= 4 {
            caption = String(parts[3]).removingPercentEncoding
        } else {
            caption = nil
        }
        return CoachChatImagePayload(fileName: fileName, width: width, height: height, caption: caption)
    }
}
