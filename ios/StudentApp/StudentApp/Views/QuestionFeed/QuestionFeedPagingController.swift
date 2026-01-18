import UIKit
import SwiftUI
import StudentCore

private protocol QuestionFeedGestureGate: AnyObject {
    var canPageUp: Bool { get }
    var canPageDown: Bool { get }
    var isInputFocused: Bool { get }
    var horizontalPageCount: Int { get }
}

private final class QuestionFeedCollectionView: UICollectionView {
    weak var gestureGate: QuestionFeedGestureGate?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }

            let translation = pan.translation(in: self)
            let velocity = pan.velocity(in: self)
            let dy = abs(translation.y) > 0 ? translation.y : velocity.y
            let dx = abs(translation.x) > 0 ? translation.x : velocity.x

            let hasHorizontalPages = (gestureGate?.horizontalPageCount ?? 1) > 1
            let horizontalBias: CGFloat = hasHorizontalPages ? 1.2 : 1.4

            // Let vertical paging begin unless the gesture is clearly horizontal.
            if abs(dx) > abs(dy) * horizontalBias {
                return false
            }

            return true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

final class QuestionFeedPagingController: UIViewController {
    private var session: PracticeSession
    private var state: QuestionFeedState
    private var store: InMemoryAnswerStore
    private var submission: AnswerSubmissionCoordinator
    private var returnToOverviewOnAnswer: Binding<Bool>
    private var headerTitle: String?
    private var onBack: () -> Void
    private var onShowOverview: () -> Void
    private var onSubmissionError: (Error) -> Void

    private var collectionView: QuestionFeedCollectionView!
    private var currentPageIndex: Int
    private var lastAppliedStateIndex: Int?
    private var lastFinalizedPageIndex: Int?
    private var isProgrammaticScroll = false
    private var didLayoutOnce = false
    private var questionIds: [String]
    private var lastDragTranslation: CGPoint = .zero

    init(
        session: PracticeSession,
        state: QuestionFeedState,
        store: InMemoryAnswerStore,
        submission: AnswerSubmissionCoordinator,
        returnToOverviewOnAnswer: Binding<Bool>,
        headerTitle: String?,
        onBack: @escaping () -> Void,
        onShowOverview: @escaping () -> Void,
        onSubmissionError: @escaping (Error) -> Void
    ) {
        self.session = session
        self.state = state
        self.store = store
        self.submission = submission
        self.returnToOverviewOnAnswer = returnToOverviewOnAnswer
        self.headerTitle = headerTitle
        self.onBack = onBack
        self.onShowOverview = onShowOverview
        self.onSubmissionError = onSubmissionError
        self.questionIds = session.questions.map { $0.id }
        self.currentPageIndex = max(0, min(state.currentIndex, max(session.questions.count - 1, 0)))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupCollectionView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayoutIfNeeded()
        if !didLayoutOnce {
            didLayoutOnce = true
            scrollToPage(currentPageIndex, animated: false, programmatic: true)
        }
    }

    func update(
        session: PracticeSession,
        state: QuestionFeedState,
        store: InMemoryAnswerStore,
        submission: AnswerSubmissionCoordinator,
        returnToOverviewOnAnswer: Binding<Bool>,
        headerTitle: String?,
        onBack: @escaping () -> Void,
        onShowOverview: @escaping () -> Void,
        onSubmissionError: @escaping (Error) -> Void
    ) {
        self.session = session
        self.state = state
        self.store = store
        self.submission = submission
        self.returnToOverviewOnAnswer = returnToOverviewOnAnswer
        self.headerTitle = headerTitle
        self.onBack = onBack
        self.onShowOverview = onShowOverview
        self.onSubmissionError = onSubmissionError

        let newIds = session.questions.map { $0.id }
        if newIds != questionIds {
            questionIds = newIds
            collectionView.reloadData()
        }

        collectionView.alwaysBounceVertical = session.questions.count > 1
        applyIndexFromStateIfNeeded()
    }
}

// MARK: - Setup

private extension QuestionFeedPagingController {
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero

        let collectionView = QuestionFeedCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = false
        collectionView.alwaysBounceVertical = session.questions.count > 1
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.isDirectionalLockEnabled = true
        collectionView.delaysContentTouches = false
        collectionView.canCancelContentTouches = true
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(QuestionCell.self, forCellWithReuseIdentifier: QuestionCell.reuseIdentifier)
        collectionView.gestureGate = self

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.collectionView = collectionView
    }

    func updateLayoutIfNeeded() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let size = view.bounds.size
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
        }
    }
}

// MARK: - Data Source

