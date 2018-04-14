# WWDC 2017 ARKit 笔记 - Augmented Reality for iOS

 ![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a4e4d44aedb5.jpg){:height="200pt" weight="2"}

作者最近刚刚开始潜心研究 ARKit，本文是 [WWDC 2017 - Introducing ARKit: Augmented Reality for iOS](https://developer.apple.com/videos/play/wwdc2017/602/) 的笔记，夹杂一些个人的理解和拓展，如果有欠妥的地方，欢迎大家指正啊！

### 一、ARKit 的三层结构

![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a9924816b9d0.jpg)

##### 1. Tracking

Tracking 是 ARKit 的核心功能，主要是对 iOS 设备进行实时的追踪。其中 **World tracking** 用于追踪换算设备在现实世界环境中的实时位置。**Visual inertial odometry 视觉惯性测程 VIO**，它的功能在于感知设备在现实世界中的运动轨迹以及位置。**VIO** 利用的是摄像头 `Camera Sensor`、陀螺仪和加速计 `CoreMotion` 的数据，然后计算出设备移动的高精度的轨迹和位置，这一点其实也可以从其名字推断出来。另一个重要特点是 **No external setup**，无需额外的传感器设备，手机自带的已经足够，同时也不需要对底层进行 Tracking 的细节有过多的理解。

##### 2. Scene Understanding

Scene Understanding 指的是 ARKit 对现实环境中周围物体特征的捕获能力。 **Plane detection** 是指 ARKit 探测平面的能力，诸如探测地面、桌面等。**Hit-Testing** 功能用于将虚拟物放置于物理世界中。**Light estimation** 功能将根据物理世界中光线状况渲染到虚拟物上，使得效果更加逼真。

##### 3. Rendering

**Easy integration** 指 `Camera Images`、`Scene Understanding`、`Tracking Information` 均可以作为输入信息，被渲染并最终呈现。如果 Rendering 使用的是 `SceneKit` 或者是 `SpriteKit`，那么可以使用系统提供的自定义 **AR Views**，已经自动为使用者进行了渲染，使用起来非常方便。而如果要进行自定义渲染 **Custom Rendering**，那么苹果也提供了 `Metal` 来进行渲染。

![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a4f167b71d02.jpg)

总体来说，一个 ARKit 的 App 的主要组成部分就是 Processing + Rendering。其中 Processing 由 ARKit 完成，主要依赖 `AVFoundation` 和 `CoreMotion` 完成内容捕捉、定位轨迹等工作。而 Rendering 可以选择 `SceneKit`、`SpriteKit` 或者 `Metal`。

### 二、ARKit 的使用方法

![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a512050dec4a.jpg)

ARKit 是基于会话的 API，由 `ARSession` 控制所有相关线程。接下来，由 `ARSessionConfiguration` 决定采用什么样的 tracking 方式。换句话说，也就是通过设置其不同的属性，可以让 `ARSession` 运行不同的线程，以及采取不同的 **Scene Understanding** 的方式。与之前提到 **Scene Understanding** 相对应的是，`ARSessionConfiguration` 的数据来源分别是 `AVCaptureSession` 以及 `CMMotionManager`。而启动 `ARSession` 的方式非常简单，直接调用 `Run(_ configuration)` 即可。

而 `ARSession` 的输出是 `ARFrame`，本质上就是一系列截图，而每一帧的截图接下来都会被送去 `Rendering`。获取 `ARFrame` 的方式有两种，一种是直接调用 `currentFrame` 属性，另一种就是通过设置 `ARSession` 的 delegate。

### 三、ARKit 的四个 Classes

![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a5185650b915.jpg)

其实前三个类在之前都已经有所提及，理解起来也是比较容易。那么接下来稍微说一下第四个类 `ARAnchor` 

##### ARAnchor

> A real-world position and orientation that can be used for placing objects in an AR scene.

`ARAnchor` 类是真实世界的坐标和方向。在 AR 场景中，使用 ARAnchor 类提供的方向和位置来放置虚拟特征。其实如果类比 CALayer 中的 `Anchor`，`ARAnchor` 就相当于空间物体的 3D 锚点。`ARFrame` 用于捕获相机的移动，其他虚拟物品就用 `ARAnchor`。

### 四、详解 Tracking

Tracking 是指探测物体在空间中的具体位置。Tracking 是 ARKit 的基础，因为我们必须要实时探测到真实物体的位置，这样才能在设备移动、旋转时，仍能保证进行正确的渲染。ARKit 对应提供了 **World Tracking**，使用 **Virtual Intertial Odometry** 技术。

**World Tracking** 能提供如下的信息：

- Position and orientation 设备的相对位置和方向
- Physical distances 物理距离，即以真实长度单位反映现实世界的规模（real-world scale）

那么 **World Tracking** 是如何工作的呢？主要是依靠 3D-feature points，它指的是 ARKit 识别出来的真实平面上的空间点，这些点是进行物体探测的基础。在设备移动的过程中，利用摄像头捕获的图像信息，识别出 3D-feature points，根据它们的相对位置移动，再加上设备本身的陀螺仪和加速计的数据，就能还原出设备的空间位置和运动轨迹。

![](http://p6z7avd1u.bkt.clouddn.com/image/blog/5a9a415b968f7.jpg)

在使用时，`AVCaptureSession` 获取视频图像数据，`CMMotionManager` 以更高的频率获取设备陀螺仪和加速计的数据，而二者结合之后 `ARSession` 计算获得设备的空间位置信息（即每一帧的 `ARFrame`）。

##### Tracking Quality
- Uninterrupted sensor data：传感器信息不能被打断，否则 tracking 也将停止
- Textured environments：需要一定的图像复杂度来进行特征分析。比如只是面对一面白墙，那么就无法进行 tracking
- Static scenes：tracking 需要尽量保持图像稳定

![](http://p6z7avd1u.bkt.clouddn.com/18-4-11/21104799.jpg)

如上图所示，Tracking state 一共有三种状态，最开始是 Not Available，一段时间后可以进入到 Normal 状态。如果 tracking 效果不好的话，有可能会出现 Limited 状态，此时可以在 UI 层面告知用户当前的效果并不好。而在 ARKit 中，提供了如下方法来判断当前的 state：

```swift
func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) { 
    if case .limited(let reason) = camera.trackingState {
        // Notify user of limited tracking state
        ...
    } 
}
```

#####  Tracking Interruption
Tracking 的过程中是有可能被打断的，原因有下面两类，分别是相机不可用和 tracking 被终止。
- Camera input unavailable
- Tracking is stopped

### 四、详解 Scene Understanding
这一部分主要目的是将 AR 中的虚拟物品呈现在现实世界中，需要考虑空间位置信息、光线情况等。第一步，就是要进行 Plane detection 平面检测，找到能够放置物体的平面。第二步，是进行 Hit-testing，来找到放置物体的具体位置坐标。最后，Light estimate 渲染虚拟物体，使得光影更加真实。

Plane Detection 基于重力探测水平面，设备在后台



