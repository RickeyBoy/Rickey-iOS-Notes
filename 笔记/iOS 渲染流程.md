# iOS 渲染流程



## 计算机渲染原理

#### CPU 与 GPU 的架构

对于现代计算机系统，简单来说可以大概视作三层架构：硬件、操作系统与进程。对于移动端来说，进程就是 app，而 CPU 与 GPU 是硬件层面的重要组成部分。CPU 与 GPU 提供了计算能力，通过操作系统被 app 调用。

![CPUGPU](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/CPUGPU.png)

- **CPU（Central Processing Unit）**：现代计算机整个系统的运算核心、控制核心。
- **GPU（Graphics Processing Unit）**：可进行绘图运算工作的专用微处理器，是连接计算机和显示终端的纽带。

CPU 和 GPU 其设计目标就是不同的，它们分别针对了两种不同的应用场景。CPU 是运算核心与控制核心，需要有很强的运算通用性，兼容各种数据类型，同时也需要能处理大量不同的跳转、中断等指令，因此 CPU 的内部结构更为复杂。而 GPU 则面对的是类型统一、更加单纯的运算，也不需要处理复杂的指令，但也肩负着更。

![architecture](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/architecture.png)

因此，CPU 与 GPU 的架构也不同。因为 CPU 面临的情况更加复杂，因此从上图中也可以看出，CPU 拥有更多的缓存空间以及复杂的控制单元，计算能力并不是 CPU 的主要诉求。CPU 是设计目标是低时延，更多的高速缓存也意味着可以更快地访问数据；同时复杂的控制单元也能更快速地处理逻辑分支，更适合串行计算。

而 GPU 拥有更多的计算单元，具有更强的计算能力，同时也具有更多的控制单元。GPU 基于大吞吐量而设计，每一部分缓存都连接着一个流处理器（stream processor），更加适合大规模的并行计算。

#### 图像渲染流水线

图像渲染流程粗粒度地大概分为下面这些步骤：

![GraphicsPipeline](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/GraphicsPipeline.png)

**Application 应用处理阶段：得到图元**

这个阶段具体指的就是图像在应用中被处理的阶段，此时还处于 CPU 负责的时期。在这个阶段应用可能会对图像进行一系列的操作或者改变，最终将新的图像信息传给下一阶段。这部分信息被叫做图元（primitives），通常是三角形、线段、顶点等。

**Geometry 几何处理阶段：处理图元**

进入这个阶段之后，以及之后的阶段，就都主要由 GPU 负责了。此时 GPU 可以拿到上一个阶段传递下来的图元信息，GPU 会对这部分图元进行处理，之后输出新的图元。这一系列阶段包括：

- 顶点着色器（Vertex Shader）：这个阶段中会将图元中的顶点信息进行视角转换、添加光照信息、增加纹理等操作。
- 形状装配（Shape Assembly）：图元中的三角形、线段、点分别对应三个 Vertex、两个 Vertex、一个 Vertex。这个阶段会将 Vertex 连接成相对应的形状。
- 几何着色器（Geometry Shader）：额外添加额外的Vertex，将原始图元转换成新图元，以构建一个不一样的模型。简单来说就是基于通过三角形、线段和点构建更复杂的几何图形。

**Rasterization 光栅化阶段：图元转换为像素**

光栅化的主要目的是将几何渲染之后的图元信息，转换为一系列的像素，以便后续显示在屏幕上。这个阶段中会根据图元信息，计算出每个图元所覆盖的像素信息等，从而将像素划分成不同的部分。

![rasterization](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/rasterization.png)

一种简单的划分就是根据中心点，如果像素的中心点在图元内部，那么这个像素就属于这个图元。如上图所示，深蓝色的线就是图元信息所构建出的三角形；而通过是否覆盖中心点，可以遍历出所有属于该图元的所有像素，即浅蓝色部分。

**Pixel 像素处理阶段：处理像素，得到位图**

经过上述光栅化阶段，我们得到了图元所对应的像素，此时，我们需要给这些像素填充颜色和效果。所以最后这个阶段就是给像素填充正确的内容，最终显示在屏幕上。这些经过处理、蕴含大量信息的像素点集合，被称作位图（bitmap）。也就是说，Pixel 阶段最终输出的结果就是位图，过程具体包含：

