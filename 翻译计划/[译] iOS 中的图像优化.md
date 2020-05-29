# 图像优化

人们总说最好的相机就是你随身携带的相机。如果这句话说得通，那么毫无疑问 —— iPhone 完全就是世界上最重要的相机。这一点从当下的产业现状也可以得到印证。

在度假？如果你没有抓拍几张照片记录到 Instagram 上面，那等于没度假。

大消息？看看 Twitter 上哪些媒体通过发布快照来报道实时发生的事情吧。

等等。

但是由于图片在整个 iOS 平台无处不在，所以仅仅做到能够展示它们，并且只用传统的内存管理方式进行管理的话，很容易导致管理混乱。而只要对 UIKit 的内部运行原理有一点了解，知道为什么它要这样处理图片的话，任何人都能大幅节省内存开销，并且停止频繁触发的 jetsam 报警。



## 原理

小测试 —— 我可爱女儿这张 266KB（并且活力四射）的照片在一个 iOS 应用中需要占多少内存？

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/swiftGGVision/baylor.jpg?raw=true)

剧透一下 —— 答案不是 266KB，也不是 2.66MB，而是差不多 14MB。

为什么？

iOS 本质上是根据图片的尺寸来分配内存 —— 而和图片文件本身的大小没什么关系。这张照片的尺寸是宽 1718 像素 2048 像素高，假设每像素要占用 4 字节的话：

```
1718 * 2048 * 4 / 1024 / 1024 = 13.42MB 左右
```

假设你有一个显示用户的 UITableView 列表，每一行左侧都用现在非常普遍的圆形头像来显示用户们的照片。如果你认为这实现起来很简洁，因为每张图片都已经被 ImageOptim 或者类似的库封装好了，那可能和接下来所说的这种情况不太一样。但如果每张照片都还是传统的 256 x 256 大小的样式，那么你确实可以好好说道说道内存优化。



## 渲染流程

说了这么多，总结起来就是 —— 了解深层原理是非常有价值的。当你加载一张图片时，会进行这三个步骤：

1) **Load 加载** —— iOS 获取到压缩过的图片，并且将这（以文中的图片为例）266KB 加载到内存中，此时还没什么需要担心的。

2) **Decode 解码** —— 此时 iOS 会将图片转换为 GPU 可以读取和识别的格式。这时图片是未压缩状态，处于上文说的占用了 14MB 大小的时刻。

3) **Render 渲染** —— 如字面意思一样，图片数据已经准备好以任何方式渲染出来了，即便只是被一个 60 x 60pt 的 UIImageView 渲染。

解码阶段是占内存最大的一部分。这里 iOS 创造了一个缓存 —— 具体说就是图片缓存（image buffer），它是图片表现形式存于内存中的位置。上述流程说明了，解码过程所占内存的大小，本质上和图片本身尺寸密切相关，而和图片文件大小无关。这清楚地描述了处理图片的过程中，为什么说到内存损耗时，图片尺寸是最重要的。

尤其是对于 `UIImage`，当我们从图片网络或者其他途径获取到图片数据，并将数据设置给它的时候，它会根据图片数据被压缩后的格式（可能是 PNG 或 JPEG）将其解码到缓存中。只不过，`UIImage` 实际上也会持有缓存，因为渲染不是一次性操作，所以 `UIImage` 会持有图片缓存，这样就只用进行一次解码操作。

在此基础上进一步说 —— 帧缓存（frame buffer）是任何一个 iOS app 都不可或缺的一种缓存。帧缓存负责将你的 iOS app 真正地显示在设备屏幕上，因为帧缓存保存了 iOS app 经过渲染之后的内容。所有 iOS 设备上的显示硬件，都是利用帧缓存中的像素信息，将所有像素准确显示到物理屏幕上。

在这种情况下，时机就显得尤为重要。要得到每秒 60 帧黄油般的丝滑滚动效果，就需要在帧缓存内容发生改变时（例如给 UIImageView 设置了一张图片），让 UIKit 重新绘制 app 的窗口以及接下来的子视图。如果这个过程太慢，那么就会发生丢帧的情况。

