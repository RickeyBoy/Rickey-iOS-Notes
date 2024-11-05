# 从零到一开发贪吃蛇游戏 Build an iOS Application from Scratch 1





## 目标

一个贪吃蛇游戏！

![shot_2424](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2424.png)



## 提前声明

### 你可以学到的

假设你已经是一个有一些基础的 iOS 开发者

最重要：开发软件所需要的思路

其次：

- iOS 软件开发的一些基础知识
- Swift 语言基础知识

如果你能自己尝试重写一遍这个项目，并且对照代码进行学习，你将会学习到：

- Swift 语言的一些高阶语法和妙用
- 架构上的一些精巧设计

### 代码地址

因为时间有限，我不会一步一步讲解如何实现，而会基于写好的代码，提供写代码的思路和步骤。然后在每一部分中挑选一些有价值的内容进行深入一些的讲解。

代码可以在这个地址找到：【TODO： 地址】



## 前期构思

### 功能拆分

UI 部分：

1. 顶部当前游戏状态展示
2. 中间红色方框内的游戏区域
   1. 地图（隐形方格）
   2. 贪吃蛇本身
   3. 食物

逻辑部分：

1. 贪吃蛇在棋盘内能够自由移动
2. 吃到食物后的表现：产生新的食物、蛇边长等
3. 游戏结束的判定：撞墙、撞到自己等

操作部分：

1. 通过滑动手势操作蛇的转向
2. 单机手势暂停、恢复



### 代码架构的设计

先设计一下需要的模块，以及他们对应的职责

首先拆分 UI 部分，初步看起来需要至少两个 View

1. 一个 UILabel，来展示顶部的信息（命名为 LogView）
2. 一个 View 用于展示中间的游戏区域（命名为 GameView）



然后对应的逻辑部分，我们可以单独使用一个 Class 来专门处理逻辑（命名为 LogicModel）

他具体负责的内容就对应上面的功能拆分中的逻辑部分



最后还需要有一个 ViewController 作为核心控制器，整合所有的组件。手势的添加也可以放到这个 ViewController 当中。



【TODO： 一个结构图】



## 第一步：架构搭建

具体怎么创建项目我就不再赘述了，这里提供一张最终的项目结构截图

我们重点关注这三部分

- ViewController：核心控制类
- Layout：存放 UI 相关的文件
- Logic：逻辑控制类文件

另外两个部分是：

- Const：预先定义的一些状态
- Extension：有助于简化代码的拓展函数

![shot_2426](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2426.png)



### 知识点：引入第三方库的三种方法

引入好用的第三方库是必须要学会的技能。通常我们会有几种引入方式，分别是 CocoaPods、Carthage 和 Swift Package Manager

1. **CocoaPods**：
   - CocoaPods 是一个流行的依赖管理工具，专为 Swift 和 Objective-C 项目设计。
   - 它使用一个名为 `Podfile` 的文件来定义项目依赖，并通过 `pod install` 命令安装依赖。
   - CocoaPods 拥有一个庞大的开源库社区，易于搜索和集成第三方库。
2. **Carthage**：
   - Carthage 允许开发者在不使用 Xcode 项目的方式下引入框架。
   - 它通过 `Cartfile` 来管理依赖，使用 `carthage update` 命令来获取和构建依赖。
   - Carthage 不修改 Xcode 项目文件，因此与 CocoaPods 相比，它提供了更多的灵活性，但集成到项目中的流程可能更复杂。
3. **Swift Package Manager (SPM)**：
   - SPM 是 Swift 的原生包管理器，集成在 Xcode 中，无需额外安装。
   - 它使用 `Package.swift` 文件来定义和管理依赖，支持 Swift 项目的依赖和模块化。
   - SPM 支持跨平台的 Swift 项目，是苹果官方推荐的依赖管理方式。

总而言之，大型公司和项目都会使用 CocoaPods 进行三方库的管理，而小型项目可以使用 SPM，SPM 和 CocoaPods 也可以结合使用，互相不冲突。

### 知识点：SnapKit 的介绍和引入

我们本次要引入的是 SnapKit（https://github.com/SnapKit/SnapKit）SnapKit 是一个 Swift 语言的自动布局框架，他有不少优点：

1. 简洁的语法：简化 Auto Layout 的代码编写 —— 如果你用过最基础的基于 frame 布局进行的开发，就知道 SnapKit 会有多好用了
2. 强类型：减少运行时错误，提升代码质量
3. 链式调用：提高代码的可读性和易用性
4. 兼容性：支持 iOS、tvOS、macOS 和 watchOS

上述三种引入方式他都是支持的。为了方便我们直接使用 Swift Package Manager 进行引入。具体步骤如下：

1. 打开 Xcode 项目。
2. 选择项目文件，点击 "File" -> "Swift Packages" -> "Add Package Dependency"
3. 输入 SnapKit 的 Git 仓库地址：`https://github.com/SnapKit/SnapKit.git`
4. 选择所需的版本，然后点击 "Next"
5. 确认依赖信息，点击 "Add Package"

