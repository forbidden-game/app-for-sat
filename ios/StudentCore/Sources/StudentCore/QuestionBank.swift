import Foundation

public struct QuestionBank: Codable, Equatable, Identifiable {
    public let id: String
    public let slug: String
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let mode: String
    public let questionLimit: Int
    public let sortOrder: Int?

    public init(
        id: String,
        slug: String,
        title: String,
        subtitle: String?,
        icon: String?,
        mode: String,
        questionLimit: Int,
        sortOrder: Int?
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.mode = mode
        self.questionLimit = questionLimit
        self.sortOrder = sortOrder
    }

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case title
        case subtitle
        case icon
        case mode
        case questionLimit = "question_limit"
        case sortOrder = "sort_order"
    }
}
