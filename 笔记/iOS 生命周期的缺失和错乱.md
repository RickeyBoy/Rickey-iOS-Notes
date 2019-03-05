# iOS 生命周期的缺失和错乱

不知道大家有没有考虑过一个很奇怪的情况，就是 View Controller 的生命周期没有被调用，或者是调用顺序错乱？其实这在实际操作中经常发生，override 的时候一不小心就忘记调用 super 了，或者明明是 override viewWillAppear()，却调用成了 super.viewWillDisappear()。甚至，一不小心，调用了两次…

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // 写成这样会被骂死吗 =。=
}
```
那么这究竟会发生导致什么问题呢？

我们先简单写一个 demo 方便我们提问（demo 地址：[LifeCycleDemo](https://github.com/RickeyBoy/Rickey-iOS-Notes/tree/master/Demos)，非常简单，自己写一个也行）。就是一个用 Storyboard 新建了一个 ViewController，然后可以跳转到另一个 ViewController。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/图片备份/Blog_Swift_UIViewController/1.png?raw=true)

然后，我们在 ViewController 的每一个生命周期被调用时都打印一下生命周期的名字，就是下面这样：

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/图片备份/Blog_Swift_UIViewController/2.png?raw=true)

好，有了这个 Demo 之后，我们依照这个 Demo 来讨论下面几个问题：

### 1. 如果缺少 loadView() 方法会怎么样？
```swift
override func loadView() {
    // super.loadView()
    print("loadView")
}
```

#### 答案：黑屏
这道题很假单，如果没有 loadView，那就没有加载 view，就是黑屏。

Apple 文档中说，loadView 不能被手动调用，View Controller 会自动在其 View 第一次被获取、并且还是 nil 的时候调用(可以理解为 View 是懒加载的)。如果你要 override 这个方法，那么必须要将你自己的 view hierarchy 中的 root View 设置给 View Controller 的 View 属性。并且这个 View 不能与其他 View Controller 共享，也不能再调用 super 方法了。

### 2. 如果在 loadView() 之前调用 view 会怎么样？
```swift
override func loadView() {
    print(self.view)
    super.loadView()
}
```
#### 答案：infinite stack trace

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/图片备份/Blog_Swift_UIViewController/3.png?raw=true)

可以看出，[UIViewController view] 和 ViewController.loadView 循环调用了。这是因为在 loadView 之前，view 并没有被创建，而由于 view 是懒加载的，此时调用 self.view 会触发 loadView，由此导致了循环引用。

另外，如果我们想要重写 loadView，正确的方式应该类似于这样：
```swift
override func loadView() {
    let myView = MyView()
    view = myView
}
```
实际上，重写 loadView 能达到一些意想不到的效果，推荐一篇文章：[重写 loadView() 方法使 Swift 视图代码更加简洁](https://juejin.im/post/5b68fe5b6fb9a04fd16039c0)

### 3. 如果在 viewWillAppear() 时候手动调用 loadView() 会怎么样？
```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadView()
}
```
#### 答案：ViewController 的 view 被替换
表面上看起来没有任何变化，ViewController 还是能完整地显示出来。但是这个时候如果我们点击 "Presented Controller" 这个按钮，想要跳转到下一个页面，会发现没有响应。同时会发现 Console 中有下面的输出：
```swift
Warning: Attempt to present <LifeCycleDemo.PresentedViewController: 0x7fe4f601def0> on <LifeCycleDemo.ViewController: 0x7fe4f6212e50> whose view is not in the window hierarchy!
```
很明显的，由于我们在手动调用了 loadView 方法，导致 ViewController 中本来的 view 新建了两次。新的 view 替换了原来的 view，导致新 view 的视图层级出错了，于是在进行 present 操作的时候就发生了上述错误。

为了验证一下，我们可以在调用 loadView() 之前和之后分别 `print(self.view!)`，会发现 ViewController 的 view 确实被替换掉了，结果如下：
```swift
loadView
viewDidLoad
<UIView: 0x7fef58c089d0; frame = (0 0; 375 812); autoresize = W+H; layer = <CALayer: 0x60000272b280>>
loadView
<UIView: 0x7fef58c1c220; frame = (0 0; 375 812); autoresize = W+H; layer = <CALayer: 0x60000272ba80>>
viewWillAppear
```
同时我们发现一个有趣的现象，之后的生命周期没有被打印出来了（并不是我没有复制粘贴上来！）。可以合理推断 viewDidAppear 等实际上监听的还是第一个 view 的变化，而由于第一个 view 被换掉之后，之后的生命周期没有被触发，所以也不会打印之后的生命周期。

### 4. 如果在 viewDidLoad() 时候手动调用 loadView() 会怎么样？
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    loadView()
}
```
#### 答案：view 被替换但是可以正常跳转

