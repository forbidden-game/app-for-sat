import Foundation
import UIKit

enum CoachChatImageStore {
    private static let directoryName = "CoachImages"
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 40
        return cache
    }()

    static func imageURL(fileName: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(fileName)
    }

    @MainActor
    static func saveCompressedImage(
        _ image: UIImage,
        maxDimension: CGFloat = 1280,
        quality: CGFloat = 0.78,
        caption: String? = nil
    ) throws -> CoachChatImagePayload {
        try save(image, maxDimension: maxDimension, quality: quality, caption: caption)
    }

    static func loadImage(fileName: String) -> UIImage? {
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }
        let url = imageURL(fileName: fileName)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    private static func save(
        _ image: UIImage,
        maxDimension: CGFloat,
        quality: CGFloat,
        caption: String?
    ) throws -> CoachChatImagePayload {
        let scaled = scale(image: image, maxDimension: maxDimension)
        let data: Data
        let fileName: String
        if let jpegData = scaled.jpegData(compressionQuality: quality) {
            data = jpegData
            fileName = "coach-image-\(UUID().uuidString).jpg"
        } else if let pngData = scaled.pngData() {
            data = pngData
            fileName = "coach-image-\(UUID().uuidString).png"
        } else {
            throw NSError(domain: "CoachChatImageStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image encode failed"])
        }

        let url = imageURL(fileName: fileName)
        try data.write(to: url, options: .atomic)

        cache.setObject(scaled, forKey: fileName as NSString)
        return CoachChatImagePayload(fileName: fileName, width: scaled.size.width, height: scaled.size.height, caption: caption)
    }

    private static func scale(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: UIGraphicsImageRendererFormat.default())
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
