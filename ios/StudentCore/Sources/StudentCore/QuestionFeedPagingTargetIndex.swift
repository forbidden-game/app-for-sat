import CoreGraphics

public enum QuestionFeedPagingTargetIndex {
    public static func verticalTargetIndex(
        currentIndex: Int,
        maxIndex: Int,
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

        var targetIndex = currentIndex

        if meetsTranslation || meetsVelocity {
            let translationSign = translationY.sign
            let velocitySign = velocityY.sign
            let direction: CGFloat

            if meetsVelocity && meetsTranslation && translationSign != velocitySign {
                direction = velocityY
            } else if meetsVelocity {
                direction = velocityY
            } else {
                direction = translationY
            }

            if direction > 0 {
                targetIndex = min(currentIndex + 1, maxIndex)
            } else if direction < 0 {
                targetIndex = max(currentIndex - 1, 0)
            }
        }

        return targetIndex
    }
}
