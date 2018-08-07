# Swift 中 enum 枚举类型的进阶用法













### enum 的基本使用

最基础的用法我们可以假设现在，我们想要实现一个文章分享的功能，最后想要实现的效果类似于下图：

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

enum 这样搭配 switch 使用的好处是逻辑非常的清楚，但是这样也有一些麻烦的地方。假设现在我们现在需要增加一个分享渠道，





### associated value

== 比较大小 http://www.thomashanning.com/swift-comparing-enums-with-associated-values/



### enum 表示状态，完成 tableview 逻辑