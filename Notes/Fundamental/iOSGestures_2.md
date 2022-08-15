# iOS 中的手势传递（一）App 层



# 第五步：App 内的事件传递



### UIEvent、UITouch、UIResponder、UIGestureRecognizer

接下来进入到我们相对熟悉的阶段了，即手势事件在 app 内部流通的阶段。那么我们先区分一下几个常见的概念：

**UITouch**

> [UITouch | Apple](https://developer.apple.com/documentation/uikit/uitouch?language=objc)

顾名思义，UITouch 对应一个手指的触摸信息。每一个 UITouch 对象会包含下列信息：

- 触摸发生的 view 或者 window
- 触摸在 view 或 window 中相对的位置
- 触摸半径（近似）
- 触摸的力度（需要设备支持 3D Touch 或者 Apple Pencil）
- 触摸的时间点
- 触摸的进行阶段（began、moved、ended、canceded）

**UIEvent**

> [UIEvent | Apple](https://developer.apple.com/documentation/uikit/uievent?language=objc)

UIEvent 对象包含了单个用户的交互操作信息，不只是触摸事件，还有其他比如锁屏、音量、远程控制等系统事件。而触摸事件是其中最常见的事件。对于触摸事件，每个 UIEvent 都包含一个或多个触摸信息（即包含一个或多个 UITouch 对象）。

需要注意的是，当多个连续触摸事件发生时，UIKit 会重复使用同一个 UIEvent 对象来分发不断更新的触摸信息，因此不应该强持有 UIEvent（以及 UITouch），如果需要记录其数据只能进行先复制。

**UIResponder**

> [UIResponder | Apple](https://developer.apple.com/documentation/uikit/uiresponder?language=objc)

UIResponder 是用于进行事件响应的抽象接口，而 UIResponder 对象包含绝大多数主要的类比如 UIApplication、UIViewController、UIView（包含 UIWindow）。当事件发生，即新的 UIEvent 信息由底层传递而来，这些对象能够通过 UIKit 实现对事件的监听和处理。

**UIGestureRecognizer**

> [UIGestureRecognizer](https://developer.apple.com/documentation/uikit/uigesturerecognizer?language=objc)

UIGestureRecognizer 是承载具体手势的基类。UITouch 和 UIEvent 等已经包含了足够多开发过程中需要的信息，但是这些信息过于丰富和离散，因此 UIGestureRecognizer 出现的主要目的就是进行逻辑的解耦：当有连续或独立的触摸事件发生时，UIGestureRecognizer 会根据 UITouch 中的信息进行初步判断，将手势分类、封装。

识别出来的手势会被封装为不同的手势识别类（比如 [UITapGestureRecognizer](https://developer.apple.com/documentation/uikit/uitapgesturerecognizer?language=objc) 单击手势类），这些手势类的基类就是 UIGestureRecognizer。







---

### 参考文献

- [计算机组成原理——原理篇 IO（上）- 小萝卜鸭](https://www.cnblogs.com/wwj99/p/12852344.html)
- [Projected-Capacitive Touch Technology](http://large.stanford.edu/courses/2012/ph250/lee2/docs/art6.pdf)
- [Apple - IOKit-fundamentals](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Introduction/Introduction.html)
- [Apple - IOKit Fundamentals - I/O Kit Family Reference](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Families_Ref/Families_Ref.html#//apple_ref/doc/uid/TP0000021-BABCCBIJ)
- [PhoneWiki - IOHIDFamily](https://iphonedev.wiki/index.php/IOHIDFamily)
- [深入浅出iOS系统内核（1）— 系统架构 — darcy87)](https://www.jianshu.com/p/029cc1b039d6)
- [PhoneWiki - GSEvent](https://iphonedevwiki.net/index.php/GSEvent)
- [PhoneWiki - backboardd](https://iphonedev.wiki/index.php/Backboardd)
- [Chapter 4. Event Handling and Graphics Services](https://www.oreilly.com/library/view/iphone-open-application/9780596155346/ch04.html)
- [Apple - main event loop](https://developer.apple.com/library/archive/documentation/General/Conceptual/Devpedia-CocoaApp/MainEventLoop.html)
- [深入理解RunLoop - ibireme](https://blog.ibireme.com/2015/05/18/runloop/)
- [xybp888/iOS-Header - UIEvent.h](https://github.com/xybp888/iOS-Header/blob/master/13.0/PrivateFrameworks/UIKitCore.framework/UIEvent.h)
- [iOS App Life Cycle - Xiao Jiang](https://medium.com/@neroxiao/ios-app-life-cycle-ec1b31cee9dc#:~:text=The%20Main%20Run%20Loop,on%20the%20app's%20main%20thread.)
- [iOS 从源码解析Run Loop (九) - 鳄鱼不怕_牙医不怕](https://juejin.cn/post/6913094534037504014)
- [iOS RunLoop应用分析—原来这些都在使用RunLoop - 小小小_小朋友](https://juejin.cn/post/7056282331132198919)






































### 重要参考
iOS触摸事件全家桶 https://juejin.im/entry/59a7b6e4f265da246f381d37#comment
iOS Touch Event from the inside out https://www.jianshu.com/p/70ba981317b6
iOS 中的事件响应与处理 https://blog.boolchow.com/2018/03/25/iOS-Event-Response/
深入理解RunLoop https://blog.ibireme.com/2015/05/18/runloop/
main event loop - Apple https://developer.apple.com/library/archive/documentation/General/Conceptual/Devpedia-CocoaApp/MainEventLoop.html
Stackoverflow 关于 Gesture 传递过程!!!：https://stackoverflow.com/questions/22116698/does-uiapplication-sendevent-execute-in-a-nsrunloop



---

[手势管理方案！！ - Rickey]


https://alanli7991.github.io/2017/05/20/Gesture%E5%92%8CUIControl%E8%A7%A6%E5%8F%91%E9%A1%BA%E5%BA%8F/

or: 

```
[self.buttonGroupView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(p_blockGesture)]]; // 隔离 button 与底层的手势
```



UIView的hitTest和pointInside方法 https://www.jianshu.com/p/c87de31b3985



### SpringBoard.app

答案是 SpringBoard.app，它接收到封装好的 IOHIDEvent 对象，经过逻辑判断后做进一步的调度分发。例如，它会判断前台是否运行有应用程序，有则将封装好的事件采用 mach port 机制传递给该应用的主线程。

Port 机制在 IPC 中的应用是 Mach 与其他传统内核的区别之一，在 Mach 中，用户进程调用内核交由 IPC 系统。与直接系统调用不同，用户进程首先向内核申请一个 port 的访问许可；然后利用 IPC 机制向这个 port 发送消息，本质还是系统调用，而处理是交由其他进程完成的。




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

