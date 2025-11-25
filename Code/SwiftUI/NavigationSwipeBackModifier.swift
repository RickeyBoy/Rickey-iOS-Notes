import SwiftUI
import UIKit

/// Coordinates navigation swipe-back gesture with horizontal scrolling gestures.
/// Allows both gestures to work simultaneously by managing UIGestureRecognizerDelegate.
public final class NavigationSwipeBackCoordinator: NSObject, UIGestureRecognizerDelegate {

    // MARK: - Properties

    /// Determines when swipe-back should be enabled
    public var shouldEnableSwipeBack: (() -> Bool)?

    /// The conflicting horizontal pan gesture (e.g., scroll view)
    public weak var conflictingGesture: UIPanGestureRecognizer?

    /// Navigation controller's interactive pop gesture
    private weak var interactivePopGesture: UIGestureRecognizer?

    /// Original delegate to restore on cleanup
    private weak var originalDelegate: UIGestureRecognizerDelegate?

    // MARK: - Lifecycle

    /// Setup coordinator with navigation's interactive pop gesture
    public func configure(with gesture: UIGestureRecognizer) {
        guard interactivePopGesture == nil else { return }
        interactivePopGesture = gesture
        originalDelegate = gesture.delegate
        gesture.delegate = self
    }

    /// Restore original state on cleanup
    public func cleanup() {
        interactivePopGesture?.delegate = originalDelegate
        interactivePopGesture = nil
        originalDelegate = nil
        shouldEnableSwipeBack = nil
        conflictingGesture = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allow simultaneous recognition with conflicting gesture
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return otherGestureRecognizer == conflictingGesture
    }

    /// Enable back gesture only for right swipes when condition is met
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        // Check swipe direction
        let translation = panGesture.translation(in: panGesture.view)
        let velocity = panGesture.velocity(in: panGesture.view)
        let isSwipingRight = translation.x > 0 || velocity.x > 0

        // Only allow back gesture for right swipes
        guard isSwipingRight else { return false }

        // Check app-specific condition (e.g., "am I on the first page?")
        return shouldEnableSwipeBack?() ?? false
    }
}

// MARK: - SwiftUI View Modifier

/// Enables swipe-back gesture in views with horizontal scrolling.
/// Requires SwiftUIIntrospect: https://github.com/siteline/swiftui-introspect
///
/// Example:
/// ```swift
/// TabView(selection: $selection) { ... }
///     .tabViewStyle(.page(indexDisplayMode: .never))
///     .enableNavigationSwipeBack(when: { selectedIndex == 0 })
/// ```
public struct NavigationSwipeBackModifier: ViewModifier {
    let shouldEnable: () -> Bool

    @State private var coordinator = NavigationSwipeBackCoordinator()

    public func body(content: Content) -> some View {
        content
            .introspect(.viewController, on: .iOS(.v16, .v17, .v18)) { viewController in
                guard let navigationController = viewController.navigationController,
                      let interactivePopGesture = navigationController.interactivePopGestureRecognizer else {
                    return
                }
                coordinator.configure(with: interactivePopGesture)
            }
            .introspect(.scrollView, on: .iOS(.v16, .v17, .v18)) { scrollView in
                coordinator.conflictingGesture = scrollView.panGestureRecognizer
            }
            .onAppear {
                coordinator.shouldEnableSwipeBack = shouldEnable
            }
            .onDisappear {
                coordinator.cleanup()
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Enables conditional swipe-back navigation.
    ///
    /// - Parameter when: Closure evaluated when gesture begins
    /// - Returns: Modified view with swipe-back support
    func enableNavigationSwipeBack(when condition: @escaping () -> Bool) -> some View {
        modifier(NavigationSwipeBackModifier(shouldEnable: condition))
    }
}
