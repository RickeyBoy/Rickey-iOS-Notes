# UIView 动画降帧探究

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/Catalog.png?raw=true)

## 一、为什么要降帧

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/header.png?raw=true)

首先要说明一件事，那就是为什么要对动画降帧？

众所周知，刷新频率越高体验越好，对于 iOS app 的刷新频率应该是越接近越 60fps 越好，这里主动给动画降帧，肯定会影响动画的体验。但是另一方面，我们也知道动画渲染的过程中需要消耗大量的 GPU 资源，所以给动画降帧则可以给 GPU 减负，降低 GPU 使用率峰值。

所以给动画降帧，实际上是一种用体验换性能的决策，在动画不复杂但是数量很多的情况下（比如一些弹幕动画、点赞动画），给动画降帧并不会影响动画效果，此时降帧就能累计节约大量的 GPU 性能。



## 二、动画渲染对性能的消耗

iOS 中的屏幕渲染原理可以参看之前的文章：[iOS 渲染全解析](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/笔记/iOS%20Rendering.md)，文中会讲解整个屏幕渲染的过程，详细说明了 Core Animation 渲染流水线的整个原理，为什么渲染过程会对 GPU 有较大的消耗。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/CApipeline.png?raw=true)

下图是 Core Animation 的单次渲染流水线，也就是一帧动画的渲染过程：
- **Handle Events**：这个过程中会先处理点击事件，这个过程中有可能会需要改变页面的布局和界面层次。
- **Commit Transaction**：此时 app 会通过 **CPU** 处理显示内容的前置计算，比如布局计算、图片解码等任务，接下来会进行详细的讲解。之后将计算好的图层进行打包发给 Render Server。
- **Render Server - Decode**：打包好的图层被传输到 Render Server 之后，首先会进行解码。注意完成解码之后需要等待下一个 RunLoop 才会执行下一步 Draw Calls。
- **Render Server - Draw Calls**：解码完成后，Core Animation 会调用下层渲染框架的方法进行绘制，进而调用到 **GPU**。
- **GPU - Render**：这一阶段主要由 **GPU** 进行渲染。
- **Display**：显示阶段，需要等 render 结束的下一个 RunLoop 触发显示。

总而言之，每一帧动画的渲染对于 CPU 和 GPU 都有一定的消耗，尤其是对 GPU 的性能占用较大。




## 三、屏幕刷新 FPS vs CoreAnimation FPS 

vSync 垂直信号刷新屏幕的原理我们都知道，但是在 iOS 中并不止有一种 FPS。

### 屏幕刷新FPS

屏幕刷新帧率就是我们通常说的 FPS，由于人眼的视觉暂留效应，当屏幕刷新频率足够高时（FPS 通常是 50 到 60 左右），就能让画面看起来是连续而流畅的。当一次渲染时间过长，就会发生掉帧的现象，此时 FPS 下降，用户就能直观地感受到卡顿。

对于 iOS 用户来说， 屏幕刷新帧率直接反应了流畅度体验，显然 FPS 越高、越接近 60 越好。

### CoreAnimation FPS

CoreAnimation FPS 指的是 CoreAnimation Render Server 的运行帧率，对应前面渲染流水线中非常重要的 GPU render 阶段。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/CApipeline2.png?raw=true)

可以发现，每一次渲染流水线都一定会有 Render Server 参与的过程，所以 Render Server 运行的频率直接反应了 GPU 被调用的频率。CoreAnimation FPS 越高，意味着 GPU 被渲染流水线使用的越频繁，那么相应的 GPU 使用率就会越高。

所以简单来说 CoreAnimation FPS 直接影响了 GPU 的使用率，一般来说 CoreAnimation FPS 越低越好。

正常情况下，如果界面没有频繁的 UI 变更，不需要频繁的重新渲染，那么 CoreAnimation FPS 应该是非常低的。但是如果使用了高帧率动画，由于需要快速更新动画效果，必然会引起 CoreAnimation FPS 升高。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/Instrument.png?raw=true)

