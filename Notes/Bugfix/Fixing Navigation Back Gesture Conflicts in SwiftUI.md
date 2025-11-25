# Fixing Navigation Back Gesture Conflicts in SwiftUI

## The Problem

Symptom: Users cannot swipe back from the navigation edge when viewing a horizontally pageable view (like TabView with page style) on the first page.

The swipe back gesture will always be blocked by TabView gesture.

<video src="../../backups/SwiftUIScrollGestureFix/failure.mov" controls=""></video>

## Root Cause Analysis

#### Why Does This Happen?

  1. Two Competing Gestures:

    - Navigation Controller: Provides edge swipe-back gesture
    - Paged View: Has horizontal pan gesture for swiping between pages
  2. Priority Conflict:

    - Both gestures recognize horizontal swipes
    - Paged view's gesture captures the touch first
    - Navigation gesture never gets a chance to respond

#### SwiftUI Limitation:

SwiftUI have no built-in way to coordinate these gestures. Must drop down to UIKit's gesture recognizer system.

#### How to Solve This:

The solution uses gesture coordination through UIKit's delegate pattern.

Key insight: On the first page, we need both gestures active but responding to different directions:
  - Swipe right (from left edge) → Navigation back gesture
  - Swipe left → TabView page change



## Solution Approach

> Full implementation: [NavigationSwipeBackModifier.swift](../../Code/SwiftUI/NavigationSwipeBackModifier.swift)

#### Step 1: Identify the Gestures

Find the two conflicting gestures:
- **Navigation gesture**: Lives on `UINavigationController.interactivePopGestureRecognizer`
- **Content gesture**: Lives on the scrollable content (e.g., UIScrollView.panGestureRecognizer)

```swift
// NavigationSwipeBackModifier.swift:129-141
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
```

#### Step 2: Create a Coordinator

Build a coordinator that implements `UIGestureRecognizerDelegate:`
  - Stores references to both gestures
  - Manages their interaction through delegate callbacks
  - Handles lifecycle (setup and cleanup)

```swift
// NavigationSwipeBackModifier.swift:13-29
public final class NavigationSwipeBackCoordinator: NSObject, UIGestureRecognizerDelegate {
    /// Closure that determines whether swipe-back should be enabled
    public var shouldEnableSwipeBack: (() -> Bool)?

    /// The conflicting gesture that should work simultaneously
    public weak var conflictingGesture: UIPanGestureRecognizer?

    private weak var interactivePopGesture: UIGestureRecognizer?
    private weak var originalDelegate: UIGestureRecognizerDelegate?

    public func configure(with gesture: UIGestureRecognizer) {
        guard interactivePopGesture == nil else { return }
        interactivePopGesture = gesture
        originalDelegate = gesture.delegate
        gesture.delegate = self
    }
    // ... cleanup and delegate methods
}
```

#### Step 3: Enable Simultaneous Recognition

Implement `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:):`
  - Return true when both gestures should work together
  - Allows both to detect touches without blocking each other

```swift
// NavigationSwipeBackModifier.swift:53-60
public func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
) -> Bool {
    // Only allow simultaneous recognition with the conflicting gesture we're managing
    return otherGestureRecognizer == conflictingGesture
}
```

#### Step 4: Add Conditional Logic

Implement `gestureRecognizerShouldBegin(_:):`
  - Check current state (e.g., "am I on the first page?")
  - Allow navigation gesture only when appropriate
  - Block when user should scroll content instead

```swift
// NavigationSwipeBackModifier.swift:66-80
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
```

#### Step 5: Manage Lifecycle

- Setup: Save original state, install custom delegate
- Teardown: Restore original state to avoid side effects

```swift
// NavigationSwipeBackModifier.swift:41-48
public func cleanup() {
    interactivePopGesture?.delegate = originalDelegate
    interactivePopGesture = nil
    originalDelegate = nil
    shouldEnableSwipeBack = nil
    conflictingGesture = nil
}
```

#### Step 6: Wrap in SwiftUI Modifier

 Create a reusable ViewModifier:
  - Encapsulates all UIKit complexity
  - Provides clean SwiftUI API
  - Updates state reactively

```swift
// NavigationSwipeBackModifier.swift:168-176
public extension View {
    func enableNavigationSwipeBack(when condition: @escaping () -> Bool) -> some View {
        modifier(NavigationSwipeBackModifier(shouldEnable: condition))
    }
}

// Usage
.enableNavigationSwipeBack(when: { selectedIndex == 0 })
```


## Implementation Pattern

```
  ┌─────────────────────────────────────┐
  │   SwiftUI View                      │
  │   .enableSwipeBack(when: condition) │
  └────────────┬────────────────────────┘
               │
               ▼
  ┌─────────────────────────────────────┐
  │   ViewModifier                      │
  │   - Manages lifecycle               │
  │   - Updates condition reactively    │
  └────────────┬────────────────────────┘
               │
               ▼
  ┌─────────────────────────────────────┐
  │   Gesture Coordinator               │
  │   - Implements delegate callbacks   │
  │   - Coordinates both gestures       │
  │   - Stores original state           │
  └─────────────────────────────────────┘
```



## Usage

Apply the `enableNavigationSwipeBack` modifier to any view with horizontal gestures that block the navigation back gesture.

#### Basic Syntax

```swift
.enableNavigationSwipeBack(when: { condition })
```

The `when` closure determines when the back gesture should be enabled. It's evaluated in real-time when the gesture begins, ensuring it responds to the latest state.

#### Example: Paged TabView

```swift
TabView(selection: $selection) {
    ForEach(items) { item in
        ItemView(item: item)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.enableNavigationSwipeBack(when: { selectedItemIndex == 0 })
```

**Note**: This solution requires [SwiftUIIntrospect](https://github.com/siteline/swiftui-introspect) library to access underlying UIKit views.



## Result

User Experience: Back swipe works naturally on first page, content swiping works everywhere

Code Quality: Reusable component in Core, clean SwiftUI API, no feature-specific coupling

Maintainability: Other teams can use same pattern for similar problems

<video src="../../backups/SwiftUIScrollGestureFix/success.mp4" controls=""></video>

