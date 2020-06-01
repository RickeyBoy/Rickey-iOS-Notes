# iOS 中的手势管理


# 第一步：IO Kit

### iOS 的系统架构

### 什么是 IOKit

iOS 操作系统看做是一个处理复杂逻辑的程序，不同进程之间彼此通信采用消息发送方式，即 IPC (Inter-Process Communication)。现在继续说上面电容触摸传感器产生的 Touch Event，它将交由 IOKit.framework 处理封装成 IOHIDEvent 对象；下一步很自然想到通过消息发送方式将事件传递出去，至于发送给谁，何时发送等一系列的判断逻辑又该交由谁处理呢？




---
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