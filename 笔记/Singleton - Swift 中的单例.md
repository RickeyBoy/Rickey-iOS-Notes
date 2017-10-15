# Singleton - Swift 中的单例
单例 Singleton 是设计模式中非常重要的一种，在 iOS 中也非常常见。在之前的面试中也被问到过单例相关的问题，当时感觉自己答得不是很好，后来也是又深入研究了一下。本文主要是简单了一下单例，并且讨论了一下 Swift 中单例的实现。

## Singleton 基本介绍

### 单例是什么？
单例模式（Singleton Pattern）是最简单的设计模式之一。这种类型的设计模式属于创建型模式，它提供了一种创建对象的最佳方式。这种模式涉及到一个单一的类，该类负责创建自己的对象，同时确保只有单个对象被创建。

<img src="http://ac-HSNl7zbI.clouddn.com/D2ErxUYP5HxTVE2mPV8vBobUxlOWdoNKkN5OVdO6.jpg" width="200">

<img src="http://ac-HSNl7zbI.clouddn.com/LP3b1q4RrOrmmoAuVUir6lA0Gsrk52KVvS2Wh3Hf.jpg" width="300">

基本要求：
- 只能有一个实例。
- 必须自己创建自己的唯一实例。
- 必须给所有其他对象提供这一实例。

### iOS 中的单例
- `UIApplication.shard` ：每个应用程序有且只有一个UIApplication实例，由UIApplicationMain函数在应用程序启动时创建为单例对象。
- `NotificationCenter.defualt`：管理 iOS 中的通知
- `FileManager.defualt`：获取沙盒主目录的路径
- `URLSession.shared`：管理网络连接
- `UserDefaults.standard`：存储轻量级的本地数据
- `SKPaymentQueue.default()`：管理应用内购的队列。系统会用 **StoreKit** framework 创建一个支付队列，每次使用时通过类方法 `default()` 去获取这个队列。 

### 单例的优点
- **提供了对唯一实例的受控访问**：单例类封装了它的唯一实例，防止其它对象对自己的实例化，确保所有的对象都访问一个实例。
- **节约系统资源**：由于在系统内存中只存在一个对象，因此可以节约系统资源，对于一些需要频繁创建和销毁的对象，单例模式无疑可以提高系统的性能。
- **伸缩性**：单例模式的类自己来控制实例化进程，类就在改变实例化进程上有相应的伸缩性。
- **避免对资源的多重占用**：比如写文件操作，由于只有一个实例存在内存中，避免对同一个资源文件的同时写操作

## Singleton 在 Swift 中的实现
    
### 第一种方式：
也是最直接简洁的方式：将实例定义为全局变量。比如下面的代码，声明了一个实例变量`sharedManager`。

``` Swift 
let sharedManager = MyManager(string: someString)
class MyManager {
    // Properties
    let string: String
    // Initialization
    init(string: String) {
        self.string = string
    }
}
```

而如果将上述实例变量在全局命名区（global namespace）第一次调用，由于Swift中**全局变量是懒加载（lazy initialize）**。所以，在`application(_:didFinishLaunchingWithOptions:)`中调用的时候之后，`shardManager`会在`AppDelegate`类中被初始化，之后程序中所有调用`sharedManager`实例的地方将都使用该实例。

另外，Swift 全局变量初始化时默认使用`dispatch_once`，这保证了全局变量的构造器（initializer）只会被调用一次，保证了`shardManager`的**原子性**。

``` Swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // 初始化位置，以及使用方式
    print(sharedManager)
    return true
}
```

* **关于 Swift 中全局变量的懒加载**

> Initialize lazily, run the initializer for a global the first time it is referenced, similar to Java. It allows custom initializers, startup time in Swift scales cleanly with no global initializers to slow it down, and the order of execution is completely predictable.
> Swift 采用与 Java 类似的方式，对全局变量实行懒加载。这样设计使得构造器可以自定义、启动时间不会因为加载全局变量而变慢、同时操作执行的顺序也变得可控。

* **关于 Swift 中的 dispatch_once 和 原子性**

> The lazy initializer for a global variable ... is launched as `dispatch_once` to make sure that the initialization is atomic. This enables a cool way to use `dispatch_once` in your code: just declare a global variable with an initializer and mark it private.
> 全局变量的懒加载在初始化时会使用 `dispatch_once` 以确保初始化的原子性。所以这是一个很酷地使用 `dispatch_once` 的方式：仅在定义全局变量时将其构造器标志为 `private` 就行。

### 第二种方式：

Swift 2 开始增加了`static`关键字，用于限定变量的作用域。如果不使用`static`（比如`let string`），那么每一个`MyManager`实例中均有一个`string`变量。而使用`static`之后，`shared`成为全局变量，成为单例。

另外可以注意到，由于构造器使用了 `private` 关键字，所以也保证了单例的原子性。

``` Swift
class MyManager {
    // 全局变量
    static let shared = MyManager(string: someString)
    
    // Properties
    let string: String
    // Initialization
    private init(string: String) {
        self.string = string
    }
}
```

第二种方式的使用如下。可以看出采用第二种方式实现单例，代码的可读性增加了，能够直观的分辨出这是一个单例。

``` Swift
// 使用
print(MyManager.shared)
```

### 第三种方式：

第三种方式是第二种方式的变种，更加复杂。让单例在闭包（Closure）中初始化，同时加入类方法来获取单例。

``` Swift
class MyManager {
    // 全局变量
    private static let sharedManager: MyManager = {
        let shared = MyManager(string: someString) 
        // 可以做一些其他的配置
        // ...
        return shared
    }()
    // Properties
    let string: String
    // Initialization
    private init(string: String) {
        self.string = string
    }
    // Accessors
    class func shared() -> MyManager {
        return sharedManager
    }
}
```

可以看出第三种方式虽然更加复杂，但是可以在闭包中作一些额外的配置。同时，调用单例的方式也不一样，需要调用单例中的类方法`shared()`

``` Swift
print(MyManager.shared())
```

## 单例的缺陷

### 单例状态的混乱
由于单例是共享的，所以当使用单例时，程序员无法清楚的知道单例当前的状态。

当用户登录，由一个实例负责当前用户的各项操作。但是由于共享，当前用户的状态很可能已经被其他实例改变，而原来的实例仍然不知道这项改变。如果想要解决这个问题，实例就必须对单例的状态进行监控。Notifications 是一种方式，但是这样会使程序过于复杂，同时产生很多无谓的通知。

### 测试困难
测试困难主要是由于单例状态的混乱而造成的。因为单例的状态可以被其他共享的实例所修改，所以进行需要依赖单例的测试时，很难从一个干净、清晰的状态开始每一个 test case

### 单例访问的混乱
由于单例时全局的，所以无法对访问权限作出限定。程序任何位置、任何实例都可以对单例进行访问，这将容易造成管理上的混乱。


## 参考资料
- [What is a Singleton and How to create one in Swift](https://cocoacasts.com/what-is-a-singleton-and-how-to-create-one-in-swift/)
- [Files and Initialization - Swift Blog - Apple Developper](https://developer.apple.com/swift/blog/?id=7)
- [Avoiding singletons in Swift - John Sundell - Medium](https://medium.com/@johnsundell/avoiding-singletons-in-swift-5b8412153f9b)


