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

而 GPU 拥有更多的计算单元，具有更强的计算能力，同时也具有更多的控制单元。GPU 基于大吞吐量而设计，更适合大规模的并行计算。

#### 图像渲染流水线

图像渲染流程粗粒度地大概分为下面这三个主要步骤：

![GraphicsPipeline](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSRender/GraphicsPipeline.png)

**Application 应用处理阶段：得到图元**

这个阶段具体指的就是图像在应用中被处理的阶段，此时还处于 CPU 负责的时期。在这个阶段应用可能会对图像进行一系列的操作或者改变，最终将新的图像信息传给下一阶段。这部分信息被叫做图元（primitives），通常是三角形、线段、顶点等。

**Geometry 几何渲染阶段：处理图元**

进入这个阶段之后，就主要由 GPU 负责了。此时 GPU 可以拿到上一个阶段传递下来的图元信息，GPU 会对这部分图元进行处理，之后输出新的图元。具体操作包括：

- 顶点着色（Vertex Shading）：图元中的三角形、线段、顶点分别对应三个 Vertex、两个 Vertex、一个 Vertex。这个阶段中会将这些顶点进行视角转换、添加光照信息、增加纹理等操作。
- 



图形渲染流水线可以分为以下六个步骤：顶点着色器（Vertex Shader）、形状装配（Shape Assembly）、几何着色器（Geometry Shader）、光栅化（Rasterization）、片段着色器（Fragment Shader）、测试与混合（Tests and Blending）。





---



[计算机那些事(8)——图形图像渲染原理](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)：硬件方面，GPU 渲染过程，CPU+GPU 架构，屏幕渲染工作流

[iOS 图像渲染原理](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)：渲染技术栈+框架，UIView+CALayer+四层树，CoreAnimation 流水线，动画渲染

[iOS Core Animation: Advanced Techniques中文译本](https://zsisme.gitbooks.io/ios-/content/index.html)：UIView+CAlayer 四层树，寄宿图，图层效果，图层变换，图层动画，图层性能

[深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/)：渲染框架，各框架渲染pipeline，commitTransaction，动画，性能检测思路

[iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)：图像显示原理+卡顿原因，CPU+GPU 资源开销，AsyncDisplayKit 原理（图层和成+异步并发）

[iOS 开发：绘制像素到屏幕](https://segmentfault.com/a/1190000000390012)



## 硬件方面

[计算机那些事(8)——图形图像渲染原理](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)

- **CPU（Central Processing Unit）**：现代计算机的三大核心部分之一，作为整个系统的运算和控制单元。CPU 内部的流水线结构使其拥有一定程度的并行计算能力。
- **GPU（Graphics Processing Unit）**：一种可进行绘图运算工作的专用微处理器。GPU 能够生成 2D/3D 的图形图像和视频，从而能够支持基于窗口的操作系统、图形用户界面、视频游戏、可视化图像应用和视频播放。GPU 具有非常强的并行计算能力。

CPU 与 GPU 的区别：[CPU 和 GPU 的区别是什么？ - 虫子君的回答 - 知乎](https://www.zhihu.com/question/19903344/answer/96081382)

GPU 图形渲染流水线：顶点着色器、形状装配、几何着色器、光栅化、片段着色器、测试与混合。英文 + 图示+ 详细介绍 [GPU Rendering Pipeline——GPU渲染流水线简介 - 拓荒犬的文章 - 知乎](https://zhuanlan.zhihu.com/p/61949898)

CPU+GPU的异构系统、工作流：分离式 or 耦合式系统，数据存入显存->CPU 驱动 GPU->GPU 并行处理->传回主存。

屏幕显示原理：CRT 电子枪、HSync+Vsync 信号，双缓冲机制以及掉帧的原因

[iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)：屏幕成像原理CRT + 卡顿原因



## iOS 渲染架构

[iOS 图像渲染原理](http://chuquan.me/2018/09/25/ios-graphics-render-principle/)

iOS 图形渲染技术栈：Display-GPU-Driver-OpenGL-Core...-app

iOS 渲染框架：UIKit，CoreAnimation，CoreGraphics，CoreImage，OpenGLES，Metal。

- [渲染框架详细说明](https://xiaozhuanlan.com/topic/9871534260)

- [深入理解 iOS Rendering Process](https://lision.me/ios_rendering_process/) - 渲染框架详解

UIKit 和 CoreAnimation 的关系



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

根据流水线分析性能消耗的主要原因 [iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/) ：

- CPU、GPU 消耗的原因
- 解决原因
- todo：一些成熟方案？Texture、IGList 等



---



引用文献：

- [Inside look at modern web browser](https://developers.google.com/web/updates/2018/09/inside-browser-part1)
- [1.2CPU和GPU的设计区别 - Magnum Programm Life](https://www.cnblogs.com/biglucky/p/4223565.html)
- [CUDA编程(三): GPU架构了解一下! - SeanDepp](https://www.jianshu.com/p/87cf95b1faa0)
- [Graphics pipeline - Wiki](https://en.wikipedia.org/wiki/Graphics_pipeline)
- [GPU Rendering Pipeline——GPU渲染流水线简介 - 拓荒犬的文章 - 知乎](https://zhuanlan.zhihu.com/p/61949898)
- [计算机那些事(8)——图形图像渲染原理 - 楚权的世界](http://chuquan.me/2018/08/26/graphics-rending-principle-gpu/)