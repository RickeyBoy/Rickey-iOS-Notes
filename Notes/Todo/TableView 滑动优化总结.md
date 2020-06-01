# TableView 滑动优化总结



https://juejin.im/post/5c85e145f265da2ddb299ac1

http://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/



## 步骤

1. 网络请求
2. 数据解析
3. 布局计算
4. cell 展示
   1. cell 创建









---



草稿！！！



## 耗时

2.统计了每次UITableView滚动时候比较耗时的操作

（1）布局计算

（2）生成富文本

（3）设置富文本

（4）图片加载动画

（5）数据存储到realm

   (6)  评论中回复列表计算高度



CPU 资源消耗原因和解决方案 + GPU



## 大致方向

- 前置
  - 预加载数据
  - 预创建视图
  - 预渲染
  - 当有图像时，预渲染图像，在bitmap context先将其画一遍，导出成UIImage对象，然后再绘制到屏幕，这会大大提高渲染速度。具体内容可以自行查找“利用预渲染加速显示iOS图像”相关资料。
  - 提前生成需要使用的富文本（UITextView 和 UILabel 对于富文本设置的时间）
- 异步
  - 异步计算高度
  - 异步计算布局：手动布局
  - 异步绘制 cell
  - 异步加载 url
  - 子线程剪切图片
  - 子线程解析模型？
- 按需加载
  - 快速滑动时只加载目标 cell
  - 快速滑动时取消多余图片请求
  - 页面跳转的时候，取消当前页面的图片加载请求；
  - 局部更新布局
  - 减少多余的绘制操作：在实现drawRect方法的时候，它的参数rect就是我们需要绘制的区域，在rect范围之外的区域我们不需要进行绘制，否则会消耗相当大的资源。
- 缓存
  - 高度缓存
  - 缓存网络请求结果？
  - 动画遮罩UIView使用Associate进行了保存。节约了 0.4-0.5ms
  - 调整资讯列表缓存到realm的策略，减少缓存到 realm 的内容
- 降低cell开销
  - 减少 subview 数量、视图层级、remove&addsubview 的操作（可以用 hidden）
  - calayer 代替 uiview
  - 离屏渲染问题
  - 颜色不要使用 alpha
  - 栅格化
  - 减少圆角等绘制，换成图片
  - opaque = YES
  - 不要将 `tableview` 的背景颜色设置成一个图片
  - 统一使用富文本显示文本，支持行高设置，提高了设计稿的还原度？？？
  - 自己绘制富文本并计算点击位：使用异步绘制富文本的bitmap图，并自己计算点击位置，可以提升渲染富文本的时间。
  - 异步线程生成图片最适合的bitmap图。图片展示到屏幕上，系统会在主线程中进行拉伸运算，计算出最适合当前视图大小的bitmap图。这个部分可以异步线程计算好，保存下来，直接使用。



## 具体



### 前置



### 异步



13.异步绘制

- (1)在绘制字符串时，尽可能使用 `drawAtPoint: withFont:`，而不要使用更复杂的 `drawAtPoint:(CGPoint)point forWidth:(CGFloat)width withFont:(UIFont *)font lineBreakMode:(UILineBreakMode)lineBreakMode`; 如果要绘制过长的字符串，建议自己先截 断，然后使用 `drawAtPoint: withFont:`方法绘制。
- (2)在绘制图片时，尽量使用 `drawAtPoint`，而不要使用 `drawInRect`。`drawInRect` 如果在绘 制过程中对图片进行放缩，会特别消耗 `CPU`。
- (3)其实，最快的绘制就是你不要做任何绘制。有时通过 `UIGraphicsBeginImageContextWithOptions()` 或者 `CGBitmapContextCeate()` 创建位图会显 得更有意义，从位图上面抓取图像，并设置为 `CALayer` 的内容。 如果你必须实现 `-drawRect:`，并且你必须绘制大量的东西，这将占用时间。
- (4)如果绘制 `cell` 过程中，需要下载 `cell` 中的图片，建议在绘制 `cell` 一段时间后再开启图 片下载任务。譬如先画一个默认图片，然后在 0.5S 后开始下载本 `cell` 的图片。
- (5)即使下载 `cell` 图片是在子线程中进行，在绘制 `cell` 过程中，也不能开启过多的子线程。 最好只有一个下载图片的子线程在活动。否则也会影响 `UITableViewCell` 的绘制，因而影响了 `UITableViewCell` 的滑动速度。(建议结合使用 `NSOpeartion` 和 `NSOperationQueue` 来下载图片， 如果想尽可能找的下载图片，可以把`[self.queuesetMaxConcurrentOperationCount:4];`)
- (6)最好自己写一个 `cache`，用来缓存 `UITableView` 中的 `UITableViewCell`，这样在整个 `UITableView` 的生命周期里，一个 `cell` 只需绘制一次，并且如果发生内存不足，也可以有效的 释放掉缓存的 `cell`。



### 按需加载

滑动时按需加载，这个在大量图片展示，网络加载的时候很管用!(`SDWebImage` 已经实现异 步加载，配合这条性能杠杠的)



### 缓存

现在是缓存前1000条，与安卓同学确认过，他们只存了首刷（10条）。

1000条的存储虽然是在异步线程中实行的，但是复制的过程在主线程中，会比较耗时。然后只改为首刷，存储让“刷新瞬间”耗时更短，帧数更高。



### 降低 cell 开销

`cell` 的 `subViews` 的各级 `opaque` 值要设成 YES，尽量不要包含透明的子 `View` `opaque` 用于辅助绘图系统，表示 `UIView` 是否透明。在不透明的情况下，渲染视图时需要快速 地渲染，以提􏰀高性能。渲染最慢的操作之一是混合`(blending`)。提􏰀高性能的方法是减少混合操 作的次数，其实就是 `GPU` 的不合理使用，这是硬件来完成的(混合操作由 `GPU` 来执行，因为这 个硬件就是用来做混合操作的，当然不只是混合)。 优化混合操作的关键点是在平衡 `CPU` 和 `GPU` 的负载。还有就是 `cell` 的 `layer` 的 `shouldRasterize` 要设成 `YES`。



2.UITextView大约0.3-0.5ms，UILabel 0.02-0.09ms
UITextView比UILabel速度慢，但是容易添加点击事件
可以点击的用UITextView，不能点击的用UILabel





---



## 代码层面

3.针对问题重新设计代码结构

将model和cell中转数据的代码进行抽离，然后抽离出一层viewModel

（1）model
单纯负责转换服务器数据
（2）viewmodel
A.转换数据 ：转换成cell直接可以使用的数据

B.计算各个视图位置frame

C.保存数据：保存转换数据和各个视图位置frame数据

（3）cell

只负责将viewmodel的数据渲染到屏幕上





按需加载对应 cell 解决办法:

1. `cell`每次被渲染时，判断当前`tableView`是否处于滚动状态，是的话，不加载图片；
2. `cell` 滚动结束的时候，获取当前界面内可见的所有`cell`
3. 在`2`的基础之上，让所有的`cell`请求图片数据，并显示出来