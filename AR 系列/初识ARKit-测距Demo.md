# 初识 ARKit - 测距 Demo

自从听了 [WWDC2017 keynote](https://developer.apple.com/videos/play/wwdc2017/101/) 之后，在下就对 ARKit 产生了非常浓厚的兴趣。早就想一探究竟，如今终于也算是开始入门了。之前已经看到各种 `AR 尺子` 的类似 Demo，姑且就以这一个Demo作为练习。


### 1. 新建 AR 项目

<img src="https://i.loli.net/2018/01/03/5a4cc7b4c9c96.jpg" width="200px"/>
<img src="https://i.loli.net/2018/01/03/5a4ccd8350a28.jpg" width="200px"/>

如下图所示，直接选择 Xcode9 中预设的 AR 项目即可。不过需要注意的是，第二张图内的 `Content Technology` 一共有三个选项，分别是 `SceneKit、SpriteKit 和 Metal`。大致区别在下面有一些简单的说明，我们的 Demo 先直接使用默认的 SceneKit 即可。


##### Content Technology
- SceneKit：为复杂 3D 模型设计
    - 基于 OpenGL，整合了 Core Animation 和 Core Image，性能更高。
    - 不需要复杂的 3D 动画编程技巧，但需要更复杂的数学计算。
- SpriteKit：更适合 2D 动画
    - 兼容 Metal 和 OpenGL
    - 支持 iOS 和 OS X
    - 与 Xcode 集成，可以更容易的创建基于 SpriteKit 的游戏工程，调试也很方便
- Metal：支持 GPU 的 3D 绘图 API
    - 底层 API 负责和 3D 绘图硬件交互

### 2. 理解项目初始框架
新建了 AR 项目之后，我们简单来了解一下 AR 项目的框架构造。观察发现，其实 Xcode 为我们新建的 AR 项目和普通项目有下面几个不同之处：

- `Info.plist` **中自动创建了** Privacy - Camera Usage Description
- **新增了 art.scnassets**
- ViewController **中新增了** `didFailWithError`、`sessionWasInterrupted`、`sessionInterruptionEnded` **三个方法**
- **新建了** `sceneView: ARSCNView!` **并自动设置了其 delegate**
- ViewController 中内置了部分对 `sceneView` 进行管理的代码

##### art.scnassets 是什么？





### 参考资料
1. [stackoverflow - What does art.scnassets stand for?](https://stackoverflow.com/questions/46189551/what-does-art-scnassets-stand-for)
2. [how-to-create-a-measuring-app-with-arkit-in-ios-11](https://www.thedroidsonroids.com/blog/how-to-create-a-measuring-app-with-arkit-in-ios-11)
3. [SpriteKit vs. SceneKit: Adding Animation to iOS Games & Apps](https://www.upwork.com/hiring/mobile/spritekit-vs-scenekit/)

