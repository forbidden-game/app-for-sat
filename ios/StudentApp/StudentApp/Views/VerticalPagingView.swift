import SwiftUI
import UIKit

struct VerticalPagingView<Page: View>: UIViewRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    @Binding var canPageUp: Bool
    @Binding var canPageDown: Bool
    let makePage: (Int) -> Page

    init(
        pageCount: Int,
        currentPage: Binding<Int>,
        canPageUp: Binding<Bool>,
        canPageDown: Binding<Bool>,
        @ViewBuilder makePage: @escaping (Int) -> Page
    ) {
        self.pageCount = pageCount
        self._currentPage = currentPage
        self._canPageUp = canPageUp
        self._canPageDown = canPageDown
        self.makePage = makePage
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> VerticalPagingScrollView {
        let scrollView = VerticalPagingScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = pageCount > 1
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator
        scrollView.pagingDelegate = context.coordinator

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, multiplier: 3)
        ])

        context.coordinator.containerView = container
        context.coordinator.configurePages(in: scrollView, force: true)
        return scrollView
    }

    func updateUIView(_ scrollView: VerticalPagingScrollView, context: Context) {
        context.coordinator.parent = self
        scrollView.pagingDelegate = context.coordinator
        scrollView.alwaysBounceVertical = pageCount > 1
        context.coordinator.configurePages(in: scrollView, force: false)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, VerticalPagingGestureGate {
        var parent: VerticalPagingView
        weak var containerView: UIView?
        var hostingControllers: [UIHostingController<Page>] = []
        var pageIndices: [Int] = []
        var currentIndex: Int = 0
        private var didSetInitialOffset = false

        init(parent: VerticalPagingView) {
            self.parent = parent
            self.currentIndex = max(0, min(parent.currentPage, max(parent.pageCount - 1, 0)))
        }

        var canPageUp: Bool { parent.canPageUp }
        var canPageDown: Bool { parent.canPageDown }

        func configurePages(in scrollView: VerticalPagingScrollView, force: Bool) {
            let total = parent.pageCount
            guard total > 0 else { return }

            let clamped = max(0, min(parent.currentPage, total - 1))
            if clamped != currentIndex {
                currentIndex = clamped
            }

            var shouldForce = force
            if hostingControllers.isEmpty {
                hostingControllers = (0..<3).map { _ in UIHostingController(rootView: parent.makePage(0)) }
                for controller in hostingControllers {
                    controller.view.translatesAutoresizingMaskIntoConstraints = false
                    controller.view.backgroundColor = .clear
                    containerView?.addSubview(controller.view)
                }
                layoutPages(in: scrollView)
                shouldForce = true
            }

            let previous = max(currentIndex - 1, 0)
            let next = min(currentIndex + 1, total - 1)
            let desired = [previous, currentIndex, next]

            if shouldForce || desired != pageIndices {
                pageIndices = desired
                for (index, controller) in hostingControllers.enumerated() {
                    let pageIndex = desired[index]
                    controller.rootView = parent.makePage(pageIndex)
                }
            }

            let pageHeight = scrollView.bounds.height
            if pageHeight > 0 {
                if !didSetInitialOffset || shouldForce {
                    scrollView.setContentOffset(CGPoint(x: 0, y: pageHeight), animated: false)
                    didSetInitialOffset = true
                }
            }
        }

        private func layoutPages(in scrollView: UIScrollView) {
            guard hostingControllers.count == 3, let containerView else { return }
            let views = hostingControllers.map { $0.view! }
            let pageHeight = scrollView.frameLayoutGuide.heightAnchor

            NSLayoutConstraint.activate([
                views[0].topAnchor.constraint(equalTo: containerView.topAnchor),
                views[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                views[0].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                views[0].heightAnchor.constraint(equalTo: pageHeight),

                views[1].topAnchor.constraint(equalTo: views[0].bottomAnchor),
                views[1].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                views[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                views[1].heightAnchor.constraint(equalTo: pageHeight),

                views[2].topAnchor.constraint(equalTo: views[1].bottomAnchor),
                views[2].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                views[2].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                views[2].heightAnchor.constraint(equalTo: pageHeight),
                views[2].bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            finalizePageChange(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                finalizePageChange(scrollView)
            }
        }

        private func finalizePageChange(_ scrollView: UIScrollView) {
            guard let pagingScrollView = scrollView as? VerticalPagingScrollView else { return }
            let pageHeight = pagingScrollView.bounds.height
            guard pageHeight > 0 else { return }
            let position = Int(round(pagingScrollView.contentOffset.y / pageHeight))

            if position == 0 {
                if currentIndex > 0 {
                    currentIndex -= 1
                    if parent.currentPage != currentIndex {
                        parent.currentPage = currentIndex
                    }
                }
            } else if position == 2 {
                if currentIndex + 1 < parent.pageCount {
                    currentIndex += 1
                    if parent.currentPage != currentIndex {
                        parent.currentPage = currentIndex
                    }
                }
            }

            configurePages(in: pagingScrollView, force: false)
            pagingScrollView.setContentOffset(CGPoint(x: 0, y: pageHeight), animated: false)
        }
    }
}

protocol VerticalPagingGestureGate: AnyObject {
    var canPageUp: Bool { get }
    var canPageDown: Bool { get }
}

final class VerticalPagingScrollView: UIScrollView {
    weak var pagingDelegate: VerticalPagingGestureGate?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGestureRecognizer {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
            let velocity = pan.velocity(in: self)
            if abs(velocity.y) <= abs(velocity.x) {
                return false
            }
            if velocity.y > 0 {
                return pagingDelegate?.canPageUp ?? true
            }
            if velocity.y < 0 {
                return pagingDelegate?.canPageDown ?? true
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}