extension QuestionFeedPagingController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        session.questions.count + 1
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: QuestionCell.reuseIdentifier,
            for: indexPath
        ) as? QuestionCell else {
            return UICollectionViewCell()
        }

        let total = session.questions.count
        let isOverview = indexPath.item >= total
        let question = isOverview ? nil : session.questions[indexPath.item]
        let config = QuestionCellConfiguration(
            question: question,
            index: indexPath.item,
            total: total,
            isOverview: isOverview,
            isActive: indexPath.item == currentPageIndex,
            headerTitle: headerTitle,
            state: state,
            store: store,
            submission: submission,
            returnToOverviewOnAnswer: returnToOverviewOnAnswer,
            onBack: onBack,
            onShowOverview: onShowOverview,
            onSubmissionError: onSubmissionError
        )

        cell.configure(config, outerPan: collectionView.panGestureRecognizer)
        return cell
    }
}

// MARK: - Paging

extension QuestionFeedPagingController: UICollectionViewDelegate, UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            lastDragTranslation = .zero
            if state.inputState.isFocused {
                state.setFocus(false)
            }
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollView === collectionView else { return }
        let pageHeight = scrollView.bounds.height
        guard pageHeight > 0 else { return }

        let translation = lastDragTranslation == .zero
            ? collectionView.panGestureRecognizer.translation(in: collectionView)
            : lastDragTranslation

        let minTranslation = pageHeight * 0.06
        let minVelocity: CGFloat = 0.2

        var targetIndex = currentPageIndex
        let meetsTranslation = abs(translation.y) > minTranslation
        let meetsVelocity = abs(velocity.y) > minVelocity

        if meetsTranslation || meetsVelocity {
            let maxIndex = session.questions.count
            let direction = meetsTranslation ? translation.y : velocity.y
            if direction > 0 {
                targetIndex = max(currentPageIndex - 1, 0)
            } else if direction < 0 {
                targetIndex = min(currentPageIndex + 1, maxIndex)
            }
        }

        targetContentOffset.pointee = CGPoint(x: 0, y: CGFloat(targetIndex) * pageHeight)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === collectionView, scrollView.isDragging {
            lastDragTranslation = collectionView.panGestureRecognizer.translation(in: collectionView)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finalizePageChange()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            finalizePageChange()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        finalizePageChange()
    }
}

// MARK: - Gesture Gate

extension QuestionFeedPagingController: QuestionFeedGestureGate {
    var canPageUp: Bool { currentPageIndex > 0 }
    var canPageDown: Bool { currentPageIndex < session.questions.count }
    var isInputFocused: Bool { state.inputState.isFocused }
    var horizontalPageCount: Int {
        guard currentPageIndex < session.questions.count else { return 1 }
        let questionId = session.questions[currentPageIndex].id
        return state.stemPageCount(for: questionId)
    }
}

// MARK: - Helpers

private extension QuestionFeedPagingController {
    func applyIndexFromStateIfNeeded() {
        guard isViewLoaded else { return }
        guard collectionView.bounds.height > 0 else { return }
        let total = session.questions.count
        guard total > 0 else { return }
        let target = max(0, min(state.currentIndex, total - 1))
        let diff = lastAppliedStateIndex.map { abs(target - $0) } ?? 0
        let shouldAnimate = didLayoutOnce && view.window != nil && diff == 1
        if target != currentPageIndex || !didLayoutOnce {
            currentPageIndex = target
            scrollToPage(target, animated: shouldAnimate, programmatic: true)
        }
        lastAppliedStateIndex = target
    }

    func scrollToPage(_ index: Int, animated: Bool, programmatic: Bool) {
        let totalPages = session.questions.count + 1
        guard index >= 0, index < totalPages else { return }
        let indexPath = IndexPath(item: index, section: 0)
        if programmatic {
            isProgrammaticScroll = true
        }
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
        if !animated {
            finalizePageChange()
        }
    }

    func finalizePageChange() {
        guard let pageIndex = centeredIndexPath()?.item else { return }
        let totalQuestions = session.questions.count
        currentPageIndex = pageIndex
        updateVisibleCellActiveStates()

        if pageIndex >= totalQuestions {
            onShowOverview()
            lastFinalizedPageIndex = pageIndex
            return
        }

        let isNewPage = pageIndex != lastFinalizedPageIndex
        if isNewPage {
            if !isProgrammaticScroll {
                triggerPageHaptic()
            }
            state.setFocus(false)
            state.jump(to: pageIndex, total: totalQuestions)
            loadAnswer(for: session.questions[pageIndex])
            lastFinalizedPageIndex = pageIndex
        }

        isProgrammaticScroll = false
    }

    func centeredIndexPath() -> IndexPath? {
        let point = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        return collectionView.indexPathForItem(at: point)
    }

    func updateVisibleCellActiveStates() {
        for cell in collectionView.visibleCells {
            guard let questionCell = cell as? QuestionCell else { continue }
            questionCell.setActive(questionCell.index == currentPageIndex)
        }
    }

    func loadAnswer(for question: Question) {
        let isMultipleChoice = (question.options?.isEmpty == false)
        state.resetInput(for: question.id, from: store, isMultipleChoice: isMultipleChoice)
    }

    func triggerPageHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
