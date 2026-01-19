import UIKit
import SwiftUI
import StudentCore

struct QuestionCellConfiguration {
    let question: Question?
    let index: Int
    let total: Int
    let isOverview: Bool
    let isActive: Bool
    let headerTitle: String?
    let state: QuestionFeedState
    let store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    let returnToOverviewOnAnswer: Binding<Bool>
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void
    let questionProvider: (Int) -> Question?
}

final class QuestionCell: UICollectionViewCell {
    static let reuseIdentifier = "QuestionCell"

    private var hostingController: UIHostingController<AnyView>?
    private(set) var index: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        index = 0
        hostingController?.rootView = AnyView(EmptyView())
    }

    func configure(_ config: QuestionCellConfiguration, outerPan: UIPanGestureRecognizer?) {
        index = config.index

        let rootView: AnyView
        if config.isOverview {
            rootView = AnyView(QuestionOverviewView(total: config.total))
        } else if let question = config.question {
            rootView = AnyView(
                QuestionContentView(
                    question: question,
                    index: config.index,
                    total: config.total,
                    questionProvider: config.questionProvider,
                    state: config.state,
                    store: config.store,
                    submission: config.submission,
                    returnToOverviewOnAnswer: config.returnToOverviewOnAnswer,
                    headerTitle: config.headerTitle,
                    onBack: config.onBack,
                    onShowOverview: config.onShowOverview,
                    onSubmissionError: config.onSubmissionError,
                    outerPan: outerPan
                )
                .id(question.id)
            )
        } else {
            rootView = AnyView(EmptyView())
        }

        ensureHostingController()
        hostingController?.rootView = rootView

        setActive(config.isActive)
    }

    func setActive(_ active: Bool) {
        // Keep for parity with the paging controller. The SwiftUI view gates interactivity
        // based on QuestionFeedState.currentIndex.
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        ensureHostingController()
    }

    private func ensureHostingController() {
        if hostingController != nil { return }

        let controller = UIHostingController(rootView: AnyView(EmptyView()))
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        hostingController = controller
    }
}
