import SwiftUI
import UIKit

/// Coordinator that manages swipe-back gesture conflicts between navigation and scrollable content.
///
/// This coordinator enables the navigation controller's interactive back gesture to work
/// alongside horizontal pan gestures (like scroll views or paged views) by implementing
/// UIKit's gesture recognizer delegate pattern.
///
/// Key responsibilities:
/// - Allows simultaneous gesture recognition
/// - Determines when back gesture should activate based on swipe direction
/// - Conditionally enables back gesture based on app state
public final class NavigationSwipeBackCoordinator: NSObject, UIGestureRecognizerDelegate {

    // MARK: - Properties

    /// Closure that determines whether swipe-back should be enabled.
    /// Called when gesture begins to decide if navigation back should be allowed.
    public var shouldEnableSwipeBack: (() -> Bool)?

    /// The horizontal pan gesture that conflicts with navigation (e.g., scroll view's pan gesture).
    /// Both gestures will be allowed to recognize simultaneously.
    public weak var conflictingGesture: UIPanGestureRecognizer?

    /// Reference to the navigation controller's interactive pop gesture
    private weak var interactivePopGesture: UIGestureRecognizer?

    /// The original delegate of the interactive pop gesture (to restore on cleanup)
    private weak var originalDelegate: UIGestureRecognizerDelegate?

    // MARK: - Lifecycle

    /// Configure the coordinator with the navigation's interactive pop gesture.
    /// Saves the original delegate and installs self as the new delegate.
    ///
    /// - Parameter gesture: The navigation controller's interactivePopGestureRecognizer
    public func configure(with gesture: UIGestureRecognizer) {
        guard interactivePopGesture == nil else { return }
        interactivePopGesture = gesture
        originalDelegate = gesture.delegate
        gesture.delegate = self
    }

    /// Cleanup and restore original state.
    /// Should be called when the view disappears to avoid side effects.
    public func cleanup() {
        interactivePopGesture?.delegate = originalDelegate
        interactivePopGesture = nil
        originalDelegate = nil
        shouldEnableSwipeBack = nil
        conflictingGesture = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allow both navigation gesture and content gesture to recognize simultaneously.
    /// This prevents one gesture from blocking the other.
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Only allow simultaneous recognition with the conflicting gesture we're managing
        return otherGestureRecognizer == conflictingGesture
    }

    /// Determine if the navigation back gesture should begin.
    /// Checks:
    /// 1. Is this a right swipe (from left edge)?
    /// 2. Does the app state allow back navigation (via shouldEnableSwipeBack closure)?
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

/// View modifier that enables swipe-back gesture in views with horizontal gestures.
///
/// Use this when you have a view with horizontal scrolling/swiping that blocks
/// the navigation back gesture. Common scenarios:
/// - Paged TabViews
/// - Horizontal scroll views
/// - Custom swipeable content
///
/// The modifier uses SwiftUIIntrospect library to access underlying UIKit views.
/// Make sure to add SwiftUIIntrospect to your project:
/// https://github.com/siteline/swiftui-introspect
///
/// Example with paged TabView:
/// ```swift
/// TabView(selection: $selection) {
///     ForEach(items) { item in
///         ItemView(item: item)
///     }
/// }
/// .tabViewStyle(.page(indexDisplayMode: .never))
/// .enableNavigationSwipeBack(when: { selectedIndex == 0 })
/// ```
public struct NavigationSwipeBackModifier: ViewModifier {
    let shouldEnable: () -> Bool

    @State private var coordinator = NavigationSwipeBackCoordinator()

    public func body(content: Content) -> some View {
        content
            // Access the view controller to get navigation controller
            .introspect(.viewController, on: .iOS(.v16, .v17, .v18)) { viewController in
                guard let navigationController = viewController.navigationController,
                      let interactivePopGesture = navigationController.interactivePopGestureRecognizer else {
                    return
                }
                coordinator.configure(with: interactivePopGesture)
            }
            // Access the scroll view to get its pan gesture recognizer
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
    /// Enables swipe-back navigation gesture for views with horizontal gestures.
    ///
    /// This modifier resolves conflicts between the navigation controller's back gesture
    /// and horizontal scrolling/swiping gestures. The back gesture only works when the
    /// condition evaluates to true (e.g., when at the start of scrollable content).
    ///
    /// The condition is evaluated in real-time when the gesture begins, allowing it to
    /// respond to the latest state even during animations.
    ///
    /// - Parameter when: Closure that determines when swipe-back should be enabled
    /// - Returns: A view that supports conditional swipe-back gesture
    ///
    /// Example:
    /// ```swift
    /// .enableNavigationSwipeBack(when: { isAtFirstPage })
    /// ```
    func enableNavigationSwipeBack(when condition: @escaping () -> Bool) -> some View {
        modifier(NavigationSwipeBackModifier(shouldEnable: condition))
    }
}
