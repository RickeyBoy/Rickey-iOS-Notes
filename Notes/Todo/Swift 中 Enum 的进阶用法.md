# Swift 中 enum 枚举类型的进阶用法



### 1. enum 搭配 switch

enum 搭配 switch，这可以说是最最基本的使用了。通过不同的 case 映射不同的类型，再根据类型进行相应的处理。这样一来可以使得代码逻辑更加清晰，并且不容易遗漏。

通过一个例子来说明，假设现在我们想要实现一个文章分享的功能，效果类似于下图：

<img src="https://github.com/RickeyBoy/Rickey-iOS-Notes/blob/master/图片备份/Blog_Swift_Enum/1.png?raw=true" width="200px" />

考虑到每一个分享选项都有不同的 UI 以及点击事件，我们可以定义下面一个 enum，表示不同的分享渠道：

``` swift
/// 不同的分享渠道
public enum ShareChannel: String {
    case wechat
    case wechatMoments
    case QQ
    case Qzone
    case toutiao
    case copyUrl
    case feedback
}
```

那么 enum 就可搭配 switch 使用。在具体实现的时候，选择了使用 UICollectionView，每一个按钮和名称的组合放在一个 UICollectionViewCell 之中进行布局。那么在 UICollectionViewCell 之中，我们可以写一个这样的方法，根据传入的分享渠道类型，来填充 Cell 之中的图片和文字内容：

``` swift
func updateData(channel: ShareChannel) {
        switch channel {
        case .toutiao:
            self.imageButton.image = #imageLiteral(resourceName: "toutiao_allshare_icon")
            self.labelButton.text = "微头条"
        case .wechat:
            self.imageButton.image = #imageLiteral(resourceName: "share_wechat_white")
            self.labelButton.text = "微信"
        ... // 列举每一种情况
        }
    }
```

建议在 switch 的时候不要使用 default，而是尽量列举所有的 case。假设现在我们现在需要增加一个分享渠道，我们只需要在定义枚举的地方增加一个新的 case 即可，之后编译器会在所有使用了 switch 的相关位置有错误提示，这样就不会漏掉对新增 case 的处理。



### 2. 把 switch 移入 enum 之中

由于 switch 语句占地面积太大，放在业务逻辑中实在是有点碍眼。所以如果能把这部分逻辑移入定义 enum 的文件之中，相关业务逻辑就会更加清晰。

```swift
public enum ShareChannel: String {
    case wechat
    case wechatMoments
    case QQ
    case Qzone
    case toutiao
    case copyUrl
    case feedback

    var name: String {
        switch self {
        case .toutiao:
            return "头条圈"
        case .wechatMoments:
            return "朋友圈"
        case .wechat:
            return "微信"
        case .QQ:
            return "手机QQ"
        case .Qzone:
            return "QQ空间"
        case .copyUrl:
            return "复制链接"
        case .feedback:
            return "反馈"
        }
    }
    
    var image: UIImage {
        switch self {
            // 类似 name
            ...
        }
    }
}
```

那么在这样定义了之后，使用起来就可以避免 switch，更加清晰明了。

``` swift
func updateData(channel: ShareChannel) {
    // 可以避免在业务逻辑中使用 switch
    self.imageButton.image = channel.name
    self.labelButton.text = channel.image
}
```



### 3. 增加关联值 Associated Values

假设



### associated value

== 比较大小 http://www.thomashanning.com/swift-comparing-enums-with-associated-values/



### enum 表示状态，完成 tableview 逻辑



### enum 实现类似 nsattributestring 的多属性



### enum swift4 高级使用