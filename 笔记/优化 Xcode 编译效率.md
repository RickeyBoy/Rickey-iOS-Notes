# 优化 Xcode 编译时间

最近在使用 Swift 开发项目时，发现编译时间实在是慢的出奇。每次 git 切换分支之后，都得编译好久，而且动辄卡死。有时候改了一点小地方想 debug 看下效果，也得编译那么好一会儿，实在是苦不堪言。所以下决心要好好研究一下，看看有没有什么优化 Xcode 编译时间的好办法。

本文中有不少实验数据，都是对基于现有项目进行的简单测试，优化效果仅供参考😅。

第一步就是搞定编译时间的测算，方法如下。完成了之后就可进入正题了。

##### 查看编译消耗的时间

1. 在命令行输入如下语句，则 Xcode 编译成功之后，会在顶部 "Succeed" 字段旁边显示编译时间。

```
defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES
```

2. 使用 Github 上这一个插件 [BuildTimeAnalyer-for-Xcode](https://github.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode)，还可以具体地显示每个文件的编译时间。




# 一、提高 Xcode 编译效率




### 1. 全模块优化（Whole Module Optimization）

module 是 Swift 文件的集合，每个 module 编译成一个 framework 或可执行程序。在编译时，Swift 编译器分别编译 module 中的每一个文件，编译完成后再链接到一起，最终再输出 framework 或可执行程序。

由于这种编译方式局限于单个文件，所以像有需要跨函数的优化等就可能会受到影响，比如函数內联、基本块合并等。因此，编译时间会变长。

而如果使用全模块优化，编译器会先将所有文件合称为同一个文件，然后再进行编译，这样能够极大的加快编译速度。比如编译器了解模块中所有函数的实现，所以它能够确保执行跨函数的优化（包括函数内联和函数特殊化等）。

另外，全模块优化时编译器能够推出所有非公有（non-public）函数的使用。非公有函数仅能在模块内部调用，所以编译器能够确定这些函数的所有引用。于是编译器能够知道一个非公有函数或方法是否根本没有被使用，从而直接删除冗余函数。

####函数特殊化举例

函数特殊化是指编译器创建一个新版本的函数，这个函数通过一个特定的调用上下文来优化性能。在 Swift 中常见的是够针对各种具体类型对泛型函数进行特殊化处理。

**main.swift**

```swift
func add (c1: Container<Int>, c2: Container<Int>) -> Int {
  return c1.getElement() + c2.getElement()
}
```

**utils.swift**

```swift
struct Container<T> {
  var element: T

  func getElement() -> T {
    return element
  }
}
```

单文件编译时，当编译器优化 **main.swift** 时，它并不知道 `getElement` 如何被实现。所以编译器生成了一个 `getElement` 的调用。另一个方面，当编译器优化 **utils.swift** 时，它并不知道函数被调用了哪个具体的类型。所以它只能生成一个通用版本的函数，这比具体类型特殊化过的代码慢很多。

即使简单的在 `getElement` 中声明返回值，编译器也需要在类型的元数据中查找来解决如何拷贝元素。它有可能是简单的 `Int` 类型，但它也可以是一个复杂的类型，甚至涉及一些引用计数操作。而在单文件编译的情况下，编译器都无从得知，更无法优化。

而在全模块编译时，编译器能够对范型函数进行函数特殊化：

**utils.swift**

```swift
struct Container {
  var element: Int

  func getElement() -> Int {
    return element
  }
}
```

将所有 `getElement` 函数被调用的地方都进行特殊化之后，函数的范型版本就可以被删除。这样，使用特殊化之后的 `getElement` 函数，编译器就可以进行进一步的优化。



#### SWIFT_WHOLE_MODULE_OPTIMIZATION 启用全模块优化

**状态栏 -> Editor -> Build Setting -> Add User-Defined Settings**，然后增加 key 为 `SWIFT_WHOLE_MODULE_OPTIMIZATION`，value 为 `YES` 就可以了。



#### 为什么 Swift 的编译器默认不是全模块优化？

Swift 默认设置是 Debug 时只编译 active 架构，Build active architecture only，Xcode 默认就是这个设置。可以在 **Build Settings** --> **Build active architecture only** 中检查到这一设置。

也就是说，在对每一个文件单独进行编译时，编译器会缓存每个文件编译后的产物。这样的好处在于，如果之前编译过了一次，之后只改动了少部分文件的内容，影响范围不大，那么其他文件就不用重新编译，速度就会很快。

而我们来看一看全模块优化的整体过程，包括：分析程序，类型检查，SIL 优化，LLVM 后端。而大多数情况下，前两项都是非常快速的。SIL 优化主要进行的是上文所说的函数內联、函数特殊化等优化，LLVM 后端采用多线程的方式对 SIL 优化的结果进行编译，生成底层代码。

<img src="http://p6z7avd1u.bkt.clouddn.com/image/blog/wmo-detail.png" width="300px" />

而设置 `SWIFT_WHOLE_MODULE_OPTIMIZATION = YES`，全模块优化会让**增量编译的颗粒度从 File 级别增大到 Module 级别**。一个只要修改我们项目里的一个文件，想要编译 debug 一下，就又得重新合并文件从头开始编译一次。理论上讲，如果单个 LLVM 线程没有被修改，那么也能利用之前的缓存进行加速。但现实情况是，分析程序、类型检查、SIL 优化肯定会被重新执行一次，而绝大部分情况下 LLVM 也基本得重新执行一次，和第一次编译时间差不多。

不过注意，pod 里的库，storyboard 和 xib 文件是不会受影响的。



### 2. 生成 dSYM 文件（dSYM generation）

dSYM 文件存储了 debug 的一些信息，里面包含着 crash 的信息，像 Fabric 可以自动的将 project 中的 dSYM 文件进行解析。

新项目的默认设置是 Debug 配置编译时不生成 dSYM 文件。有时候为了在开发时进行 Crash 日志解析，会去修改这个参数。生成 dSYM 会消耗大量时间，如果不需要的话，可以去 **Debug Information Format** 修改一下。**DWARF** 是默认的不生成 dSYM 文件，**DWARF with dSYM file** 是会生成 dSYM 文件。



### 3. 使用新的 Xcode 9 编译系统

在 Xcode 9 中，苹果官方悄悄引入了一个新的编译系统，你可以在 [Github](https://github.com/quellish/XcodeNewBuildSystem) 中找到这一个项目。这还只是一个预览版，所以并没有在 Xcode 中默认开启。官方新系统会改变 Swift 中处理对象间依赖的方式，旨在提高编译速度。不过现在还不完善，有可能导致写代码时的诡异行为以及较长的编译时间。果然，我试了一下确实比原来还要慢。

如果想要开启试试的话，可以在 **File菜单 -> Working space ** **Building System -> New Building System(Preview)**



### Build Time 记录

| Generate dSYM | Who Module Optimization | 增加空行后第二次编译 | 首次编译 | 使用 New Build System | 编译总时间 |
| :-----------: |:---------------:| :----:| :-----------: | :-----------: | :-----------: |
| ✔ |  |  | ✔ |  | 8m 42s |
|       |         |    | ✔ |  | 8m 18s |
| ✔ | ✔       |     | ✔ |  | 2m 2s |
|  | ✔ |  | ✔ |  | 1m 36s |
| ✔ |  | ✔ |  |  | 0m 38s |
|  |  | ✔ |  |  | 0m 16s |
| ✔ | ✔ | ✔ |  |  | 1m 26s |
|  | ✔ | ✔ |  |  | 0m 55s |
|  |  |  | ✔ | ✔ | 9m 24s |
|  | ✔ |  | ✔ | ✔ | 1m 46s |



# 二、优化 Swift 代码

### 1. 减少类型推断

```swift
let array = ["a", "b", "c", "d", "e", "f", "g"]
```

这种写法会更简洁，但是编译器需要进行类型推断才能知道 `array` 的准确类型，所以最好的方法是直接写出类型，避免推断。

```swift
let array: [String] = ["a", "b", "c", "d", "e", "f", "g"]
```



### 2. 减少使用 ternary operator

```swift
let letter = someBoolean ? "a" : "b"
```

三目运算符写法更加简洁，但会增加编译时间，如果想要减少编译时间，可以改写为下面的写法。

```swift
var letter = ""
if someBoolean { 
  letter = "a"
} else {
  letter = "b"
}
```



### 3. 减少使用 nil coalescing operator

```swift
let string = optionalString ?? ""
```

这是 Swift 中的特殊语法，在使用 optional 类型时可以通过这样的方式设置 default value。但是这种写法本质上也是三目运算符。

```swift
let string = optionalString != nil ? optionalString! : nil
```

所以，如果以节约编译时间为目的，也可以改写为

```swift
if let string = optionalString{ 
    print("\(string)")
} else {
    print("")
}
```



### 4. 改进拼接字符串方式

```swift
let totalString = "A" + stringB + "C"
```

这样拼接字符串可行，但是 Swift 编译器并不青睐这样的写法，尽量改写成下面的方式。

```swift
let totalString = "A\(stringB)C"
```



### 5. 改进转化字符串的方式

```swift
let StringA = String(IntA)
```

这样拼接字符串可行，但是 Swift 编译器并不青睐这样的写法，尽量改写成下面的方式。

```swift
let StringA = "\(IntA)"
```



### 6. 提前计算

```swift
if time > 14 * 24 * 60 * 60 {}
```

这样写可读性会更好，但是会对编译器造成极大的负担。可以将具体内容写在注释中，这样改写：

```swift
if time > 1209600 {} // 14 * 24 * 60 * 60
```



### Build Time 记录

##### 减少类型推断
在一个文件中，共减少了 2 处类型推断，一共优化 0.3ms，改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 135.3 ms |
| 更改后 | 135.0 ms |

所见 Xcode 对类型推断的处理优化还是效果很不错的，而且在声明阶段的类型推断实际上并不是很困难，因此提前声明类型其实对编译时间的优化效果影响不大。



##### 减少使用 ternary operator

在一个文件中，共减少了 2 处使用三目运算符的地方，一共优化 51.2ms，改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 229.2 ms |
| 更改后 | 178.0 ms |

可见使用三目运算符的地方会对编译速度产生一定的影响，因此在不是特别需要的时候，出于编译时间的考虑可以改写为 if-else 语句。



##### 减少使用 nil coalescing operator

在一个文件中，共减少了 5 处使用 nil coalescing operator 的地方，一共优化 2.8ms，具体改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 386.4 ms |
| 更改后 | 383.6 ms |

根据结果而言，优化效果并不显著。可是根据前文所述，nil coalescing operator 实际上是基于三目运算符的，那么为何优化效果反而不如三目运算符？据我推测，原因可能在于三目运算符只需要改写为 if-else 语句即可，而 nil coalescing operator 大部分时候需要先用 var 实现赋值语句，在使用 if-else 对赋值进行更改，所以总的来说优化效果不大。



##### 字符串连接方式

在一个文件中，共改进了 7 处字符串的拼接方式，一共优化 73ms，具体改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 696.1 ms |
| 更改后 | 623.1 ms |

可见改进字符串的拼接方式效果还是十分明显的，而且也更符合 Swift 的语法规范，所以何乐而不为呢？



##### 字符串转换方式

在一个文件中，进行了 5 处修改，一共优化 4952.5ms，效果十分显著。具体改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 5106.2 ms |
| 更改后 | 153.7 ms |



##### 提前计算

在一个文件中，进行了之前例子中的修改，一共优化 843.2ms，效果十分显著。具体改进效果如下：

| -- | 总时间 |
| :-----------: |:---------------:|
| 更改前 | 1034.7 ms |
| 更改后 | 191.5 ms |



### 参考文献

1. [Whole-Module Optimization in Swift 3](https://swift.org/blog/whole-module-optimizations/)
2. [How to enable build timing in Xcode? - Stack Overflow](https://stackoverflow.com/questions/1027923/how-to-enable-build-timing-in-xcode/2801156#2801156)
3. [Speed up Swift compile time](https://hackernoon.com/speed-up-swift-compile-time-6f62d86f85e6)