![shot_2414](/Users/timo.wang/Pictures/SnapNDrag Library.snapndraglibrary/113a029c28-4e/shot_2414.png)



## 第二步：写 UI 相关的代码

### 步骤 1：UI 代码框架搭建

接下来我们先写 UI 相关的代码，也就是 Layout 文件夹中的部分

![shot_2427](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2427.png)

最终会需要新建这么三个文件：

- GameView：游戏区域
- UnitView：游戏区域中每个单位小格子
- LogView：上方的信息展示区域

用最终的截图来展示的话就能很一目了然了：

![shot_2428](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2428.png)

### 步骤 2：详细讲解 UnitView

对于每一个小方格而言，核心会有两个属性。

首先会必须要有一个坐标的概念，代表他所处的具体的位置。

其次，一个小格子一共有四种展示情况，这四种情况分别展示不同的图片样式：

1. 蛇头：展示绿色菱形
2. 蛇身：展示绿色圆形
3. 食物：展示星星
4. 空白格子：不展示任何图片

这里我们根据需要，可以判断样式需要使用 enum

```swift
/// UnitView 类型
enum UnitViewType {
    case snakeHead /// 蛇头
    case snakeBody /// 蛇身
    case food /// 食物
    case normal /// 空白格子
}
```

而坐标需要使用使用 struct 来定义：

```swift
/// 坐标
struct Pos {
    var x: Int
    var y: Int
}
```

所以 UnitView 的情况是（简化版）：

![shot_2429](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2429.png)

### 知识点：Swift 中的结构体和枚举

在 Swift 中，除了我们最熟悉的 Class 之外，struct 和 enum 这两种类型也经常被使用：

- **struct (结构体)**：用于定义自定义数据类型，可以包含多个属性和方法。结构体是引用类型。
- **enum (枚举)**：用于定义一个有固定数量的常量集合，可以有原始值，也可以关联值。枚举可以定义方法。

| 特性   | struct         | enum                                         |
| ------ | -------------- | -------------------------------------------- |
| 类型   | 自定义数据类型 | 固定数量的常量集合                           |
| 存储   | 引用类型       | 值类型（默认）或引用类型（如果定义为 class） |
| 属性   | 可以有多个属性 | 通常没有属性，但可以扩展                     |
| 方法   | 可以定义方法   | 可以定义方法                                 |
| 原始值 | 不适用         | 可以有，用于存储额外信息                     |
| 关联值 | 不适用         | 可以有，每个枚举案例可以关联不同的数据类型   |
| 继承   | 不能被继承     | 不能被继承                                   |
| 构造器 | 可以有构造器   | 可以有构造器                                 |

请注意，Swift 中的 `enum` 可以非常强大，可以拥有方法、原始值和关联值，使它们在某些情况下可以替代 `struct`。然而，`struct` 由于是引用类型，通常用于定义更复杂的数据结构。



### 知识点：直接给 enum 增加方法来简化代码

通过给 Enum 增加方法简化代码。比如针对 UnitViewType，我们可以增加一个方法根据类型获取对应展示的图片，头部展示菱形、身体展示圆形等：

![shot_2448](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2448.png)

这样在使用的时候就能直接调用了，不用再关心具体的逻辑：

![shot_2449](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2449.png)



### 知识点：通过 \#imageLiteral 在代码中引用图片

在 Swift 中，图片可以直接展示在代码中，这样非常的简洁清晰

![shot_2450](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2450.png)

那么要如何触发呢，我们如何实现这样的效果呢？其实注释掉这段代码就发现秘密了，需要使用 \#imageLiteral 关键字：

![shot_2451](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2451.png)





### 步骤 3：完善 GameView

具体的过程，可以下载项目之后看具体的注释。可以稍微看一下下图的构造，可以看到第一个标记点，整个棋盘中的元素都是基于刚才写的 UnitView 基本单元格。

另外读代码的时候可以根据第二个标记点开始读，在这里会依次初始化棋盘、蛇、食物。

![shot_2431](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2431.png)



### 知识点：Swift 中的权限管理

在 Swift 中，一共有这样几种访问权限：

| 访问级别      | 定义     | 访问范围       |
| ------------- | -------- | -------------- |
| `public`      | 公开     | 跨模块访问     |
| `internal`    | 内部     | 模块内访问     |
| `private`     | 私有     | 源文件内访问   |
| `fileprivate` | 文件私有 | 定义文件内访问 |

可以注意到，在上面的文件中，部分地方我使用了 public，部分地方我用了 private，这是因为内部的方法我不希望给其他 Class 调用。

那么我们为什么要进行权限控制呢？权限控制的主要目的是为了封装和安全性：

- **封装**：隐藏实现细节，只暴露必要的接口，使得代码更易于维护和理解。
- **安全性**：限制对敏感数据和功能的访问，防止意外或恶意的修改。
- **模块化**：促进代码的模块化，每个模块只关注其内部的职责，降低模块间的耦合。



### 知识点：注释的技巧

可以看到我在代码中使用了`// MARK: -` 标记，这是一种非常好用的注释方式：

