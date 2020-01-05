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



## iOS 中的渲染框架

![softwareStack](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/softwareStack.png)

iOS 的渲染框架依然符合渲染流水线的基本架构，具体的技术栈如上图所示。在硬件基础之上，iOS 中有 Core Graphics、Core Animation、Core Image、OpenGL 等多种软件框架来绘制内容，在 CPU 与 GPU 之间进行了更高层地封装。

**GPU Driver**：上述软件框架相互之间也有着依赖关系，不过所有框架最终都会通过 OpenGL 连接到 GPU Driver，GPU Driver 是直接和 GPU 交流的代码块，直接与 GPU 连接。

**OpenGL**：是一个提供了 2D 和 3D 图形渲染的 API，它能和 GPU 密切的配合，最高效地利用 GPU 的能力，实现硬件加速渲染。OpenGL的高效实现（利用了图形加速硬件）一般由显示设备厂商提供，而且非常依赖于该厂商提供的硬件。OpenGL 之上扩展出很多东西，如 Core Graphics 等最终都依赖于 OpenGL，有些情况下为了更高的效率，比如游戏程序，甚至会直接调用 OpenGL 的接口。

**Core Graphics**：Core Graphics 是一个强大的二维图像绘制引擎，是 iOS 的核心图形库，常用的比如 CGRect 就定义在这个框架下。

**Core Animation**：在 iOS 上，几乎所有的东西都是通过 Core Animation 绘制出来，它的自由度更高，使用范围也更广。

**Core Image**：Core Image 是一个高性能的图像处理分析的框架，它拥有一系列现成的图像滤镜，能对已存在的图像进行高效的处理。



#### Core Animation 是什么

> Render, compose, and animate visual elements. ---- Apple

Core Animation，它本质上可以理解为一个复合引擎，主要职责包含：渲染、构建和实现动画。

通常我们会使用 Core Animation 来高效、方便地实现动画，但是实际上它的前身叫做 Layer Kit，关于动画实现只是它功能中的一部分。对于 iOS app，不论是否直接使用了 Core Animation，它都在底层深度参与了 app 的构建。而对于 OS X app，也可以通过使用 Core Animation 方便地实现部分功能。

![CA](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/CA.png)

Core Animation 是 AppKit 和 UIKit 完美的底层支持，同时也被整合进入 Cocoa 和 Cocoa Touch 的工作流之中，它是 app 界面渲染和构建的最基础架构。 Core Animation 的职责就是尽可能快地组合屏幕上不同的可视内容，这个内容是被分解成独立的 **layer**（iOS 中具体而言就是 CALayer），并且被存储为树状层级结构。这个树也形成了 UIKit 以及在 iOS 应用程序当中你所能在屏幕上看见的一切的基础。

简单来说就是用户能看到的屏幕上的内容都由 CALayer 进行管理。那么 CALayer 究竟是如何进行管理的呢？另外在 iOS 开发过程中，最大量使用的视图控件实际上是 UIView 而不是 CALayer，那么他们两者的关系到底如何呢？



#### CALayer.contents 属性：存储 bitmap

简单理解，CALayer 就是屏幕显示的基础。那 CALayer 是如何完成的呢？让我们来从源码向下探索一下，在 CALayer.h 中，CALayer 有这样一个属性 contents：

```objective-c
/** Layer content properties and methods. **/

/* An object providing the contents of the layer, typically a CGImageRef,
 * but may be something else. (For example, NSImage objects are
 * supported on Mac OS X 10.6 and later.) Default value is nil.
 * Animatable. */

@property(nullable, strong) id contents;
```

> An object providing the contents of the layer, typically a CGImageRef.

contents 提供了 layer 的内容，是一个指针类型，在 iOS 中的类型就是 CGImageRef（在 OS X 中还可以是 NSImage）。而我们进一步查到，Apple 对 CGImageRef 的定义是：

> A bitmap image or image mask.

看到 bitmap，这下我们就可以和之前讲的的渲染流水线联系起来了：实际上，CALayer 中的 contents 属性保存了由设备渲染流水线渲染好的位图 bitmap（通常也被称为 **backing store**），而当设备屏幕进行刷新时，会从 CALayer 中读取生成好的 bitmap，进而呈现到屏幕上。

所以，如果我们在代码中对 CALayer 的 contents 属性进行了设置，比如这样：

```objective-c
// 注意 CGImage 和 CGImageRef 的关系：
// typedef struct CGImage CGImageRef;
layer.contents = (__bridge id)image.CGImage;
```