这些点可以进行不同的排列和染色以构成图样。当放大位图时，可以看见赖以构成整个图像的无数单个方块。只要有足够多的不同色彩的像素，就可以制作出色彩丰富的图象，逼真地表现自然界的景象。缩放和旋转容易失真，同时文件容量较大。

- 片段着色器（Fragment Shader）：也叫做 Pixel Shader，这个阶段的目的是给每一个像素 Pixel 赋予正确的颜色。颜色的来源就是之前得到的顶点、纹理、光照等信息。由于需要处理纹理、光照等复杂信息，所以这通常是整个系统的性能瓶颈。
- 测试与混合（Tests and Blending）：也叫做 Merging 阶段，这个阶段主要处理片段的前后位置以及透明度。这个阶段会检测各个着色片段的深度值 z 坐标，从而判断片段的前后位置，以及是否应该被舍弃。同时也会计算相应的透明度 alpha 值，从而进行片段的混合，得到最终的颜色。

#### GPU 渲染流水线

上述图像渲染流水线中，除了第一部分 app 处理阶段，后续主要都由 GPU 负责。所以总结一下，GPU 渲染流水线总共有六个步骤，如下图所示：

![GPUPipeline](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/GPUPipeline.png)

上图就是一个三角形被渲染的过程中，GPU 所负责的渲染流水线。可以看到简单的三角形绘制就需要大量的计算，如果再有更多更复杂的顶点、颜色、纹理信息（包括 3D 纹理），那么计算量是难以想象的。这也是为什么 GPU 更适合于渲染流程。

#### 屏幕成像与卡顿

在图像渲染流程结束之后，接下来就需要将得到的像素信息显示在物理屏幕上了。GPU 最后一步渲染结束之后像素信息，被存在帧缓冲器（Framebuffer）中，之后视频控制器（Video Controller）会读取帧缓冲器中的信息，经过数模转换传递给显示器（Monitor），进行显示。完整的流程如下图所示：

![renderStructure](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/renderStructure.png)

经过 GPU 处理之后的像素集合，也就是位图，会被帧缓冲器缓存起来，供之后的显示使用。显示器的电子束会从屏幕的左上角开始逐行扫描，屏幕上的每个点的图像信息都从帧缓冲器中的位图进行读取，在屏幕上对应地显示。扫描的流程如下图所示：

![vsync](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/vsync.png)

电子束扫描的过程中，屏幕就能呈现出对应的结果，每次整个屏幕被扫描完一次后，就相当于呈现了一帧完整的图像。屏幕不断地刷新，不停呈现新的帧，就能呈现出连续的影像。而这个屏幕刷新的频率，就是帧率（Frame per Second，FPS）。由于人眼的视觉暂留效应，当屏幕刷新频率足够高时（FPS 通常是 50 到 60 左右），就能让画面看起来是连续而流畅的。对于 iOS 而言，app 应该尽量保证 60 FPS 才是最好的体验。

**屏幕撕裂 Screen Tearing**

在这种单一缓存的模式下，最理想的情况就是一个流畅的流水线：每次电子束从头开始新的一帧的扫描时，CPU+GPU 对于该帧的渲染流程已经结束，渲染好的位图已经放入帧缓冲器中。但这种完美的情况是非常脆弱的，很容易产生屏幕撕裂：

![tearing](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/tearing.jpg)

CPU+GPU 的渲染流程是一个非常耗时的过程。如果在电子束开始扫描新的一帧时，位图还没有渲染好，而是在扫描到屏幕中间时才渲染完成，被放入帧缓冲器中 ---- 那么已扫描的部分就是上一帧的画面，而未扫描的部分则会显示新的一帧图像，这就造成屏幕撕裂。

**垂直同步 Vsync + 双缓冲机制 Double Buffering**

解决屏幕撕裂、提高显示效率的一个策略就是使用垂直同步信号 Vsync 与双缓冲机制 Double Buffering。根据苹果的官方文档描述，iOS 设备会始终使用 Vsync + Double Buffering 的策略。

垂直同步信号（vertical synchronisation，Vsync）相当于给帧缓冲器加锁：当电子束完成一帧的扫描，将要从头开始扫描时，就会发出一个垂直同步信号。只有当视频控制器接收到 Vsync 之后，才会将帧缓冲器中的位图更新为下一帧，这样就能保证每次显示的都是同一帧的画面，因而避免了屏幕撕裂。