```swift
loadView
<UIView: 0x7ff917519350; frame = (0 0; 375 812); autoresize = W+H; layer = <CALayer: 0x600000e8bd80>>
loadView
<UIView: 0x7ff91a407a50; frame = (0 0; 375 812); autoresize = W+H; layer = <CALayer: 0x600000ef1120>>
viewDidLoad
viewWillAppear
viewSafeAreaInsetsDidChange
viewWillLayoutSubviews
viewDidLayoutSubviews
viewDidAppear
```
我们输出生命周期之后，发现手动调用 loadView 之后 view 确实被替换了。但是为什么这一次，之后的生命周期就被正常打印出来了，并且再跳转的时候也可以正常跳转呢？

可以推测，底层在将 view 加入到视图层级，并且开始监听 viewWillAppear 等生命周期的时机，是在 viewDidLoad 之后，viewWillAppear 之前的。所以如果在 view 被加入视图层级之前将其替换掉，并不影响它被加入视图层级之中，于是也就可以正常跳转了。

### 5. 如错误调用 viewWillAppear 等方法会怎么样？
```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidDisappear(animated) // 调用错了！
}

override func viewDidDisappear(_ animated: Bool) {
    // super.viewDidDisappear(animated) 忘记调用了
}
```
#### 答案：继承时可能有问题

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/图片备份/Blog_Swift_UIViewController/4.png?raw=true)

根据代码注释描述可以知道，实际上这些方法并没有实际上做什么事情，只是在特定的时间节点，起到一个通知的作用。所以在我们的 demo 里，错误调用、不调用不会有什么实质上的错误。但是由于我们在复杂的项目中会有非常复杂的继承关系，如果中间有一个地方错了，那么很可能影响继承关系中的其他 ViewController。所以还是应该严格准确地调用 super 方法。

那么，如何来保证正确地调用 super 方法呢？在 Objective-C 中，可以使用 `__attribute__((objc_requires_super));` 或者 `NS_REQUIRES_SUPER` 属性(实际功效都是相同的)，比如新建一个 BaseViewController 作为所有类的基类，然后这样写：
```swift
// Objective-C 保证调用 super 方法
@interface BaseViewController : UIViewController

- (void)viewDidLoad __attribute__((objc_requires_super));

- (void)viewWillAppear:(BOOL)animated NS_REQUIRES_SUPER;

@end
```
(参考答案：[Stack Overflow - nhgrif's answer](https://stackoverflow.com/a/21446076))

如果是 swift 呢？目前 swift 没有上面这种代码层面的解决办法，只能借助 [SwiftLint](https://github.com/realm/SwiftLint) 进行静态检查。按照官方文档引入 SwiftLint 后，在 yml 文件中加入下面的描述即可强制检查，override 的时候是否调用响应方法的 super（这也可以用于检查自定义的 class）：

```
// Swift 保证调用 super 方法
overridden_super_call:
  severity: error
  included:
    - "*"
    - viewDidLoad()
    - viewWillAppear()
    - viewDidAppear()
    - viewWillDisappear()
    - viewDidDisappear()
```

### 6. 最后两个小问题

**小问题1**：在当前屏幕上加一个全屏的 window，会触发下面的 ViewController 的 viewWillAppear 等方法吗？

**答案**：不会，这些方法只关注在同一个 view hierarchy 下的变化。同理，锁屏后进入，后台进前台等都不会触发。

**小问题2**：如何判定一个 ViewController 是否可见？

**答案**：[Stack Overflow - progrmr's answer](https://stackoverflow.com/a/2777460)

可以使用 `view.window` 方法来判断，但是需要注意加上 `isViewLoaded`，来防止在 ViewController 的 view 没有被初始化过的时候被调用，而触发它的懒加载。
```swift
if (viewController.isViewLoaded && viewController.view.window) {
    // viewController is visible
}
```
另外，在 iOS 9+，也可以使用下面这个更加简洁的方式：
```swift
if viewController.viewIfLoaded?.window != nil {
    // viewController is visible
}
```

（本文 Github 链接：[RickeyBoy - iOS 生命周期的缺失和错乱](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/笔记/iOS%20生命周期的缺失和错乱.md)）