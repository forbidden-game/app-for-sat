import SwiftUI
import UIKit

enum QuestionHorizontalPage: Equatable {
    case stem(String)
    case answer
}

struct QuestionHorizontalPagerView: UIViewControllerRepresentable {
    let pages: [QuestionHorizontalPage]
    let currentIndex: Int
    let outerPan: UIPanGestureRecognizer?
    let onPageChange: (Int) -> Void
    let onUserInteraction: () -> Void
    let pageBuilder: (QuestionHorizontalPage) -> AnyView

    func makeUIViewController(context: Context) -> QuestionHorizontalPagingController {
        QuestionHorizontalPagingController(
            pages: pages,
            currentIndex: currentIndex,
            outerPan: outerPan,
            onPageChange: onPageChange,
            onUserInteraction: onUserInteraction,
            pageBuilder: pageBuilder
        )
    }

    func updateUIViewController(_ controller: QuestionHorizontalPagingController, context: Context) {
        controller.update(
            pages: pages,
            currentIndex: currentIndex,
            outerPan: outerPan,
            onPageChange: onPageChange,
            onUserInteraction: onUserInteraction,
            pageBuilder: pageBuilder
        )
    }
}

private final class HorizontalCollectionView: UICollectionView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }

            let translation = pan.translation(in: self)
            let velocity = pan.velocity(in: self)
            let dy = abs(translation.y) > 0 ? translation.y : velocity.y
            let dx = abs(translation.x) > 0 ? translation.x : velocity.x

            // Only allow horizontal paging when the gesture is clearly horizontal.
            if abs(dx) <= abs(dy) * 1.05 {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

final class QuestionHorizontalPagingController: UIViewController {
    private var pages: [QuestionHorizontalPage]
    private var currentIndex: Int
    private var lastAppliedIndex: Int?
    private var didLayoutOnce = false
    private var isProgrammaticScroll = false
    private var onPageChange: (Int) -> Void
    private var onUserInteraction: () -> Void
    private var pageBuilder: (QuestionHorizontalPage) -> AnyView
    private var outerPan: UIPanGestureRecognizer?
    private var didAttachOuterPan = false
    private var lastDragTranslation: CGPoint = .zero

    private var collectionView: HorizontalCollectionView!

    init(
        pages: [QuestionHorizontalPage],
        currentIndex: Int,
        outerPan: UIPanGestureRecognizer?,
        onPageChange: @escaping (Int) -> Void,
        onUserInteraction: @escaping () -> Void,
        pageBuilder: @escaping (QuestionHorizontalPage) -> AnyView
    ) {
        self.pages = pages
        self.currentIndex = currentIndex
        self.outerPan = outerPan
        self.onPageChange = onPageChange
        self.onUserInteraction = onUserInteraction
        self.pageBuilder = pageBuilder
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
            scrollToPage(currentIndex, animated: false, programmatic: true)
        }
    }

    func update(
        pages: [QuestionHorizontalPage],
        currentIndex: Int,
        outerPan: UIPanGestureRecognizer?,
        onPageChange: @escaping (Int) -> Void,
        onUserInteraction: @escaping () -> Void,
        pageBuilder: @escaping (QuestionHorizontalPage) -> AnyView
    ) {
        let pagesChanged = pages != self.pages
        self.pages = pages
        self.currentIndex = max(0, min(currentIndex, max(pages.count - 1, 0)))
        self.outerPan = outerPan
        self.onPageChange = onPageChange
        self.onUserInteraction = onUserInteraction
        self.pageBuilder = pageBuilder

        if pagesChanged {
            collectionView.reloadData()
        }
        collectionView.alwaysBounceHorizontal = pages.count > 1
        collectionView.isScrollEnabled = pages.count > 1
        attachOuterPanRequirementIfNeeded()
        applyIndexIfNeeded()
    }
}

// MARK: - Setup

private extension QuestionHorizontalPagingController {
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero

        let collectionView = HorizontalCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = pages.count > 1
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.isDirectionalLockEnabled = true
        collectionView.delaysContentTouches = false
        collectionView.canCancelContentTouches = true
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(QuestionHorizontalPageCell.self, forCellWithReuseIdentifier: QuestionHorizontalPageCell.reuseIdentifier)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.collectionView = collectionView
        attachOuterPanRequirementIfNeeded()
    }

    func updateLayoutIfNeeded() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let size = view.bounds.size
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
        }
    }

    func attachOuterPanRequirementIfNeeded() {
        guard !didAttachOuterPan else { return }
        guard let outerPan else { return }
        outerPan.require(toFail: collectionView.panGestureRecognizer)
        didAttachOuterPan = true
    }
}

// MARK: - Data Source

extension QuestionHorizontalPagingController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: QuestionHorizontalPageCell.reuseIdentifier,
            for: indexPath
        ) as? QuestionHorizontalPageCell else {
            return UICollectionViewCell()
        }

        let page = pages[indexPath.item]
        cell.configure(pageBuilder(page))
        return cell
    }
}

// MARK: - Paging

extension QuestionHorizontalPagingController: UICollectionViewDelegate, UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            lastDragTranslation = .zero
            onUserInteraction()
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollView === collectionView else { return }
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }

        let translation = lastDragTranslation == .zero
            ? collectionView.panGestureRecognizer.translation(in: collectionView)
            : lastDragTranslation
        let minTranslation = pageWidth * 0.06
        let minVelocity: CGFloat = 0.2

        var targetIndex = currentIndex
        let meetsTranslation = abs(translation.x) > minTranslation
        let meetsVelocity = abs(velocity.x) > minVelocity

        if meetsTranslation || meetsVelocity {
            let maxIndex = max(pages.count - 1, 0)
            let direction = meetsTranslation ? translation.x : velocity.x
            if direction > 0 {
                targetIndex = max(currentIndex - 1, 0)
            } else if direction < 0 {
                targetIndex = min(currentIndex + 1, maxIndex)
            }
        }

        targetContentOffset.pointee.x = CGFloat(targetIndex) * pageWidth
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

// MARK: - Helpers

private extension QuestionHorizontalPagingController {
    func applyIndexIfNeeded() {
        guard isViewLoaded else { return }
        guard collectionView.bounds.width > 0 else { return }
        let diff = lastAppliedIndex.map { abs(currentIndex - $0) } ?? 0
        let shouldAnimate = didLayoutOnce && view.window != nil && diff == 1
        if currentIndex != lastAppliedIndex || !didLayoutOnce {
            scrollToPage(currentIndex, animated: shouldAnimate, programmatic: true)
        }
        lastAppliedIndex = currentIndex
    }

    func scrollToPage(_ index: Int, animated: Bool, programmatic: Bool) {
        guard index >= 0, index < pages.count else { return }
        if programmatic {
            isProgrammaticScroll = true
        }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
        if !animated {
            finalizePageChange()
        }
    }

    func finalizePageChange() {
        guard let pageIndex = centeredIndexPath()?.item else { return }
        currentIndex = pageIndex
        onPageChange(pageIndex)
        isProgrammaticScroll = false
    }

    func centeredIndexPath() -> IndexPath? {
        let point = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        return collectionView.indexPathForItem(at: point)
    }
}

private final class QuestionHorizontalPageCell: UICollectionViewCell {
    static let reuseIdentifier = "QuestionHorizontalPageCell"

    private var hostingController: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.rootView = AnyView(EmptyView())
    }

    func configure(_ view: AnyView) {
        ensureHostingController()
        hostingController?.rootView = view
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
