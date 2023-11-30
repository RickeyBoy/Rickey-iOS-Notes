# SwiftUI 弹出键盘不影响布局

> 关于我：大厂摸鱼 + 业余独立开发，之后会输出深度技术文章 + 独立开发技巧
>
> 我的往期技术文章合集：[RickeyBoy - Gitbub](https://github.com/RickeyBoy/Rickey-iOS-Notes)
>
> 我的独立开发 App：[iColors - 设计灵感 配色助手](https://apps.apple.com/app/id6448422065)

今天来讲一个简单又实用的细节，如何在 SwiftUI 中避免因为键盘弹起，而影响页面布局的方法。



## 实现效果

> 就以我的独立 App 中的一个场景为例：在自制色卡后，需要给色卡命名，这时需要弹起键盘

| 优化前                                              | 优化后                                            |
| --------------------------------------------------- | ------------------------------------------------- |
| 键盘弹起后，背景布局受影响                          | 键盘弹起后，不影响其他布局                        |
| ![before](../../backups/SwiftUIKeyboard/before.gif) | ![after](../../backups/SwiftUIKeyboard/after.gif) |



## 实现方案

先看看原本的布局代码，非常简单的一个 VStack 结构

```swift
VStack() {
    ImageContent() // 中央核心内容
}
```

想要避免键盘弹起影响布局，需要使用 `.ignoresSafeArea(.keyboard, edges: .bottom)`，当然，需要添加到 VStack 的外层：

```swift
VStack() {
    ImageContent() // 中央核心内容
}
.ignoresSafeArea(.keyboard, edges: .bottom)
```

不过这种情况下测试，发现并没有修复原有的问题。经过调查发现，除了使用 `ignoresSafeArea(.keyboard)` 之外，还需要**确保目标视图占据全屏！**

比如，下面这样利用 Spacer，就可以了：

```swift
// 方法 1：通过 Spacer() 撑满全屏
VStack() {
    Spacer()
    ImageContent() // 中央核心内容
    Spacer()
}
.ignoresSafeArea(.keyboard, edges: .bottom)
```

还有一种更巧妙一点的方法，使用 `GeometryReader`，这样可以避免需要添加 Spacer 而造成的布局调整

```swift
// 方法 2：利用 GeometryReader 包裹一层
GeometryReader { _ in
  VStack() {
      ImageContent() // 中央核心内容
  }
}
.ignoresSafeArea(.keyboard, edges: .bottom)
```

