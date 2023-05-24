# SwiftUI 点击空白处收起键盘

> iOS 14+



当用户输入完毕，通过点击空白处，快捷实现键盘收起；同时也不影响其他正常的交互操作。这个需求的场景应该非常常见，大部分涉及键盘输入的时候，都会需要实现上述的功能。



先回顾一下 UIKit 中隐藏键盘的方法，本质上是需要获取到承载键盘的视图：

```Swift
// 方法一：
textField.resignFirstResponder()

// 方法二：
view.endEditing(true)
```



那么其实对于 SwiftUI 来说，虽然没有之前 View 的概念了，但是同样可以获取到整个 App 的 window，从而调用 endEditing。为了方便，我们直接给 UIApplication 增加 Extension：

```swift
extension UIApplication {
    func addTapGestureRecognizer() {
        guard let window = windows.first else { return }
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        window.addGestureRecognizer(tapGesture)
    }
}
```



需要注意的是，下面两个参数需要配置正确：

- requiresExclusiveTouchType：默认为 true。这个属性是指是否允许多种手势输入，这里的多种包含触摸、遥控器、触控笔等，所以可以配置成 false（当然不配置也不会有太大影响）
- cancelsTouchesInView：默认为 true。这里设置为 false，主要为了不影响其他手势的识别。当前的 tap 手势被识别出来之后，也不会触发 UITouch 的 cancel 方法，因此就不会中断 UITouch 的传递。



当然，为了不影响其他手势的识别，还需要实现下面这个方法：

```swift
extension UIApplication: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // 可以同时响应多个手势
    }
}
```



最后我们只需要在整个 App 初始化时加上手势识别就可以了：

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: UIApplication.shared.addTapGestureRecognizer)
        }
    }
}
```