那么在运行时，操作系统会调用底层的接口，将 image 通过 CPU+GPU 的渲染流水线渲染得到对应的 bitmap，存储于 CALayer.contents 中，在设备屏幕进行刷新的时候就会读取 bitmap 在屏幕上呈现。

也正因为每次要被渲染的内容是被静态的存储起来的，所以每次渲染时，Core Animation 会触发调用 `drawRect:` 方法，使用存储好的 bitmap 进行新一轮的展示。



#### CALayer 与 UIView 的关系

UIView 作为最常用的视图控件，和 CALayer 也有着千丝万缕的联系，那么两者之间到底是个什么关系，他们有什么差异？

当然，两者有很多显性的区别，比如是否能够响应点击事件。但为了从根本上彻底搞懂这些问题，我们必须要先搞清楚两者的职责。

> [UIView - Apple](https://developer.apple.com/documentation/uikit/uiview)
>
> Views are the fundamental building blocks of your app's user interface, and the `UIView` class defines the behaviors that are common to all views. A view object renders content within its bounds rectangle and handles any interactions with that content.

根据 Apple 的官方文档，UIView 是 app 中的基本组成结构，定义了一些统一的规范。它会负责内容的渲染以及，处理交互事件。具体而言，它负责的事情可以归为下面三类

- Drawing and animation：绘制与动画
- Layout and subview management：布局与子 view 的管理
- Event handling：点击事件处理

> [CALayer - Apple](https://developer.apple.com/documentation/quartzcore/calayer)
>
> Layers are often used to provide the backing store for views but can also be used without a view to display content. A layer’s main job is to manage the visual content that you provide...
>
> If the layer object was created by a view, the view typically assigns itself as the layer’s delegate automatically, and you should not change that relationship.

而从 CALayer 的官方文档中我们可以看出，CALayer 的主要职责是管理内部的可视内容，这也和我们前文所讲的内容吻合。当我们创建一个 UIView 的时候，UIView 会自动创建一个 CALayer，为自身提供存储 bitmap 的地方（也就是前文说的 **backing store**），并将自身固定设置为 CALayer 的代理。

从这儿我们大概总结出下面两个**核心关系**：

1. CALayer 是 UIView 的属性之一，负责渲染和动画，提供可视内容的呈现。
2. UIView 提供了对 CALayer 部分功能的封装，同时也另外负责了交互事件的处理。

有了这两个最关键的根本关系，那么下面这些经常出现在面试答案里的显性的异同就很好解释了。举几个例子：

- **相同的层级结构**：我们对 UIView 的层级结构非常熟悉，由于每个 UIView 都对应 CALayer 负责页面的绘制，所以 CALayer 也具有相应的层级结构。

- **部分效果的设置**：因为 UIView 只对 CALayer 的部分功能进行了封装，而另一部分如圆角、阴影、边框等特效都需要通过调用 layer 属性来设置。

- **是否响应点击事件**：CALayer 不负责点击事件，所以不响应点击事件，而 UIView 会响应。

- **不同继承关系**：CALayer 继承自 NSObject，UIView 由于要负责交互事件，所以继承自 UIResponder。

当然还剩最后一个问题，为什么要将 CALayer 独立出来，直接使用 UIView 统一管理不行吗？为什么不用一个统一的对象来处理所有事情呢？

这样设计的主要原因就是为了职责分离，拆分功能，方便代码的复用。通过 Core Animation 框架来负责可视内容的呈现，这样在 iOS 和 OS X 上都可以使用 Core Animation 进行渲染。与此同时，两个系统还可以根据交互规则的不同来进一步封装统一的控件，比如 iOS 有 UIKit 和 UIView，OS X 则是AppKit 和 NSView。



## Core Animation 渲染流水线

当我们了解了 Core Animation 以及 CALayer 的基本知识后，接下来我们来看下 Core Animation 的渲染流水线。

![CApipeline](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/CApipeline.png)

整个流水线一共有下面几个步骤：

**Handle Events**：这个过程中会先处理点击事件，这个过程中有可能会需要改变页面的布局和界面层次，因此需要先完成相应的





当我们知道了单个 CALayer 的情况，实际上整个屏幕的显示还需要进行多个 CALayer 的合成。实际情况下，每个 CALayer 都需要被确定其在屏幕中所处的位置，以及对重叠的 CALayer 进行叠加处理。另外对于每个 CALayer 还有一些特殊的视觉效果，如圆角和阴影，甚至是一个对应的蒙版（mask）。蒙版本质上是一个拥有透明度信息的位图，类似于 CALayer 的子图层，CALayer 最终的呈现效果也是进行了蒙版叠加之后的效果。

// TODO: 此处缺一张图 sketch -- 位置、叠加、蒙版

进行了这一系列的处理之后，整个屏幕的内容才能被最终全部呈现出来。不过显而易见，这中间涉及到大量的运算，部分情况下可能会非常耗时，这一点我们在之后的章节中详细说明。







---


## iOS 渲染架构

Getting Pixels onto the Screen 中文版：https://www.geek-share.com/detail/2695278535.html

## CoreAnimation 渲染流水线

[iOS 图像渲染原理 - chuquan](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)

CoreAnimation 流水线：CALayer 到 render server 到 GPU 到 Display.

CoreAnimation 流水线 WWDC https://joakimliu.github.io/2019/03/02/wwdc-2014-419/

WWDC：https://ustcqidi.github.io/2018/06/14/wwdc-Advanced-Graphics-and-Animations-for-iOS-Apps/

渲染技术栈+框架，UIView+CALayer+四层树，CoreAnimation 流水线，动画渲染

[深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/)：渲染框架，各框架渲染pipeline，commitTransaction，动画，性能检测思路

## CALayer

UIView 和 CALayer 区别：

1. 框架不同
2. 进一步的封装
3. 平行层级关系，职责分离
4. [CALayer 基础](https://luochenxun.com/ios-calayer-overview/) **作为最后补充**

CALayer 如何呈现内容：

- [调用 drawRect 之后](https://www.jianshu.com/p/c49833c04362) **作为最后补充**
- [深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/) - 不同框架的 pipeline **作为最后补充**

[iOS Core Animation: Advanced Techniques中文译本](https://zsisme.gitbooks.io/ios-/content/index.html) 
UIView+CAlayer 四层树，寄宿图，图层效果，图层变换，图层动画，图层性能
CALayer 寄宿图：Contents 属性 + Custom Drawing
性能调优 + 高效绘图 + 图像 IO + 图层性能

UIView animation 动画渲染过程：调用，Layout Display Prepare Commit，Render Server

#### Layer Trees 是什么（不用）

https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html#//apple_ref/doc/uid/TP40004514-CH2-SW3


## 解决卡顿

卡顿监控：https://github.com/aozhimin/iOS-Monitor-Platform#fps，包括两种监控方案

根据流水线分析性能消耗的主要原因 [iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/) ：

- CPU、GPU 消耗的原因
- 解决原因
- todo：一些成熟方案？Texture、IGList 等

使用 Instrument 调试的具体内容，加一些常见解决方案：https://blog.csdn.net/Hello_Hwc/article/details/52331548

[WWDC 部分解决卡顿的方法](https://github.com/100mango/zen/blob/master/WWDC心得：Advanced Graphics and Animations for iOS Apps/Advanced Graphics and Animations for iOS Apps.md)





---



引用文献：

- [Inside look at modern web browser - Google](https://developers.google.com/web/updates/2018/09/inside-browser-part1)
- [1.2CPU和GPU的设计区别 - Magnum Programm Life](https://www.cnblogs.com/biglucky/p/4223565.html)
- [CUDA编程(三): GPU架构了解一下! - SeanDepp](https://www.jianshu.com/p/87cf95b1faa0)
- [Graphics pipeline - Wiki](https://en.wikipedia.org/wiki/Graphics_pipeline)
- [GPU Rendering Pipeline——GPU渲染流水线简介 - 拓荒犬的文章 - 知乎](https://zhuanlan.zhihu.com/p/61949898)
- [计算机那些事(8)——图形图像渲染原理 - 楚权的世界](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)
- [iOS 保持界面流畅的技巧 - ibireme](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)
- [Framebuffer - Wiki](https://en.wikipedia.org/wiki/Framebuffer)
- [Frame Rate (iOS and tvOS) - Apple](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/FrameRate.html)
- [理解 Vsync - 陈蒙](https://blog.csdn.net/zhaizu/article/details/51882768)
- [Getting Pixels onto the Screen - objc.io](https://www.objc.io/issues/3-views/moving-pixels-onto-the-screen/)
- [深入理解 iOS Rendering Process - lision](https://lision.me/ios_rendering_process/)
- [Core Animation Programming Guide - Apple](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40004514)
- [iOS Core Animation: Advanced Techniques中文译本](https://zsisme.gitbooks.io/ios-/content/index.html)
- 

