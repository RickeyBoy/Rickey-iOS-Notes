# iOS Animation 动画

> 比较不同的动画实现方式（CoreAnimation UIView 基于计时器（DisplayLink + NStimer + GCD） 粒子效果 物理仿真  Lottie FacebookPop）
> 不赘述动画的基本实现，只负责效果图（Swift playground）
> 讲解动画的底层原理（CALayer 相关）
> 比较动画的能力与性能
> 讲解动画的性能检测方式
> 举例一些动画的实现与题目（Github 可插入 gif）

# 动画底层实现原理

### CALayer 回顾

> An object that manages image-based content and allows you to perform animations on that content.
>
> [CALayer - Apple](https://developer.apple.com/documentation/quartzcore/calayer?language=objc)

简而言之，CALayer 就是一切内容呈现、动画的基础。

在内容呈现方面，CALayer 存在一个 `contents` 属性，用于保存渲染好的 bitmap（通常也被称为 **backing store**），从而系统在屏幕刷新时会将这部分渲染好的内容呈现在屏幕上。多个 CALayer 叠加呈现，在屏幕上构成图层树（model layer tree）。

![basics_layer_rendering_2x](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSAnimation/basics_layer_rendering_2x.png)

在动画过程中，Core Animation 会负责调用硬件进行逐帧绘制，而开发者只需要设置动画的起始状态和重点状态就可以了。

由于 CALayer 保存的是一个静态的 bitmap 以及一些状态信息（如透明度、旋转角度等），对于一个动画过程，实际上改变的是 layer 的状态，而不是静态内容。这也就意味着当动画发生时，Core Animation 会将静态 bitmap 以及改变后的状态传递给 GPU，GPU 根据 bitmap 及新的状态，将新的样式绘制在屏幕上。

而对比更传统的基于 UIView 重写 `drawRect:` 的动画实现方式，每一次动画改变都需要依赖新参数进行重绘，这就导致了主线程昂贵的 CPU 消耗。基于 CALayer 的动画就能避免这些消耗，因为 GPU 是直接根据 bitmap 进行绘制，GPU 会对 bitmap 进行缓存，这样能极大地节约 CPU 的性能消耗，提高效率。

### CALayer 隐式动画（Layer-Based Animations）

#### 隐式动画是什么

![basics_animation_types_2x](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSAnimation/basics_animation_types_2x.png)

CALayer 支持的动画类型很多，上图是一些最基本的例子。当改变 CALayer 的某些属性时，它并不会瞬间在屏幕上改变，而是会从先前的值平滑过渡到新的值，这就是 CALayer 的隐式动画。隐式动画在用户体验方面带来的好处非常明显，那就是在属性切换时显得不那么生硬，而是自然地过渡。

隐式动画默认打开，Core Animation 会负责具体的实现。在日常开发中，我们只是通过代码改变了 CALayer 某些属性的值，隐式动画就会被自动触发。具体会触发隐式动画的属性可以参考：[Animatable Properties - CALayer](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/AnimatableProperties/AnimatableProperties.html#//apple_ref/doc/uid/TP40004514-CH11-SW1)。

从上面这个文档中可以发现，绝大部分的基础属性（包括背景色、透明度、圆角等）的改变都会触发隐式动画，而默认的隐式动画通过 [CABasicAnimation](https://developer.apple.com/documentation/quartzcore/cabasicanimation) 类实现，**默认时长为 0.25s**。

{
#### TODO - 隐式动画的原理，事务
#### TODO - 隐式动画的关闭
#### TODO - 隐式动画的自定义图层
#### TODO - 呈现与模型
https://zsisme.gitbooks.io/ios-/content/chapter7/transactions.html
https://cloud.tencent.com/developer/article/1418000
https://zhangbuhuai.com/post/implicit-animations.html
}

### CALayer 显示动画

上一章介绍了隐式动画的概念。隐式动画是在iOS平台创建动态用户界面的一种直接方式，也是UIKit动画机制的基础，不过它并不能涵盖所有的动画类型。在这一章中，我们将要研究一下显式动画，它能够对一些属性做指定的自定义动画，或者创建非线性动画，比如沿着任意一条曲线移动。



# 动画实现方法简述

### UIView 动画

我们查看 UIView.h 的源码可以清晰地看到，通过 UIView 实现的动画效果有下面三种方式：

- UIView (UIViewAnimation) - **basic animation 基础动画**
- UIView (UIViewAnimationWithBlocks) - **basic animation 基础动画**
- UIView (UIViewKeyframeAnimations) - **keyframe animation 关键帧动画**








---
CoreAnimation 中文译本
https://zsisme.gitbooks.io/ios-/content/index.html

iOS 动画全面解析 - 掘金
https://juejin.im/post/6844903698737397773

- UIView 封装 CoreAnimation
- CA 的一些基类、属性介绍，动画类型（Basic、Keyframe、CATransition 等）
- CALayer 子类特殊动画
- 交互式动画 UIViewPropertyAnimator
- ViewController 转场动画

重读 CALayer - 简书
https://www.jianshu.com/p/e3c118e56c9a

动画相关面试题 gitbook
https://hit-alibaba.github.io/interview/iOS/Cocoa-Touch/Animation.html
（UIView、CA）
- UIDynamic Animator 物理仿真动画
- CAEmitterLayer 粒子动画

iOS 中的 FPS - 刘峰 - tech
https://tech.bytedance.net/articles/6854742302901043214
CPU、GPU、FPS 之间的关系
卡顿与如何测量



UIView block 动画的实现原理
https://zhuanlan.zhihu.com/p/71861969

https://www.jianshu.com/p/13c231b76594（包含 actionForKey 四个步骤）



全部 iOS 动画 - 掘金

https://juejin.im/entry/6844903480952537102

讲述各个动画



UIView 动画相关内容

https://www.jianshu.com/p/dbbfdee37936



[Why an empty implementation of drawRect: will adversely affect performance during animation](https://stackoverflow.com/questions/18748276/why-an-empty-implementation-of-drawrect-will-adversely-affect-performance-durin)