1. **组织代码**：通过添加 `// MARK: -` 来标记代码的不同部分，使得代码结构更加清晰，便于阅读和维护。
2. **导航辅助**：许多代码编辑器和 IDE 会使用这些标记来提供更好的导航功能，允许开发者快速跳转到特定的代码段。
3. **文档生成**：在生成文档时，`// MARK: -` 可以帮助文档工具组织和分类内容。

比如这里的导航辅助，我们点击文件上方导航栏：

![shot_2440](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2440.png)

就可以看到使用 `// MARK: -` 标记的部分：

![shot_2438](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2438.png)

类似的方法还有：

- **`// TODO:`** 标记遗留的 todo
- **`// FIXME:`** 标记需要修复的错误

效果如下图：

![shot_2452](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2452.png)



### 步骤 4：在 ViewController 中放置这一系列 UI

这一步的流程还是很简单的，看途中注解就可以比较方便的理解这个流程。

![shot_2433](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2433.png)

### 知识点：ViewController 的生命周期

注意这里我们重写了 ViewController 的 viewDidLoad 方法，这是 ViewController 众多生命周期中最经常被使用的一个。

![shot_2434](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2434.png)

生命周期是指从它被创建到被销毁的整个过程，其中包含了一系列的时机，还有比如

1. **`init(coder:)` 和 `init(nibName:bundle:)`**：
   - 构造器，用于从 storyboard 或 XIB 文件加载视图控制器。

2. **`loadView()`**：
   - 当视图控制器需要加载视图时调用，通常在构造器之后。

3. **`viewDidLoad()`**：
   - 视图加载完成后调用，是设置初始状态和配置 UI 的好地方。

4. **`viewWillAppear(_:)`**：
   - 在视图即将出现到屏幕上时调用，可以用于配置动画或更新 UI。

5. **`viewDidAppear(_:)`**：
   - 视图已经出现在屏幕上后调用，可以执行一些需要视图已经可见的操作。

6. **`viewWillDisappear(_:)`**：
   - 在视图即将从屏幕上消失时调用，可以用于保存状态或清理。

7. **`viewDidDisappear(_:)`**：
   - 视图已经从屏幕上消失后调用，用于执行一些清理工作。

8. **`updateViewConstraints(_:)`**：
   - 在更新视图的约束之前调用，用于自定义约束更新逻辑。

9. **`viewWillLayoutSubviews()`** 和 **`viewDidLayoutSubviews()`**：
   - 分别在视图的子视图布局之前和之后调用，用于微调布局。

10. **`viewWillTransition(to:size:with:)`**：
    - 在视图控制器的视图将要改变大小时调用。

11. **`dealloc`**：
    - 视图控制器被销毁前调用，用于执行清理工作。



## 第三步：写 Logic 相关的代码



### 步骤 1：使用 Timer 驱动蛇的移动

为了让贪吃蛇移动起来，我们需要使用 Timer，这是用于定时执行任务的类。

它可以在指定的时间间隔后重复或单次执行代码块。使用 `Timer` 可以模拟时间相关的功能，如倒计时、游戏循环等。

使用方法如下：

![shot_2435](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2435.png)

### 知识点：为什么要使用 @objc

注意，为什么这里的方法需要额外加一个 @objc 的标记？

因为 @objc 属性用于桥接 Swift 和 Objective-C 之间的方法调用，被标记了之后的 Swift 类、属性、方法或其他成员，就可以在 Objective-C 代码中使用。

而 `Timer` 类实际上源自 Objective-C 运行时，因为 `Timer` 是 `NSObject` 的子类。所以为了能够将 Swift 的方法作为目标方法传递给 Objective-C 的 `Timer`，就必须加上 @objc



### 步骤 2：判断游戏结束的条件

![shot_2436](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2436.png)

具体的逻辑很简单，但是涉及一个核心知识点：

### 知识点：Swift 中的 optional（可选类型）

`optional`（可选类型）是一个特殊的类型，用来表示某个位置可能包含一个值，或者根本没有值。在声明时，会加上问号来标记可选类型。比如下图，就代表这个 gameGround 可能是一个 GameView 的，也可能是一个 nil（空值）

![shot_2454](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2454.png)

因此，我们在使用的时候，可以使用感叹号来强制解析，不过一般我们推荐使用可选绑定（`if let` 或 `guard let`）来安全地解包，比如上图里使用的 guard let 方法。



### 步骤 3：核心逻辑函数 moveSnake

比较复杂，可以看源代码仔细研究

![shot_2437](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2437.png)



## 其他知识点：

懒加载

![shot_2441](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2441.png)

通过 extension 来简化代码

![shot_2442](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2442.png)

实现 Equatable 来支持使用双等号判断

![shot_2443](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2443.png)

Swift 变量的 didSet 用法

![shot_2444](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2444.png)

通过使用 weak 避免循环引用：

![shot_2445](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2445.png)

高阶函数 contains，以及 $0 的语法糖使用

![shot_2436](/Users/timo.wang/Desktop/Timo/Rickey-iOS-Notes/backups/SnakeGame/shot_2436.png)
