# interactivePopGestureRecognizer 导致页面卡死

### interactivePopGestureRecognizer 的使用

interactivePopGestureRecognizer 是系统为 UINavigationController 添加的右滑 pop 手势，由系统提供返回动画，实现边缘返回功能。

```cpp
@property(nullable, nonatomic, readonly) UIGestureRecognizer *interactivePopGestureRecognizer API_AVAILABLE(ios(7.0)) API_UNAVAILABLE(tvos);
```

navigation controller 会将手势加在其 view 上，并负责将最上层 ViewController 从 navigation stack 中移除。

因为这个手势是加在 navigation controller 上的，手势的 enable 状态是 stack 中所有 ViewController 共享的，因此如果我们想针对某个 VC 禁用 interactivePopGestureRecognizer，我们可能通常会这样做 ---- 在 willAppear 和 willDisappear 的生命周期中进行设置：

```cpp
- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];   
  self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}
- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}
```



### 页面卡死的产生

这样的做法会导致一个非常严重的卡死 bug，具体路径如下：

1. FirstViewController 在 willAppear 时设置手势 enable = NO；

2. [FirstViewController  push: SecondViewController]

3. FirstViewController 在 WillDisappear 时设置手势 enable = YES；

4. 在 SecondViewController 中尝试使用边缘手势，页面卡死，无法响应任何手势

为什么在新 push 出来的 SecondViewController 中尝试使用边缘手势就会造成卡死呢，原因在于此时同时触发了两件事情：

1. 边缘手势 interactivePopGestureRecognizer 开始响应，将 SecondViewController 从 navigation stack 中移除

2. FirstViewController willAppear 被调用，interactivePopGestureRecognizer.enabled = NO，那么正在响应的手势操作将会被中断掉。

> @property(nonatomic, getter=isEnabled) BOOL enabled;  // default is YES. disabled gesture recognizers will not receive touches. when changed to NO the gesture recognizer will be cancelled if it's currently recognizing a gesture

> 如果设置为 NO，将 cancel 正在响应的手势

这样的结果就是系统的 interactivePopGestureRecognizer 生命周期被破坏，SecondViewController 被从 stack 中移除，但是其 view 却仍留在最顶层，并且无法再响应任何手势。这样的现象就是看起来什么都没有发生，但是 SecondViewController 实际上已经被移除了，表现为页面直接卡死。



### 两种解决方式

知道了原因之后解决方案就变得非常简单了，延缓手势被禁用的时机即可。在 DidAppear 的时候禁用，就可以避免上述的冲突：

```cpp
- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}
```

当然，也可以通过其他的方式在 FirstViewController 中禁用边缘手势，比如通过 shouldBegin 方法过滤，这样也能避免冲突：
> 此方案参考：https://stackoverflow.com/a/21424580
```cpp
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)] &&
      gestureRecognizer == self.navigationController.interactivePopGestureRecognizer) {
    return NO;
  }
  return YES;
}
```