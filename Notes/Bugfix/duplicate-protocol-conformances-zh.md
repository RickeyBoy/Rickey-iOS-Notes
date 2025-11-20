# Swift6 @retroactive：Swift 的重复协议遵循陷阱

## 背景：一个看似简单的 bug

App 内有一个电话号码输入界面，在使用时用户需要从中选择注册电话对应的国家，以获取正确的电话区号前缀（比如中国是 +86，英国是 +44 等）。

| Step 1：入口                                                 | Step 2：缺少区号                                             | 期望结果                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| ![image1](../../backups/DuplicateProtocolConformances/image1.png) | ![image2](../../backups/DuplicateProtocolConformances/image2.png) | ![image3](../../backups/DuplicateProtocolConformances/image3.png) |

这是一个看似很简单的 bug，无非就是写 UI 的时候漏掉了区号，那么把对应字段拼上去就行了嘛。不过一番调查之后发现事情没有那么简单。

列表是一个公用组件，我们需要在列表中显示国家及其电话区号，格式像这样："🇬🇧 United Kingdom (+44)"。所以之前在 **User 模块**中添加了这个extension：

```swift
extension Country: @retroactive DropdownSelectable {
    public var id: String {
        code
    }

    public var displayValue: String {
        emoji + "\t\(englishName) (\(phoneCode))"
    }
}
```

原理一看就明白，displayValue 代表的是展示的内容。但是**最终结果展示错误了**：明明将电话区号 `(\(phoneCode))` 拼在了上面，为什么只显示了国家名称："🇬🇧 United Kingdom"？

代码可以编译。测试通过。没有警告。但功能在生产环境中却是坏的。

> 顺便说一下，什么是 DropdownSelectable？
>
> `DropdownSelectable` 是我们 DesignSystem 模块中的一个协议，它使任何类型都能与我们的下拉 UI 组件配合使用：

```swift
protocol DropdownSelectable {
    var id: String { get }           // 唯一标识符
    var displayValue: String { get } // 列表中显示的内容
}
```

## Part 1: extension 不起作用了

### 发现问题

经过调试后，我们发现了根本原因：**Addresses 模块已经有一个类似的 extension**：

```swift
// 在 Addresses 模块中
extension Country: @retroactive DropdownSelectable {
    public var displayValue: String {
        emoji + "\t\(englishName)"  // 没有电话区号
    }
}
```

| Step 1                                                       | Step 2                                                       |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| ![image4](../../backups/DuplicateProtocolConformances/image4.png) | ![image5](../../backups/DuplicateProtocolConformances/image5.png) |

Addresses 模块不需要电话区号，只需要国家名称。这对地址列表来说是合理的。

但关键是：**Addresses extension 在运行时覆盖了我们 User extension**。我们以为在使用 User 模块的extension（带电话区号），但 Swift 随机选择了 Addresses 的 extension（不带电话区号）。

这就是关键问题。

### 冲突：同时存在两个拓展协议

代码中发现的两处冲突的拓展协议：

**在 User 模块中（我们以为在使用的）：**

```swift
extension Country: @retroactive DropdownSelectable {
    public var id: String {
        code
    }
    public var displayValue: String {
        emoji + "\t\(englishName) (\(phoneCode))"  // ✅ 带电话区号
    }
}
```

**在 Addresses 模块中（实际被使用的）：**

```swift
extension Country: @retroactive DropdownSelectable {
    public var id: String {
        code
    }
    public var displayValue: String {
        emoji + "\t\(englishName)"  // ❌ 不带电话区号
    }
}
```

两个模块都有各自合理的实现理由：
- **User 模块**：电话号码输入界面需要电话区号
- **Addresses 模块**：地址表单不需要电话区号，只需要国家名称

每个开发者都在实现需求时添加了他们需要的内容。代码编译没有警告，新需求测试通过，没人预料到会对旧的需求产生影响。

同时，确实 Swift 也是允许在不同模块中使用相同的 extension。那么到底发生了什么，我们又是如何解决的呢？



## Part 2: 为什么会发生这种情况 - Swift 模块系统解析

要理解为什么这是一个问题，我们需要理解 Swift 的模块系统是如何工作的。有趣的是：**通常情况下，在不同模块中有相同的 extension 是完全没问题的**。但协议遵循是一个特殊情况。

### 正常情况：extension 在模块间通常工作良好

假设你为一个类型添加了一个辅助方法：

```swift
// 在 UserModule 中
extension Country {
    var displayValue: String {
        return emoji + "\t\(englishName) (\(phoneCode))"
    }
}
// 在 AddressesModule 中
extension Country {
    var displayValue: String {
        return emoji + "\t\(englishName)"
    }
}
```

这完全可以工作！每个模块看到的是它自己的extension：
- UserModule 中的代码调用 `displayValue` 会得到带 `phoneCode` 的结果
- AddressesModule 中的代码调用 `displayValue` 会得到不带 `phoneCode` 的结果

**为什么可以工作：** 常规 extension 方法在编译时根据导入的模块来解析。Swift 根据当前模块的导入准确知道要调用哪个方法。

### 特殊情况：协议遵循是全局的

但协议遵循的工作方式不同。当你写：

