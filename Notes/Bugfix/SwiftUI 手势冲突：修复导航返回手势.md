# SwiftUI 手势冲突：修复 Navigation 返回手势

## 问题背景

在开发过程中遇到一个体验上的冲突问题，当用户在使用可横向翻页的视图（如 TabView 的 page 样式）时，第一页无法从屏幕边缘滑动返回上一页。返回手势总是被 TabView 的手势拦截，具体表现可以看下面这个 gif 图：

![failure](../../backups/SwiftUIScrollGestureFix/failure.gif)

## 原因分析

#### 为什么会这样？

  1. 手势竞争问题：

    - Navigation Controller：提供边缘滑动返回手势
    - TabView：拥有用于页面切换的横向拖动手势
  2. 优先级冲突：

    - 两个手势都识别横向滑动
    - TabView 的手势先捕获触摸
    - Navigation 手势永远没有机会响应

#### SwiftUI 的局限性

SwiftUI 没有内置的方式来协调这些手势，解决冲突，所以我们必须深入到 UIKit，自行解决冲突。

#### 如何解决

关键点：在第一页时，我们需要两个手势同时激活，但响应不同的方向：
  - 向右滑动（从左边缘） → Navigation 返回手势
  - 向左滑动 → TabView 翻页

当然，这个要实现上述的逻辑，需要通过 UIKit 来进行手势冲突的逻辑处理。



## 解决方案

> 完整实现：[NavigationSwipeBackModifier.swift](../../Code/SwiftUI/NavigationSwipeBackModifier.swift)

#### 步骤 1：识别手势

获取到互相冲突的两个手势：
- **Navigation Gesture**：位于 `UINavigationController.interactivePopGestureRecognizer`
- **Content Gesture**：位于可滚动内容上（如 UIScrollView.panGestureRecognizer）

```swift
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

#### 步骤 2：创建 Coordinator

构建一个实现 `UIGestureRecognizerDelegate` 的 Coordinator，他的职责如下：
  - 存储两个手势
  - 通过 Delegate 回调管理它们的交互
  - 处理生命周期（设置和清理）

```swift
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

#### 步骤 3：启用同时识别 RecognizeSimultaneously

实现 `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`：
  - 当两个手势需要同时工作时返回 true
  - 允许两者检测触摸而不会互相拦截

```swift
public func gestureRecognizer(
    _: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
) -> Bool {
    // Only allow simultaneous recognition with the conflicting gesture we're managing
    return otherGestureRecognizer == conflictingGesture
}
```

#### 步骤 4：添加条件逻辑

实现 `gestureRecognizerShouldBegin(_:)`：
  - 检查当前状态（例如检查是否位于第一页）
  - 只在适当的时候允许 Navigation 手势
  - 在用户应该滚动内容时阻止返回手势

```swift
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

#### 步骤 5：管理生命周期

- 设置：保存原始状态，安装自定义 Delegate
- 清理：恢复原始状态以避免副作用

```swift
public func cleanup() {
    interactivePopGesture?.delegate = originalDelegate
    interactivePopGesture = nil
    originalDelegate = nil
    shouldEnableSwipeBack = nil
    conflictingGesture = nil
}
```

#### 步骤 6：封装为 SwiftUI Modifier

 创建可复用的 ViewModifier：
  - 封装所有 UIKit 复杂性
  - 提供简洁的 SwiftUI API
  - 响应式更新状态

```swift
public extension View {
    func enableNavigationSwipeBack(when condition: @escaping () -> Bool) -> some View {
        modifier(NavigationSwipeBackModifier(shouldEnable: condition))
    }
}
// Usage
.enableNavigationSwipeBack(when: { selectedIndex == 0 })
```



## 实现模式

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



## 使用方法

在任何会阻止 Navigation 返回手势的横向滑动视图上，应用 `enableNavigationSwipeBack` modifier。

#### 基本语法

```swift
.enableNavigationSwipeBack(when: { condition })
```

`when` 闭包用于判断何时应该启用返回手势。它在手势开始时实时计算，确保能响应最新的状态。

#### 示例：分页 TabView

```swift
TabView(selection: $selection) {
    ForEach(items) { item in
        ItemView(item: item)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.enableNavigationSwipeBack(when: { selectedItemIndex == 0 })
```

**注意**：此方案需要 [SwiftUIIntrospect](https://github.com/siteline/swiftui-introspect) 库来访问底层 UIKit 视图。



## 效果

当用户位于第一页时，自动允许边缘滑动返回手势

![success](../../backups/SwiftUIScrollGestureFix/success.gif)