> 1/60 秒一帧在时间上过于紧迫了？画质卓越的设备已经提升到 1/120 秒一帧了。



## 大小很重要

我们可以轻易地想象出内存被消耗的这个过程。我用我女儿的照片，写了一个简易 app ，是一个内部显示了具体图片的 UIImageView：

```Swift
let filePath = Bundle.main.path(forResource:"baylor", ofType: "jpg")!
let url = NSURL(fileURLWithPath: filePath)
let fileImage = UIImage(contentsOfFile: filePath)

// Image view
let imageView = UIImageView(image: fileImage)
imageView.translatesAutoresizingMaskIntoConstraints = false
imageView.contentMode = .scaleAspectFit
imageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
imageView.heightAnchor.constraint(equalToConstant: 400).isActive = true

view.addSubview(imageView)
imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
```

> 实际工作中要注意对强制解析的使用，我们这里只是采取了一个简单的演示方案。

上述代码能得到：

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/swiftGGVision/baylorPhone.jpg?raw=true)



使用 LLDB 我们就能很快得到正在使用的图片的真实尺寸，即使我们使用了远小于原图尺寸的 UIImageView 去呈现它：

```swift
<UIImage: 0x600003d41a40>, {1718, 2048}
```

别忘了 —— 这里的单位是 *pt*，所以在 2x 或者 3x 的设备上可能还需要乘以一定的系数，导致结果更大。我们快用 `vmmap` 试试，看下我们能否确认这一张照片就用掉了 14 MB 左右：

```
vmmap --summary baylor.memgraph
```

有一部分结果相当显眼（为简洁而做了截取）：

```swift
Physical footprint:         69.5M
Physical footprint (peak):  69.7M
```

现在我们用了接近 70MB，这给了我们一个很好的基准，可以以此对比确认重构的效果。如果我们用 grep 语句针对 Image IO 具体查看，我们就能看到图片某些方面的开销：

```
vmmap --summary baylor.memgraph | grep "Image IO"

Image IO  13.4M   13.4M   13.4M    0K  0K  0K   0K  2 
```

啊 —— 有差不多 14 MB 的内存脏数据，这正符合我们之前快速估计出的图片开销的结果。再多说明一下，这有一个命令行的截图，可以清楚地说明 grep 语句结果中省略掉的每一列的含义。

![](https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/backups/swiftGGVision/vmmap.jpg?raw=true)


显然，即使我们使用 300 x 400 大小的 UIImageView 来呈现图片，这部分开销也和原始尺寸的图片一样。不过图片尺寸虽然关键，但并不是全部因素。



## 色域

你请求的内存大小部分取决于另一个重要因素 —— 色域。上述例子中我们所做的假设 —— 图片都是使用 sRGB 格式，每像素占用 4 字节，其中红、蓝、绿、透明度每个通道各用 1 字节来表示，但这可能不符合大多数 iPhone 的情况 。

如果你正在使用一个支持广色域格式的设备（比如 iPhone 8+ 或者 iPhone X），那么你差不多能将全部开销直接翻倍。当然，反之亦然，比如 Metal 框架可以使用 Alpha 8 格式的图片，根据名字就可以推断这种格式只有一个透明度通道。