```swift
extension Country: DropdownSelectable {
    var displayValue: String { ... }
}
```

你不只是在添加一个方法。你在做一个**全局声明**："对于整个应用程序，Country 遵循 DropdownSelectable。"

所以当你创建两个相同的遵循时，会导致**重复遵循错误**

```swift
// 在 UserModule 中
extension Country: DropdownSelectable {
    var displayValue: String {
        return emoji + "\t\(englishName) (\(phoneCode))"
    }
}
// 在 AddressesModule 中
extension Country: DropdownSelectable {
    var displayValue: String {
        return emoji + "\t\(englishName)"
    }
}
```

当你构建链接两个模块的应用时，Swift 编译器或链接器会报错，类似这样：

>  'Country' declares conformance to protocol 'DropdownSelectable' multiple times



## Part 3: 引入 @retroactive 破坏了编译器检查

### 剩余问题：这怎么能编译通过？

基本上，如果我们遇到**重复遵循错误**，编译器会阻止我们。但是为什么这段代码可以正常存在？

一切问题都可以被归咎于 `@retroactive`。

### 什么是 @retroactive？

在 Swift 6 中，Apple 引入了 `@retroactive` 关键字来让跨模块遵循变得明确：

```swift
extension Country: @retroactive DropdownSelectable {
    // 让一个外部类型
    // 遵循一个外部协议
}
```

你需要使用 `@retroactive` 当：

- 类型定义在不同的模块中（例如，来自模块 A 的 `Country`）
- 协议定义在不同的模块中（例如，来自模块 B 的 `DropdownSelectable`）
- 你在第三个模块中添加遵循（例如，在 `UserModule` 和 `AddressesModule` 中）

### 为什么 @retroactive 会破坏编译器检查重复编译问题？

没有 `@retroactive` 的情况下，重复遵循已经是编译时错误。但有了 `@retroactive`，问题变得更加棘手 —— 因为现在你明确声明了影响**整个应用运行时**的东西，而不仅仅是你的模块。

当你写 `@retroactive` 时，你在说：

> "我要为一个我不拥有的现有类型添加遵循，作用于整个 App。"

这意味着编译器允许你 *追溯地/逆向地（retroactively）* 为在其他地方定义的类型添加遵循。这很强大，但也改变了 Swift 检查重复的方式。

**关键点：**

Swift 在**每个模块内**强制执行重复遵循规则，但**不跨模块**。换句话说，编译器只检查它当前正在构建的代码。

- 每个生产者模块（UserModule、AddressesModule）**单独编译时是正常的**（它只"看到"自己的遵循）。到目前为止是正常的。
- 导入两者的消费者（至少你有一个，就是你的 **app target**！），会构建失败，因为它看到了**两个相同的协议遵循**。

**添加 @retroactive 之后：**

使用 `@retroactive`，Swift **将一些检查推迟到链接时**，所以两个模块都能成功编译，即使它们都在声明相同的全局遵循。

重复只有在**链接之后**才会变得可见，当两个模块都被加载到同一个运行时镜像中时 —— 而那时，编译器已经太晚无法阻止它了。

这就是为什么这些重复可以"逃过"编译器的安全检查，导致令人困惑的运行时级别的 bug。

### 运行时发生了什么

当链接器发现 `(Country, DropdownSelectable)` 有两个实现时：
- 选项 A：UserModule 的实现（带电话区号）
- 选项 B：AddressesModule 的实现（不带电话区号）

**它只能注册一个**。所以它根据链接顺序选择一个 —— 基本上是链接器首先处理的那个模块。另一个遵循会被静默忽略。

这解释了为什么 UserModule 的实现被忽略了。



## Part 4: 解决方案 - 包装结构体来拯救

幸运的是我们有一个非常简单的修复方法：**使用包装类型**。

### 解决方案模式

不要让 `Country` 本身遵循协议，而是包装它：

```swift
// UserModule 示例
struct CountryWithPhoneDropdown: DropdownSelectable {
    let country: Country
    var id: String { country.code }
    var displayValue: String {
        country.emoji + "\t\(country.englishName) (\(country.phoneCode))"
    }
}
// AddressModule 示例
struct CountryAddressDropdown: DropdownSelectable {
    let country: Country

    var id: String { country.code }
    var displayValue: String {
        country.emoji + "\t\(country.englishName)"
    }
}
// 使用方式
countries.map { CountryWithPhoneDropdown(country: $0) }
countries.map { CountryAddressDropdown(country: $0) }
```



## **Part 5: 预防 — 如何防止它再次发生**

当然，如果想要不仅是修复这个问题，而是预防这个问题，那么可以通过在工作流程中添加**静态分析**或 **CI 检查**来轻松避免重复的 `@retroactive` 遵循。

这确保任何重复的 `@retroactive` 遵循在**到达生产环境之前**被发现，避免类似的运行时错误。



## 结语

这个 bug 根本不是简单的 UI 问题，想要彻底解决就需要深度理解 Swift 的运行机制。协议拓展可以跨模块重复，但协议遵循是全局的，`@retroactive` 叠加 Swift 的这种能力造成了这次的 bug。

一旦我们理解了这一点，修复就很简单了。
