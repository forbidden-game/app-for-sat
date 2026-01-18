import UIKit
import SwiftUI
import StudentCore

protocol QuestionCellDelegate: AnyObject {
    func questionCell(_ cell: QuestionCell, didUpdateBoundary state: ScrollBoundaryState)
}

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
}

final class QuestionCell: UICollectionViewCell, UIScrollViewDelegate {
    static let reuseIdentifier = "QuestionCell"

    weak var delegate: QuestionCellDelegate?

    private let scrollView = UIScrollView()
    private var hostingController: UIHostingController<AnyView>?
    private var lastResetQuestionId: String = ""
    private var boundaryState: ScrollBoundaryState = .neutral
    private var isActive: Bool = false
    private var questionId: String = ""
    private weak var outerPanGesture: UIPanGestureRecognizer?
    private var didAttachOuterRequirement = false

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
        delegate = nil
        index = 0
        isActive = false
        lastResetQuestionId = ""
        boundaryState = .neutral
        scrollToTop(animated: false)
    }

    func configure(_ config: QuestionCellConfiguration, outerPan: UIPanGestureRecognizer?) {
        index = config.index
        questionId = config.question?.id ?? "overview"
        outerPanGesture = outerPan

        let rootView: AnyView
        if config.isOverview {
            rootView = AnyView(QuestionOverviewView(total: config.total))
        } else if let question = config.question {
            let contentView = QuestionContentView(
                question: question,
                index: config.index,
                total: config.total,
                state: config.state,
                store: config.store,
                submission: config.submission,
                returnToOverviewOnAnswer: config.returnToOverviewOnAnswer,
                headerTitle: config.headerTitle,
                onBack: config.onBack,
                onShowOverview: config.onShowOverview,
                onSubmissionError: config.onSubmissionError
            )
            .id(question.id)
            rootView = AnyView(contentView)
        } else {
            rootView = AnyView(EmptyView())
        }

        ensureHostingController()
        hostingController?.rootView = rootView

        setActive(config.isActive, forceReset: true)

        setNeedsLayout()
        layoutIfNeeded()
        updateBoundary(forceNotify: true)
    }

    func refreshBoundary() {
        updateBoundary(forceNotify: true)
    }

    func setActive(_ active: Bool, forceReset: Bool = false) {
        let shouldReset = forceReset || active != isActive
        isActive = active
        if active && shouldReset {
            resetIfNeeded(for: questionId)
            updateBoundary(forceNotify: true)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBoundary(forceNotify: false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateBoundary(forceNotify: false)
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self

        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func ensureHostingController() {
        if let hostingController { return }
        let controller = UIHostingController(rootView: AnyView(EmptyView()))
        if #available(iOS 16.0, *) {
            controller.sizingOptions = [.intrinsicContentSize]
        }
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            controller.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        hostingController = controller
    }

    private func resetIfNeeded(for questionId: String) {
        guard questionId != lastResetQuestionId else { return }
        lastResetQuestionId = questionId
        scrollToTop(animated: false)
    }

    private func scrollToTop(animated: Bool) {
        let topInset = scrollView.adjustedContentInset.top
        scrollView.setContentOffset(CGPoint(x: 0, y: -topInset), animated: animated)
    }

    private func updateBoundary(forceNotify: Bool) {
        let newState = computeBoundaryState()
        if newState == boundaryState && !forceNotify { return }
        boundaryState = newState
        scrollView.isScrollEnabled = newState.isScrollable
        scrollView.alwaysBounceVertical = newState.isScrollable
        applyOuterRequirementIfNeeded(isScrollable: newState.isScrollable)
        if isActive {
            delegate?.questionCell(self, didUpdateBoundary: newState)
        }
    }

    private func computeBoundaryState() -> ScrollBoundaryState {
        let viewportHeight = scrollView.bounds.height
        let contentHeight = scrollView.contentSize.height
        let inset = scrollView.adjustedContentInset
        let offsetY = scrollView.contentOffset.y
        return ScrollBoundaryCalculator.calculate(
            contentHeight: Double(contentHeight),
            viewportHeight: Double(viewportHeight),
            offsetY: Double(offsetY),
            insetTop: Double(inset.top),
            insetBottom: Double(inset.bottom)
        )
    }

    private func applyOuterRequirementIfNeeded(isScrollable: Bool) {
        guard isScrollable, !didAttachOuterRequirement else { return }
        guard let outerPanGesture else { return }
        outerPanGesture.require(toFail: scrollView.panGestureRecognizer)
        didAttachOuterRequirement = true
    }
}