管理和考究色域的影响都非常麻烦，这就是你应该使用 [UIGraphicsImageRenderer](https://swiftjectivec.com/UIGraphicsImageRenderer) 而不是 `UIGraphicsBeginImageContextWithOptions` 的原因。后者*只能*使用 sRGB 格式，意味着你无法[使用广色域](https://instagram-engineering.com/bringing-wide-color-to-instagram-5a5481802d7d)，或者损失进一步压缩内存的机会。截至 iOS 12，`UIGraphicsImageRenderer` 会自动帮你选择合适的色域格式。

大家别忘了，很多出现的图片并不是那些各式各样的摄影作品，而是一些琐碎的绘图操作。我不是故意重复最近写过的内容，只是以防你错过了：

```swift
let circleSize = CGSize(width: 60, height: 60)

UIGraphicsBeginImageContextWithOptions(circleSize, true, 0)

// 画一个圆
let ctx = UIGraphicsGetCurrentContext()!
UIColor.red.setFill()
ctx.setFillColor(UIColor.red.cgColor)
ctx.addEllipse(in: CGRect(x: 0, y: 0, width: circleSize.width, height: circleSize.height))
ctx.drawPath(using: .fill)

let circleImage = UIGraphicsGetImageFromCurrentImageContext()
UIGraphicsEndImageContext()
```

上面这个圆形图片用的是每像素 4 字节的格式。但如果你使用 `UIGraphicsImageRenderer`，允许渲染器自动优化选择最正确的格式，这个方法能达到最多 75% 的内存节省，即选择每像素只占用 1 字节的格式：

```swift
let circleSize = CGSize(width: 60, height: 60)
let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: circleSize.width, height: circleSize.height))

let circleImage = renderer.image{ ctx in
    UIColor.red.setFill()
    ctx.cgContext.setFillColor(UIColor.red.cgColor)
    ctx.cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: circleSize.width, height: circleSize.height))
    ctx.cgContext.drawPath(using: .fill)
}
```



## 缩小尺寸 vs 降采样

说明了简单的绘图情况之后 —— 还有大量我们设想的那种摄影照片导致的问题，以及它们对内存造成的影响，比如人像照片、风景照等等。

正如部分工程师所认为的（并且逻辑上也确实如此），简单地用 `UIImage` 将原始图片缩小尺寸（downscaling）就可以了，这样确实说得通。但通常本质上并不是因为上述原因，并且根据苹果工程师 Kyle Howarth 所说，由于内部坐标系的变换，这样做效果也不会如预想的那么好。

`UIImage` 使用这类照片时会有问题，主要是因为它会将*原始图片*解压到内存中,正如我们之前研究渲染流程时所讨论的那样。我们需要一个能够减少占用的图片缓存的理想方法。

万幸的是，有办法能以图片调整大小后的尺寸来计算开销，也就是之前认为发生了，但通常不会发生的事情。

我们试试使用更底层的 API，来对图片进行降采样（downsampling）：

```swift
let imageSource = CGImageSourceCreateWithURL(url, nil)!
let options: [NSString:Any] = [kCGImageSourceThumbnailMaxPixelSize:400,
                               kCGImageSourceCreateThumbnailFromImageAlways:true]

if let scaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
    let imageView = UIImageView(image: UIImage(cgImage: scaledImage))
    
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.contentMode = .scaleAspectFit
    imageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
    imageView.heightAnchor.constraint(equalToConstant: 400).isActive = true
    
    view.addSubview(imageView)
    imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
}
```

从显示结果来看，我们得到了与之前完全一样的效果。但是这里，我们用了 `CGImageSourceCreateThumbnailAtIndex()` 而不只是直接将一张普通的照片放到 UIImageView 中。我们再一次使用 `vmmap` 来看我们的优化是否有效（又为简洁而做了截取），就能从中得到结果：

```swift
vmmap -summary baylorOptimized.memgraph

Physical footprint:         56.3M
Physical footprint (peak):  56.7M
```

得到这些结果我们就能计算出节约了多少内存。如果我们比较之前的 69.5M 和现在的 56.3M 我们能算出节约了 13.2M。这是一笔*巨大*的节省，和图片全部的开销都差不多了。

不止如此，你还可以尝试多种选项，来适配于你的使用场景。在 WWDC 18 的 session 219 "Images and Graphics Best Practices" 里，苹果工程师 Kyle Sluder 就演示了一个有趣的方法，通过使用 `kCGImageSourceShouldCacheImmediately` 来控制图像解码的时机：

```swift
func downsampleImage(at URL:NSURL, maxSize:Float) -> UIImage
{
    let sourceOptions = [kCGImageSourceShouldCache:false] as CFDictionary
    let source = CGImageSourceCreateWithURL(URL as CFURL, sourceOptions)!
    let downsampleOptions = [kCGImageSourceCreateThumbnailFromImageAlways:true,
                             kCGImageSourceThumbnailMaxPixelSize:maxSize
                             kCGImageSourceShouldCacheImmediately:true,
                             kCGImageSourceCreateThumbnailWithTransform:true,
                             ] as CFDictionary
    
    let downsampledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions)!
    
    return UIImage(cgImage: downsampledImage)
}
```

此时 Core Graphics 在明确获取缩略图（thumbnail）之前都不会开始解码图片。同时，注意像之前两个例子中一样要传递 `kCGImageSourceCreateThumbnailMaxPixelSize` 参数，因为如果你不这样做 —— 你将会得到一个和原始图像一样大的缩略图。文档中说：

> "…如果没有指定最大像素值，那么缩略图将会和整个图像一样大，这可能不是你所想希望的。"

所以发生了什么事？简单来说，我们将图片缩小存入缩略图中，再进行解码，这样可以让图片缓存缩小很多。回想渲染流程，在第一部分（加载）时，我们不再将整个图片的按原尺寸映射给 UIImage，之后再解码到内存中，而是根据要展示图片的 UIImageView 尺寸，仅传入相应大小的图片缓存。

想要本文"太长不看"的简略版本？找机会对图片进行降采样，而不是使用 `UIImage` 缩小图片尺寸。



## 附加分

我个人在 tandem 中就是像下面这样使用的，并且配合 iOS 11 中新引入的 [prefetch API](https://developer.apple.com/documentation/uikit/uitableviewdatasourceprefetching?language=swift)。请记住，由于我们在解码图片，所以我们需要额外考虑 CPU 使用峰值不要超负荷，即使我们在 UITableView 或者是 UICollectionView 可能需要 cell 之前就已经提前解码好了。

iOS 在 CPU 持续工作时依然能有效地管理 CPU 性能，而此例中对 CPU 的需求是间断性的，因此最好在你自己的线程上解决相关问题。下面代码也将解码操作放到了后台线程，这也是另一个重大优化。

拭目以待吧，我副业项目中的 Objective-C 示例代码来了：

```swift
// 用你自己的队列，而不是系统提供的全局异步队列，以避免可能的线程爆炸
- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    if (self.downsampledImage != nil || 
        self.listItem.mediaAssetData == nil) return;
    
    NSIndexPath *mediaIndexPath = [NSIndexPath indexPathForRow:0
                                                     inSection:SECTION_MEDIA];
    if ([indexPaths containsObject:mediaIndexPath])
    {
        CGFloat scale = tableView.traitCollection.displayScale;
        CGFloat maxPixelSize = (tableView.width - SSSpacingJumboMargin) * scale;
        
        dispatch_async(self.downsampleQueue, ^{
            // Downsample 降采样
            self.downsampledImage = [UIImage downsampledImageFromData:self.listItem.mediaAssetData
                               scale:scale
                        maxPixelSize:maxPixelSize];
            
            dispatch_async(dispatch_get_main_queue(), ^ {
                self.listItem.downsampledMediaImage = self.downsampledImage;
            });
        });
    }
}
```

> 对你大部分的原始 image asset 要小心使用 asset catalog 图片管理方案，因为它已经帮你管理了图片缓存（并且做的远不止这些）。

关于如何成为所有内存和图片相关内容的一等公民，如果想要获得更多启发的话，千万别错过 WWDC 18 中这些内容丰富的 sessions：

- [iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416/?time=1074)

- [Images and Graphics Best Practices](https://developer.apple.com/videos/play/wwdc2018/219/)



## 总结

人无法预料自己不了解的事情。对于编程，你已经能确定整个编程生涯，都要一个以时速 10000 英里运行，以跟上创新和变化的步伐。这意味着…将会有成千上万你不知道的 API、框架、模式或者是优化方式。

对于图像也是如此。大多数时候，你可以创建一个 `UIImageView` 显示一些漂亮的图像，然后就不用管了。我明白，这是因为摩尔定律之类的。现在手机运行很快，能有好几个 G 的内存，并且 —— 我们用不到 100KB 内存的电脑就能把人类送上月球了。

但是常在河边走，哪能不湿鞋。还是别让 jetsam 因为内存过大而造成崩溃吧，因为毕竟自拍就要占用 1G 的内存。希望这一点知识和上述的技巧能让你远离崩溃日志。

下次再见✌️。