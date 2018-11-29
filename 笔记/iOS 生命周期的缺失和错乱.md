# ViewController 生命周期相关的小问题



### 主要思路

（可以给一个小 demo）
- viewController 自身
  - 职责
  - 继承
  - (属性)
  - 遵循的协议
- viewcontroller 生命周期
  - 每个生命周期的职责
  - 初始化时、present、push 等时生命周期的状态转换
  - nib、storyboard、programmatically 的区别
  - 如果某个生命周期缺失会怎么样？
  - 如果某个生命周期执行多次、或者颠倒了会怎么样？
- 初始化
  - 有几种方法？
  - 相互比较
  - 最佳实践
  - 在 init 的时候传参数和 init 之后传参数有什么不同？
  - swift 中新建到底应该用 ! ？ 还是直接新建一个实例，或者用 lazy？
- 布局
  - 初始化布局的最佳时机
  - 刷新布局的最佳时机
  - ViewController 底层如何进行布局计算
  - 针对布局可以怎么进行优化？
- 交互
  - 如何响应交互



## UIViewController 基本信息



> An object that manages a view hierarchy for your UIKit app.

### 1. 主要职责：
- 更新内部 Views 的内容
- 相应内部 Views 上的用户交互
- 布置内部 Views 的位置
- 与 App 內其他 Object 协作，包括其他 ViewController

### 2. 继承关系

NSObject -> UIResponder -> UIViewController

### 3. 遵循的协议
CVarArg
Equatable
Hashable
**NSCoding**
NSExtensionRequestHandling
UIAppearanceContainer
UIContentContainer
UIFocusEnvironment
UIPasteConfigurationSupporting
UIStateRestoring
UITraitEnvironment
UIUserActivityRestoring



## UIViewController 的生命周期


### 1. 生命周期的相关方法

根据 Apple 的官方文档，View Controller 的生命周期实际上可以分为三个部分：管理自身的 View、 响应 View 的事件和配置 View 的 Layout。这其实是和它的职责高度相关，其实就是 ViewController 中除了响应交互的部分。

管理自身的 View 涉及到的生命周期：

- loadView：创建 View Controller 管理的 View
- viewDidLoad：View 已经在内存中加载完成

响应 View 的事件，参照下方的图，相关生命周期一共有四个：

- viewWillAppear(Bool)：View Controller 马上要被加入到视图层级之中了
- viewDidAppear(Bool)：View Controller 已经被加入到视图层级之中了
- viewWillDisappear(Bool)：View Controller 马上要被从视图层级之中移除了
- viewDidDisappear(Bool)：View Controller 已经从视图层级中移除了

<img src="/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/图片备份/Blog_Swift_UIViewController/UIViewController_Valid_State_Transistions.png" width="400px" />

配置 View 的 Layout 时涉及到生命周期：

- viewWillLayoutSubviews：View Controller 的 view 马上要布局其子 view 了
- viewDidLayoutSubviews：View Controller 的 view 已经把子 view 布局好了
- updateViewConstraints：View Controller 的 view 需要 update 其约束

### 2. 初始化的生命周期

说完了生命周期相关的所有方法，他们被调用的顺序是怎样的呢？我们可以直接来做个实验。结果如下：

1. loadView
2. viewDidLoad
3. viewWillAppear
4. viewWillLayoutSubviews
5. viewDidLayoutSubviews
6. viewDidAppear

根据 console 的输出结果，在初始化一个 View Controller 的时候，执行顺序如上图所示。其实很好理解，View Controller 的生命周期，实际上就是对他的 View 的整个操作流程：创建 View，创建完成之后开始显示 View，并且布局所有的 subviews。

### 3. 跳转的生命周期

那么，如果是从一个 View Controller 跳转到另一个 View Controller 呢？再来做个实验：

1. Presented -- loadView
2. Presented -- viewDidLoad
3. viewWillDisappear
4. Presented -- viewWillAppear
5. Presented -- viewWillLayoutSubviews
6. Presented -- viewDidLayoutSubviews
7. Presented -- viewDidAppear
8. viewDidDisappear

之后再回退到第一个 View Controller，输出结果如下：

1. Presented -- viewWillDisappear
2. viewWillAppear
3. viewDidAppear
4. Presented -- viewDidDisappear

可以看到，在新进入一个页面的时候，总是第一个页面先调用 viewWillDisappear 的方法，然后最后调用 viewDidDisappear。然后如果新的页面是第一次进入，那么就会触发 load 的 layoutSubviews 的相关通知。

### 4. 生命周期的缺失和错乱

不知道大家有没有考虑过一个很奇怪的情况，就是 View Controller 的生命周期没有被调用，或者是调用顺序错乱？其实这在实际操作中经常发生，override 的时候一不小心就忘记调用 super 了，或者明明是 override viewWillAppear()，却调用成了 super.viewWillDisappear()。甚至，一不小心，调用了两次...

那么这究竟会发生什么现象呢？让我们分开进行讨论。

**loadView**：首先来说说 loadView()，[Apple 文档](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621454-loadview)中说，loadView 不能被手动调用，View Controller 会自动在其 View 第一次被获取、并且还是 nil 的时候调用(可以理解为 View 是懒加载的)。如果你要 override 这个方法，那么必须要将你自己的 view hierarchy 中的 root View 设置给 View Controller 的 View 属性。并且这个 View 不能与其他 View Controller 共享，也不能再调用 super 方法了。

如果想要手动 override loadView 方法，大概会长成这个样子：

```swift
final class MyViewController: UIViewController {
	override func loadView() {
	    let myView = MyView()
	    myView.delegate = self
        view = myView
    }
    override func viewDidLoad() {
        super.viewDidLoad()
		print(view) // 一个 MyView 的实例
	}
}
```

这样重写 loadView 可以替换掉 View Controller 自身的 View，从而达到使得视图代码逻辑更加易于理解、易于维护的目的。推荐这样一篇文章：[[译] 重写 loadView() 方法使 Swift 视图代码更加简洁
](https://juejin.im/post/5b68fe5b6fb9a04fd16039c0)

聊了这么多，那么可以很明显的知道，loadView 是有其具体操作的，就是负责加载 View Controller 的 View，那么如果忘记调用其 super 方法，就加载不了根视图，那么所有的 subviews 也都无法被加载了。注释掉 super 方法，View Controller 会全黑。

**viewDidLoad**：View 已经在内存中加载完成之后被调用。



### 5. 





---


### 参考资料

1. [Apple Developer - UIViewController](https://developer.apple.com/documentation/uikit/uiviewcontroller)
2. [View Controller Programming Guide for iOS]https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/index.html#//apple_ref/doc/uid/TP40007457

