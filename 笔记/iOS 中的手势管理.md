# iOS 中的手势管理

# 第一步：I/O Kit

### 手机触屏原理

我们首先来讲讲触摸手势最开始在物理层面上是如何被触发和检测的。

手机屏幕实现触屏的原理大概有分为两种，电容屏和电阻屏；其中电容屏虽然价格更为昂贵，但精度更高，可实现多点触控，以及保护、清洁都更方便，因此也是主流的方案。

![capacitor](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/capacitor.png)

电容屏的大概原理简单来说，整块屏幕就是一个大的电容器。根据中学物理知识，电容器实际上就是一个储存电荷的电子元件，人体也可以传导微弱的电流；当人的手指触碰到电容器，人的手指就会变成电容器的一极，部分的电荷就会从人的手指处流失，从而被屏幕探测到触摸动作。

> 注 1：这也是为什么冬天戴手套时无法使用触摸屏幕的原因，因为绝大部分手套是绝缘体，无法成为电容器的一极，不会产生电荷的流动，因此无法被电容屏探测到触摸操作。
>
> 注 2：而有些安卓手机设置有手套模式，戴着手套也能使用触屏。这个主要是因为当电压足够的情况下，电荷的传到也能穿透一定的绝缘电阻。因此开启了手套模式后，电容屏功率加大，即使戴着较薄手套，也能产生电荷的转移。

而 iPhone 采用的是投射电容（Projected-Capacitive）式电容屏，一共主要有四层，一层触摸层，两层导电层，和一层隔离层，大致结构如下：

![ProjectedCapacitive](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/ProjectedCapacitive.png)

其中最上层透明的 touch surface 是触摸层，主要起保护作用，避免手指直接接触到下层结构。绿色 ITO 是导电玻璃层，中心黄色是绝缘层，这三层结构就构成了电容器。当手指触碰到触摸层时，就会产生电荷从电容器到人手指的转移，从而被屏幕捕获。

> 注：有些时候除了这些结构，最下层还会有额外的一层 ITO 导电玻璃层，主要用于减少显示屏的噪声（LCD noise）。

而屏幕如何捕获具体的触摸坐标呢？实际上刚才说的两层 ITO 导电玻璃，分别负责探测触摸点的横纵坐标：

![diamond](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/diamond.png)

参考上图，两层分别都按横纵方向分布有联锁钻石（Interlocking Diamonds）形状，分别负责探测触摸点的横纵坐标，两者结合之后可以计算出具体的触摸点坐标。

### CPU 架构与 I/O 总线

其实看完上一小节，我们知道手机触摸屏对于系统内核来说，实际上就是一个外接的物理设备。而这个设备是如何与 CPU 连接起来的呢，这就要从计算机组成与 I/O 总线说起。在现代 CPU 架构中有一个总线（Bus）的概念，用于数据的传输：

![](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/Bus.jpg)

在物理层面上，总线可以被拆分为三条线路，分别是数据线（Data Bus）、地址线（Address Bus）和控制线（Control Bus）。分别用于数据的传输、地址的索引，以及具体传输操作的控制。在这样的结构支持下，总线连接的各个设备之间，通过”上下车“的机制，就能将需要数据在各个设备中传递。

而在现代 CPU 的架构中，存在多个总线结构，主要包括系统总线、内存总线和 I/O 总线，整体结构大概如下所示：

![](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/IOBus.jpg)

从图中可以看到，I/O 总线连接了各个设备，对于计算机来说就是诸如键盘鼠标、显示器、硬盘等；另一方面它与 I/O 桥接器（I/O Bridge）相连，就能完成设备与 CPU、内存的数据连通了。

### 什么是 I/O Kit

经过了上面的说明，大概能知道 I/O Kit 的作用是什么了。

