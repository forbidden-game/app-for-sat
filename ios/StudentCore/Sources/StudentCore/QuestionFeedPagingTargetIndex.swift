import CoreGraphics

public enum QuestionFeedPagingTargetIndex {
    public static func verticalTargetIndex(
        currentIndex: Int,
        maxIndex: Int,
        proposedIndex: Int,
        translationY: CGFloat,
        velocityY: CGFloat,
        pageHeight: CGFloat,
        minTranslationRatio: CGFloat = 0.1,
        minVelocity: CGFloat = 0.3
    ) -> Int {
        guard pageHeight > 0 else { return currentIndex }

        let minTranslation = pageHeight * minTranslationRatio
        let meetsTranslation = abs(translationY) > minTranslation
        let meetsVelocity = abs(velocityY) > minVelocity

        guard meetsTranslation || meetsVelocity else {
            return currentIndex
        }

        return max(0, min(proposedIndex, maxIndex))
    }
}