我们使用 Instrument 中 CoreAnimation FPS 选项测出的 FPS 就是 CoreAnimation FPS，如图可以看到，能够通过 Instrument 监测到 avg CoreAnimation FPS，以及 GPU 使用率的情况，可以将这些指标作为帧率优化的结果指标。



## 四、降帧方案

在调查降帧方案之前，先回顾一下我们的最终目的：调研多种动画实现方法，选择可以控制或者降低渲染帧率的方式，重新实现已有动画。进而达到降低 GPU 使用率的效果。

### 重写 DrawRect:

一种常见自定义动画的方案是通过重写 drawRect: 方法实现：改变 view 属性 -> 触发 drawRect: 进行重绘 -> 改变 view 的展示。

在前文提到的渲染流水线的 Commit Transaction 这个阶段中，其中 Display 步骤会通过 Core Graphics 进行视图的绘制，注意不是真正的显示，而是得到图元 primitives 数据。

注意正常情况下 Display 阶段只会得到图元 primitives 信息，而位图 bitmap 是在 GPU 中根据图元信息绘制得到的。但是如果重写了 drawRect: 方法，这个方法会直接调用 Core Graphics 绘制方法得到 bitmap 数据，同时系统会额外申请一块内存，用于暂存绘制好的 bitmap。

由于重写了  drawRect: 方法，导致绘制过程从 GPU 转移到了 CPU，这就导致了一定的效率损失。与此同时，这个过程会额外使用 CPU 和内存，因此如果绘制效率不够高，很容易造成 CPU 卡顿或者内存爆炸。

显而易见，通过重写 DrawRect: 方法来实现的动画并不适合来做降帧优化的方案。

### Core Animation 动画

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/CAProcess.png?raw=true)

由于 CALayer 保存的是一个静态的 bitmap 以及一些状态信息（如透明度、旋转角度等），对于一个动画过程，实际上改变的是 layer 的状态，而不是静态内容。这也就意味着当动画发生时，Core Animation 会将静态 bitmap 以及改变后的状态传递给 GPU，GPU 根据 bitmap 及新的状态，将新的样式绘制在屏幕上。

而对比更传统的基于 UIView 重写 drawRect: 的动画实现方式，drawRect: 每一次动画改变都需要依赖新参数进行重绘，这就导致了主线程昂贵的 CPU 消耗。基于 CALayer 的动画就能避免这些消耗，因为 GPU 是直接根据 bitmap 进行绘制，GPU 会对 bitmap 进行缓存，这样能极大地节约 CPU 的性能消耗，提高效率。

通常 Core Animation 动画是实现复杂动画的首选，但是在降帧目的下，无法通过 Core Animation 将渲染帧率下降到 60FPS 以下。

### UIView animation block

