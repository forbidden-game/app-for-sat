import SwiftUI
import UIKit

struct PagingScrollView<Page: View>: UIViewRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    let makePage: (Int) -> Page

    init(
        pageCount: Int,
        currentPage: Binding<Int>,
        @ViewBuilder makePage: @escaping (Int) -> Page
    ) {
        self.pageCount = pageCount
        self._currentPage = currentPage
        self.makePage = makePage
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPage: $currentPage)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = pageCount > 1
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .interactive
        scrollView.delegate = context.coordinator

        context.coordinator.scrollView = scrollView
        context.coordinator.startKeyboardObservers()

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        context.coordinator.stackView = stackView
        rebuildPages(in: scrollView, context: context)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if context.coordinator.pageCount != pageCount {
            rebuildPages(in: scrollView, context: context)
        } else {
            updatePages(context: context)
        }

        let clampedPage = max(0, min(currentPage, max(pageCount - 1, 0)))
        let targetOffset = CGPoint(x: CGFloat(clampedPage) * scrollView.bounds.width, y: 0)
        if scrollView.bounds.width > 0, scrollView.contentOffset != targetOffset {
            context.coordinator.isProgrammaticScroll = true
            scrollView.setContentOffset(targetOffset, animated: true)
        }
    }

    private func rebuildPages(in scrollView: UIScrollView, context: Context) {
        guard let stackView = context.coordinator.stackView else { return }

        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        context.coordinator.hostingControllers.removeAll()

        for index in 0..<pageCount {
            let controller = UIHostingController(rootView: makePage(index))
            controller.view.backgroundColor = .clear
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(controller.view)

            controller.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
            context.coordinator.hostingControllers.append(controller)
        }

        context.coordinator.pageCount = pageCount
    }

    private func updatePages(context: Context) {
        for (index, controller) in context.coordinator.hostingControllers.enumerated() {
            controller.rootView = makePage(index)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var pageCount: Int = 0
        var hostingControllers: [UIHostingController<Page>] = []
        var stackView: UIStackView?
        weak var scrollView: UIScrollView?
        var isProgrammaticScroll = false
        private var currentPage: Binding<Int>
        private var keyboardObservers: [NSObjectProtocol] = []

        init(currentPage: Binding<Int>) {
            self.currentPage = currentPage
        }

        deinit {
            stopKeyboardObservers()
        }

        func startKeyboardObservers() {
            guard keyboardObservers.isEmpty else { return }
            let center = NotificationCenter.default
            let willChange = center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.snapToCurrentPage()
            }
            let willHide = center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.snapToCurrentPage()
            }
            keyboardObservers = [willChange, willHide]
        }

        func stopKeyboardObservers() {
            let center = NotificationCenter.default
            for token in keyboardObservers {
                center.removeObserver(token)
            }
            keyboardObservers.removeAll()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateCurrentPage(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateCurrentPage(scrollView)
            }
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            isProgrammaticScroll = false
        }

        private func snapToCurrentPage() {
            guard let scrollView, scrollView.bounds.width > 0 else { return }
            let clampedPage = max(0, min(currentPage.wrappedValue, max(pageCount - 1, 0)))
            let targetOffset = CGPoint(x: CGFloat(clampedPage) * scrollView.bounds.width, y: 0)
            if scrollView.contentOffset != targetOffset {
                scrollView.setContentOffset(targetOffset, animated: false)
            }
        }

        private func updateCurrentPage(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll, scrollView.bounds.width > 0 else { return }
            let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
            if currentPage.wrappedValue != page {
                currentPage.wrappedValue = page
            }
        }
    }
}