但是这种情况下，视频控制器在接受到 Vsync 之后，就要将下一帧的位图传入，这意味着整个 CPU+GPU 的渲染流程都要在一瞬间完成，这是明显不现实的。所以双缓冲机制会增加一个新的备用缓冲器（back buffer）。渲染结果会预先保存在 back buffer 中，在接收到 Vsync 信号的时候，视频控制器会将 back buffer 中的内容置换到 frame buffer 中，此时就能保证置换操作几乎在一瞬间完成（实际上是交换了内存地址）。

![gpu-double-buffer](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/gpu-double-buffer.png)

**掉帧 Jank**

启用 Vsync 信号以及双缓冲机制之后，能够解决屏幕撕裂的问题，但是会引入新的问题：掉帧。如果在接收到 Vsync 之时 CPU 和 GPU 还没有渲染好新的位图，视频控制器就不会去替换 frame buffer 中的位图。这时屏幕就会重新扫描呈现出上一帧一模一样的画面。相当于两个周期显示了同样的画面，这就是所谓掉帧的情况。

![double](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/double.png)

如图所示，A、B 代表两个帧缓冲器，当 B 没有渲染完毕时就接收到了 Vsync 信号，所以屏幕只能再显示相同帧 A，这就发生了第一次的掉帧。

**三缓冲 Triple Buffering**

事实上上述策略还有优化空间。我们注意到在发生掉帧的时候，CPU 和 GPU 有一段时间处于闲置状态：当 A 的内容正在被扫描显示在屏幕上，而 B 的内容已经被渲染好，此时 CPU 和 GPU 就处于闲置状态。那么如果我们增加一个帧缓冲器，就可以利用这段时间进行下一步的渲染，并将渲染结果暂存于新增的帧缓冲器中。

![tripple](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/tripple.png)

如图所示，由于增加了新的帧缓冲器，可以一定程度上地利用掉帧的空档期，合理利用 CPU 和 GPU 性能，从而减少掉帧的次数。

**屏幕卡顿的本质**

手机使用卡顿的直接原因，就是掉帧。前文也说过，屏幕刷新频率必须要足够高才能流畅。对于 iPhone 手机来说，屏幕最大的刷新频率是 60 FPS，一般只要保证 50 FPS 就已经是较好的体验了。但是如果掉帧过多，导致刷新频率过低，就会造成不流畅的使用体验。

这样看来，可以大概总结一下

- 屏幕卡顿的根本原因：CPU 和 GPU 渲染流水线耗时过长，导致掉帧。
- Vsync 与双缓冲的意义：强制同步屏幕刷新，以掉帧为代价解决屏幕撕裂问题。
- 三缓冲的意义：合理使用 CPU、GPU 渲染性能，减少掉帧次数。



## iOS 的渲染原理

#### iOS 渲染框架

![softwareStack](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/softwareStack.png)

iOS App 的图形渲染技术栈，App 使用 Core Graphics、Core Animation、Core Image 等框架来绘制可视化内容，这些软件框架相互之间也有着依赖关系。这些框架都需要通过 OpenGL 来调用 GPU 进行绘制，最终将内容显示到屏幕之上。









---


## iOS 渲染架构

[iOS 图像渲染原理](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)

iOS 图形渲染技术栈：Display-GPU-Driver-OpenGL-Core...-app

iOS 渲染框架：UIKit，CoreAnimation，CoreGraphics，CoreImage，OpenGLES，Metal。