UIView animation block 是根据 Core Animation 动画的封装，使用起来更加简洁。同时，UIView 提供 [UIViewAnimationOptionPreferredFramesPerSecond30](https://developer.apple.com/documentation/uikit/uiviewanimationoptions/uiviewanimationoptionpreferredframespersecond30) 属性，可以支持指定动画刷新频率为 30fps。

> 注：实际上 CoreAnimation 动画通过设置 CAAnimation 私有属性 preferredFramesPerSecond，也可以达到降帧的效果，具体可查看 [iOS-Runtime-Headers](https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/QuartzCore.framework/CAAnimation.h) 中的相关属性。

通过这个属性，可以很方便地实现降帧的目的，但是这个方案也并不是完美的，由于只支持了直线位移，所以当涉及到贝塞尔曲线位移的时候，需要手动计算贝塞尔曲线上的点，进行近似的位移。

### 利用 CADisplayLink 进行逐帧动画

CADisplayLink 是一个能让我们以和屏幕刷新率相同的频率将内容画到屏幕上的定时器，每次屏幕内容刷新结束时，runloop 就会向对应的 target 发送一次 selector 方法，selector 就会被调用一次。

相比另外两种定时器， NSTimer 精度稍低，并且延迟时间会逐渐累积，当 runloop 处于阻塞状态，NSTimer 的操作就会被推迟到下一个 runloop，很容易造成动画失控；而基于 dispatch_source_t 的定时器同样也不是百分百精确，如果 GCD 内部管理的所有线程都被占用时，其触发事件也将被延迟。

实际上使用 CADisplayLink 是一种终极方案，最终可以通过设置 CADisplayLink 的计时帧率来控制动画的帧率，不再只有 30 帧和 60 帧两个选项，能更好的适应多种情况，更好地平衡 GPU 占用率与用户体验。

但是基于 CADisplayLink 实现动画需要重写大量代码，工作量很大，具体可以参考 [Facebook - pop](https://github.com/facebookarchive/pop)，该库虽然不支持自定义帧率，但是已经完整实现了基于 CADisplayLink 的自定义动画。



## 五、测试方案与结论

### 最终方案

基于上面的各种原因，这次选用了 UIView animation block + UIViewAnimationOptionPreferredFramesPerSecond30 属性进行动画降帧的方案，可以较少改动代码而实现降帧的目的。

在这种方案下，如果本身动画使用的就是 UIView animation block，那么直接加上 UIViewAnimationOptionPreferredFramesPerSecond30 属性就可以了；如果基于 CoreAnimation 实现的动画，也能快捷地改造为 UIView animation block。

下面我们以进入抖音直播、在直播间内触发点赞动画为例子，进行对比测试：

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/digg.png?raw=true)

- 原本方案（60 FPS）：基于 Core Animation 的动画
- 降帧方案（30 FPS）：修改为 UIView animation block + UIViewAnimationOptionPreferredFramesPerSecond30

### 对帧率的影响

这张图是没做改动的情况，可以看到在直播间内疯狂触发动画时，会将 Core Animation FPS 打满，始终保持在 59 - 60 FPS。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/fps0.png?raw=true)

采用降帧方案后，可以看到帧率明显下降，整个 App 的 Core Animation FPS 能降低到 40 FPS 左右。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/iOSPreferredFPS/fps1.png?raw=true)

### 对 CPU & GPU 的影响

> 经过多次测试，将数据结论总结如下：

- 动画触发频率较低时：降帧方案能有效降低 GPU 占用率（下降 10%-20%），略微降低 CPU 占用率。
- 高频触发动画 or 长时间连续触发动画，超过一定临界时间之后：降帧方案下 GPU、CPU 占用率反而升高。
- 临界点有机器性能决定，低端机的临界时间也更短；对于较新机型，很难触及到临界时间，但对于 iPhone 6 来说，复杂的动画如果频率稍高一些，就会导致 GPU、CPU 占用率很快升高。

### 临界时间现象解释

从上面的数据结论可以发现，改造为 UIView animation block 方案之后，容易遭遇 CPU 瓶颈。

当 animation block 过多（每个动画需要的 block 过多✖️ 每秒触发的动画数过多 ✖️持续时间过长）而无法被消化时，会遭遇 CPU 瓶颈，导致 CPU、GPU 占用率反而升高。

对于这个现象暂时也没有发现具体的解释，不过我大概有如下的猜测：

- Block-based animation 的每一个 block 都会返回一个 UIViewAdditiveAnimationAction 类，用于 CALayer 动画的 actionForKey:  方法的回调。
- 与此同时，根据 block 中的具体内容生成对应的类，需要换算 fromValue 以及 toValue 等内容(不清楚换算是否在主线程实现，否则也可能造成线程爆炸)，比起直接基于 CoreAnimation keyFrames 的动画需要更多的 CPU 计算量。
- 因此，当 block 堆积过多，就可能会造成 CPU 负担过重。

### 总结

- 通过 PreferredFramesPerSecond30 属性能有效降低刷新帧率，从而降低 CPU、GPU 占用率
- 降低刷新帧率后，GPU 占用率下降比较明显，下降能达到 10%-20%
- 当 animation block 过多而无法被消化时，会遭遇 CPU 瓶颈，导致 CPU、GPU 占用率反而升高。且低端机更容易遭遇瓶颈。