> The I/O Kit is a collection of system frameworks, libraries, tools, and other resources for creating device drivers in OS X. It is based on an object-oriented programming model implemented in a restricted form of C++ that omits features unsuitable for use within a multithreaded kernel. By modeling the hardware connected to an OS X system and abstracting common functionality for devices in particular categories, the I/O Kit streamlines the process of device-driver development.
>
> -- [Apple Documentation](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Features/Features.html#//apple_ref/doc/uid/TP0000012-TPXREF101)

根据 [Apple](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Features/Features.html#//apple_ref/doc/uid/TP0000012-TPXREF101) 的官方文档，I/O Kit 简单来说就是连接系统与硬件的中间结构。它能提供以及简化在 OS X 系统上依赖硬件的开发过程，以及支持 iOS 的底层调用。虽然对于 iOS 来说通过 I/O Kit 进行内核编程的机会非常有限，但是也有通过其实现对电池电量监控的相关实践。

也因此可想而知，其实 I/O Kit 所处的位置应该位于系统较为底层的地方。对于 iOS 系统（以及 OS X）来说，如图所示，大概可以分为下面四层。其中操作系统核心 Darwin 包含内核和 UNIX shell 环境，I/O Kit 也位于其中。

![4layers](/Users/rickey/Desktop/Swift/Rickey-iOS-Notes/backups/iOSGesture/4layers.png)

### I/O Kit Family

I/O Kit 中所有类的祖先都是 OSObject 类，而苹果定义了一些设备的 Family（"族"），都继承于 OSObject，分别实现了一些通用的驱动程序。这样说起来还是有点抽象，说一些常见的族就大概能理解了：

> 参考：[IOKit Fundamentals - I/O Kit Family Reference](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Families_Ref/Families_Ref.html#//apple_ref/doc/uid/TP0000021-BABCCBIJ)

- IOUSBFamily：通用 USB 设备
- IOAudioFamily：所有音频设备
- IONetworkingFamily：提供对无线网络连接的支持
- IOGraphicsFamily：通用图形适配器，支持屏幕显示

而我们需要关注的是 IOHIDFamily，他的全称是 Human Interface Device。根据官方文档的说明：

>  The Graphics family provides support for frame buffers and display devices (monitors).







---
682 iOS family

[深入浅出iOS系统内核（1）— 系统架构](https://www.jianshu.com/p/029cc1b039d6)

[IOKit-fundamentals](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Introduction/Introduction.html)

IOHIDEvent:https://github.com/kennytm/iphone-private-frameworks/blob/master/IOKit/hid/IOHIDEvent.h

### SpringBoard.app

答案是 SpringBoard.app，它接收到封装好的 IOHIDEvent 对象，经过逻辑判断后做进一步的调度分发。例如，它会判断前台是否运行有应用程序，有则将封装好的事件采用 mach port 机制传递给该应用的主线程。

Port 机制在 IPC 中的应用是 Mach 与其他传统内核的区别之一，在 Mach 中，用户进程调用内核交由 IPC 系统。与直接系统调用不同，用户进程首先向内核申请一个 port 的访问许可；然后利用 IPC 机制向这个 port 发送消息，本质还是系统调用，而处理是交由其他进程完成的。

### Rickey's app runloop



### IOHIDEvent -> UIEvent




### UIApplication -> UIWindow -> Responder chain




### UITouch 、 UIEvent 、UIResponder




### 手势冲突与处理




### 事件的生命周期

系统响应、进程响应 、事件传递

1. IOKit、spring board
2. 进程
3. runloop source
4. UIwindow
5. GestureRecognizer & HitTest





---



[iOS Touch Event from the inside out](https://www.jianshu.com/p/70ba981317b6)

---

[iOS 触摸事件全家桶 - 掘金](https://juejin.im/entry/59a7b6e4f265da246f381d37)

- 触摸事件由触屏生成后如何传递到当前应用？<事件的生命周期>
- 应用接收触摸事件后如何寻找最佳响应者？实现原理？
- 触摸事件如何沿着响应链流动？
- 响应链、手势识别器、UIControl之间对于触摸事件的响应有着什么样的瓜葛？

[处理手势冲突和错乱的一些经验](http://yulingtianxia.com/blog/2016/08/29/Some-Experience-of-Gesture/)

[各种点击事件的关系](https://juejin.im/post/5bd142fdf265da0a8b576417)

[黄文臣-七种手势详解](https://blog.csdn.net/Hello_Hwc/article/details/44044225)


### 参考文献

- [计算机组成原理——原理篇 IO（上）- 小萝卜鸭](https://www.cnblogs.com/wwj99/p/12852344.html)
- [Projected-Capacitive Touch Technology](http://large.stanford.edu/courses/2012/ph250/lee2/docs/art6.pdf)
- [IOKit-fundamentals](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Introduction/Introduction.html)