- [渲染框架详细说明](https://xiaozhuanlan.com/topic/9871534260)

- [深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/) - 渲染框架详解

UIKit 和 CoreAnimation 的关系

[iOS 图像渲染原理](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)：渲染技术栈+框架，UIView+CALayer+四层树，CoreAnimation 流水线，动画渲染

[iOS Core Animation: Advanced Techniques中文译本](https://zsisme.gitbooks.io/ios-/content/index.html)：UIView+CAlayer 四层树，寄宿图，图层效果，图层变换，图层动画，图层性能

[深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/)：渲染框架，各框架渲染pipeline，commitTransaction，动画，性能检测思路

Advanced Graphics and Animations for iOS Apps：https://joakimliu.github.io/2019/03/02/wwdc-2014-419/

Getting Pixels onto the Screen 中文版：https://www.geek-share.com/detail/2695278535.html



## CALayer 渲染过程

[iOS 图像渲染原理](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)

UIView 和 CALayer 区别：

1. 框架不同
2. 进一步的封装
3. 平行层级关系，职责分离
4. [CALayer 基础](https://luochenxun.com/ios-calayer-overview/)

CALayer 如何呈现内容：CAlayer=纹理=图片，backing store 包含 contents，两种实现方式

- [调用 drawRect 之后](https://www.jianshu.com/p/c49833c04362)
- [深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/) - 不同框架的 pipeline

CoreAnimation 流水线：CALayer 到 render server 到 GPU 到 Display.

UIView animation 动画渲染过程：调用，Layout Display Prepare Commit，Render Server



## CALayer + CoreAnimation

[iOS Core Animation: Advanced Techniques中文译本](https://zsisme.gitbooks.io/ios-/content/index.html)

CALayer 寄宿图：Contents 属性 + Custom Drawing

性能调优 + 高效绘图 + 图像 IO + 图层性能



## 解决卡顿

卡顿监控：https://github.com/aozhimin/iOS-Monitor-Platform#fps，包括两种监控方案

根据流水线分析性能消耗的主要原因 [iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/) ：

- CPU、GPU 消耗的原因
- 解决原因
- todo：一些成熟方案？Texture、IGList 等

使用 Instrument 调试的具体内容，加一些常见解决方案：https://blog.csdn.net/Hello_Hwc/article/details/52331548





---



引用文献：

- [Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1)
- [1.2CPU和GPU的设计区别 - Magnum Programm Life](https://www.cnblogs.com/biglucky/p/4223565.html)
- [CUDA编程(三): GPU架构了解一下! - SeanDepp](https://www.jianshu.com/p/87cf95b1faa0)
- [Graphics pipeline - Wiki](https://en.wikipedia.org/wiki/Graphics_pipeline)
- [GPU Rendering Pipeline——GPU渲染流水线简介 - 拓荒犬的文章 - 知乎](https://zhuanlan.zhihu.com/p/61949898)
- [计算机那些事(8)——图形图像渲染原理 - 楚权的世界](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)
- [iOS 保持界面流畅的技巧 - ibireme](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)
- [Framebuffer - Wiki](https://en.wikipedia.org/wiki/Framebuffer)
- [Frame Rate (iOS and tvOS)](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/FrameRate.html)
- [理解 Vsync - 陈蒙](https://blog.csdn.net/zhaizu/article/details/51882768)
- [Getting Pixels onto the Screen](https://www.objc.io/issues/3-views/moving-pixels-onto-the-screen/)



---

已使用的资源



## 硬件方面

[计算机那些事(8)——图形图像渲染原理](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)

- **CPU（Central Processing Unit）**：现代计算机的三大核心部分之一，作为整个系统的运算和控制单元。CPU 内部的流水线结构使其拥有一定程度的并行计算能力。
- **GPU（Graphics Processing Unit）**：一种可进行绘图运算工作的专用微处理器。GPU 能够生成 2D/3D 的图形图像和视频，从而能够支持基于窗口的操作系统、图形用户界面、视频游戏、可视化图像应用和视频播放。GPU 具有非常强的并行计算能力。

CPU 与 GPU 的区别：[CPU 和 GPU 的区别是什么？ - 虫子君的回答 - 知乎](https://www.zhihu.com/question/19903344/answer/96081382)

GPU 图形渲染流水线：顶点着色器、形状装配、几何着色器、光栅化、片段着色器、测试与混合。英文 + 图示+ 详细介绍 [GPU Rendering Pipeline——GPU渲染流水线简介 - 拓荒犬的文章 - 知乎](https://zhuanlan.zhihu.com/p/61949898)

CPU+GPU的异构系统、工作流：分离式 or 耦合式系统，数据存入显存->CPU 驱动 GPU->GPU 并行处理->传回主存。

屏幕显示原理：CRT 电子枪、HSync+Vsync 信号，双缓冲机制以及掉帧的原因

[iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)：屏幕成像原理CRT + 卡顿原因

[OpenGL 图片从文件渲染到屏幕的过程](https://juejin.im/post/5d732ea96fb9a06b2d77f76a)：屏幕缓冲区 + 离屏缓冲区，iOS 图片显示过程

