import SwiftUI
import UIKit

struct VerticalPagingView<Page: View>: UIViewRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    @Binding var canPageUp: Bool
    @Binding var canPageDown: Bool
    let onMoveBeyondEnd: (() -> Void)?
    let makePage: (Int) -> Page

    init(
        pageCount: Int,
        currentPage: Binding<Int>,
        canPageUp: Binding<Bool>,
        canPageDown: Binding<Bool>,
        onMoveBeyondEnd: (() -> Void)? = nil,
        @ViewBuilder makePage: @escaping (Int) -> Page
    ) {
        self.pageCount = pageCount
        self._currentPage = currentPage
        self._canPageUp = canPageUp
        self._canPageDown = canPageDown
        self.onMoveBeyondEnd = onMoveBeyondEnd
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
        context.coordinator.slotViews = context.coordinator.buildSlots(in: scrollView, container: container)
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
        var slotViews: [UIView] = []
        var hostingControllers: [UIHostingController<Page>] = []
        private var viewConstraints: [ObjectIdentifier: [NSLayoutConstraint]] = [:]
        var pageIndices: [Int] = []
        var currentIndex: Int = 0
        private var didSetInitialOffset = false
        private var lastRefreshedPage: Int = -1

        init(parent: VerticalPagingView) {
            self.parent = parent
            self.currentIndex = max(0, min(parent.currentPage, max(parent.pageCount - 1, 0)))
        }

        var canPageUp: Bool { parent.canPageUp }
        var canPageDown: Bool { parent.canPageDown }

        func buildSlots(in scrollView: UIScrollView, container: UIView) -> [UIView] {
            let slots = (0..<3).map { _ in UIView() }
            slots.forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
                $0.backgroundColor = .clear
                container.addSubview($0)
            }

            let pageHeight = scrollView.frameLayoutGuide.heightAnchor
            NSLayoutConstraint.activate([
                slots[0].topAnchor.constraint(equalTo: container.topAnchor),
                slots[0].leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slots[0].trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slots[0].heightAnchor.constraint(equalTo: pageHeight),

                slots[1].topAnchor.constraint(equalTo: slots[0].bottomAnchor),
                slots[1].leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slots[1].trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slots[1].heightAnchor.constraint(equalTo: pageHeight),

                slots[2].topAnchor.constraint(equalTo: slots[1].bottomAnchor),
                slots[2].leadingAnchor.constraint(equalTo: container.leadingAnchor),
                slots[2].trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slots[2].heightAnchor.constraint(equalTo: pageHeight),
                slots[2].bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return slots
        }

        func configurePages(in scrollView: VerticalPagingScrollView, force: Bool) {
            let total = parent.pageCount
            guard total > 0 else { return }

            let clamped = max(0, min(parent.currentPage, total - 1))
            let currentChanged = clamped != currentIndex
            if currentChanged {
                currentIndex = clamped
            }

            var shouldForce = force
            if hostingControllers.isEmpty {
                guard slotViews.count == 3 else { return }
                hostingControllers = (0..<3).map { _ in UIHostingController(rootView: parent.makePage(0)) }
                for (index, controller) in hostingControllers.enumerated() {
                    controller.view.backgroundColor = .clear
                    attach(controller, to: slotViews[index])
                }
                shouldForce = true
            }

            let desired = desiredIndices(for: currentIndex, total: total)

            if shouldForce || pageIndices.isEmpty || currentChanged {
                applyIndices(desired, updateAll: true)
            } else if desired != pageIndices {
                applyIndices(desired, updateAll: false)
            }

            let pageHeight = scrollView.bounds.height
            if pageHeight > 0 {
                if !didSetInitialOffset || shouldForce {
                    scrollView.setContentOffset(CGPoint(x: 0, y: pageHeight), animated: false)
                    didSetInitialOffset = true
                }
            }

            refreshPagesIfNeeded()
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
                moveToPrevious(in: pagingScrollView)
            } else if position == 2 {
                moveToNext(in: pagingScrollView)
            } else {
                recenter(pagingScrollView)
            }
        }

        private func moveToNext(in scrollView: VerticalPagingScrollView) {
            guard currentIndex + 1 < parent.pageCount else {
                parent.onMoveBeyondEnd?()
                recenter(scrollView)
                return
            }
            currentIndex += 1
            if parent.currentPage != currentIndex {
                parent.currentPage = currentIndex
            }
            rotateForNext()
            let desired = desiredIndices(for: currentIndex, total: parent.pageCount)
            applyIndices(desired, updateAll: false)
            refreshPagesIfNeeded()
            recenter(scrollView)
        }

        private func moveToPrevious(in scrollView: VerticalPagingScrollView) {
            guard currentIndex > 0 else {
                recenter(scrollView)
                return
            }
            currentIndex -= 1
            if parent.currentPage != currentIndex {
                parent.currentPage = currentIndex
            }
            rotateForPrevious()
            let desired = desiredIndices(for: currentIndex, total: parent.pageCount)
            applyIndices(desired, updateAll: false)
            refreshPagesIfNeeded()
            recenter(scrollView)
        }

        private func recenter(_ scrollView: UIScrollView) {
            let pageHeight = scrollView.bounds.height
            guard pageHeight > 0 else { return }
            scrollView.setContentOffset(CGPoint(x: 0, y: pageHeight), animated: false)
        }

        private func desiredIndices(for current: Int, total: Int) -> [Int] {
            let previous = max(current - 1, 0)
            let next = min(current + 1, total - 1)
            return [previous, current, next]
        }

        private func applyIndices(_ desired: [Int], updateAll: Bool) {
            if pageIndices.count != 3 {
                pageIndices = desired
                for (index, controller) in hostingControllers.enumerated() {
                    controller.rootView = parent.makePage(desired[index])
                }
                return
            }
            for (index, controller) in hostingControllers.enumerated() {
                if updateAll || pageIndices[index] != desired[index] {
                    pageIndices[index] = desired[index]
                    controller.rootView = parent.makePage(desired[index])
                }
            }
        }

        private func rotateForNext() {
            guard hostingControllers.count == 3, slotViews.count == 3, pageIndices.count == 3 else { return }
            let top = hostingControllers[0]
            let middle = hostingControllers[1]
            let bottom = hostingControllers[2]
            hostingControllers = [middle, bottom, top]

            let topIndex = pageIndices[0]
            let middleIndex = pageIndices[1]
            let bottomIndex = pageIndices[2]
            pageIndices = [middleIndex, bottomIndex, topIndex]

            reattachControllers()
        }

        private func rotateForPrevious() {
            guard hostingControllers.count == 3, slotViews.count == 3, pageIndices.count == 3 else { return }
            let top = hostingControllers[0]
            let middle = hostingControllers[1]
            let bottom = hostingControllers[2]
            hostingControllers = [bottom, top, middle]

            let topIndex = pageIndices[0]
            let middleIndex = pageIndices[1]
            let bottomIndex = pageIndices[2]
            pageIndices = [bottomIndex, topIndex, middleIndex]

            reattachControllers()
        }

        private func reattachControllers() {
            UIView.performWithoutAnimation {
                for (index, controller) in hostingControllers.enumerated() {
                    attach(controller, to: slotViews[index])
                }
            }
        }

        private func attach(_ controller: UIHostingController<Page>, to slot: UIView) {
            let view = controller.view!
            if let constraints = viewConstraints[ObjectIdentifier(view)] {
                NSLayoutConstraint.deactivate(constraints)
            }
            view.removeFromSuperview()
            slot.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            let constraints = [
                view.topAnchor.constraint(equalTo: slot.topAnchor),
                view.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: slot.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            viewConstraints[ObjectIdentifier(view)] = constraints
        }

        private func refreshPagesIfNeeded() {
            guard parent.currentPage != lastRefreshedPage else { return }
            lastRefreshedPage = parent.currentPage
            guard hostingControllers.count == 3, pageIndices.count == 3 else { return }
            for (index, controller) in hostingControllers.enumerated() {
                controller.rootView = parent.makePage(pageIndices[index])
            }
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
