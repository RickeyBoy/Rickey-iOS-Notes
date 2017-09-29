# Swift 协议 - Protocol 详解

## 基本用法
> 《 The Swift Programming Language 》

#### Protocol 基础语法
1. 属性要求 ： 
    - { get set } ：指定读写属性
    - static／class：指定类型属性
2. 方法要求：
    - static／class：指定类方法
    - mutating：要求实现可变方法（针对值类型的实例方法，可以在该方法中修改它所属的实例以及实例的任意属性的值）
3. 构造器要求：
    - 在遵循协议的类中，必须使用`required`关键字修饰，保证其子类也必须提供该构造器的实现。（除非有`final`修饰的类，可以不用`required`，因为不会再有子类）

#### Protocol 作为类型
1. 作为类型：代表遵循了该协议的某个实例（实际上就是某个实例遵循了协议）
2. 协议类型的集合：`let A: [someProtocol]`，遵守某个协议的实例的集合
3. Delegate 委托设计模式：定义协议来封装那些需要被委托的功能

#### Protocol 间的关系
1. 协议的继承：协议可继承
2. 协议的合成：使用`&`关键字，同时遵循多个协议
3. 协议的一致性：使用`is`、`as？`、`as！`进行一致性检查
4. 类专属协议：协议继承时使用`class`关键字，限制该协议职能被类继承

#### optional & @objc 关键字
可选协议：使用`optional`修饰属性、函数、协议本身，同时所有`option`必须被`@objc`修饰，协议本身也必须使用`@objc`，只能被Objective-C的类或者`@objc`的类使用

#### extension 关键字

 - （对实例使用）令已有类型遵循某个协议
 - （对协议使用）可遵循其他协议，增加协议一致性
 - （对协议使用）提供默认实现
 - （搭配`where`对协议使用）增加限制条件

## Protocols or Classes 协议与类的对比
> 类（Class） 是面向对象编程之中的重要元素，它代表的是一个共享相同结构和行为的对象的集合

- Classes 可以做的事：
    - Encapsulation 封装：表现为对外提供接口，隐藏具体逻辑，保证类的高内聚
    - Access Control 访问控制：依赖于类的修饰符（如public、private），保证隔离性
    - Abstraction 抽象：提取具有类似特性的事物，进行建模
    - NameSpace 命名空间：避免不同作用域中，同名变量、函数发生冲突
    - Expressive Syntax 丰富的语法
    - Extensibility 可拓展性：可继承、可重写等等

#### Classes 的问题：
1. Implicit Sharing 隐式共享: 

![-w100](http://ac-HSNl7zbI.clouddn.com/sdLriPomzMIjCbp1eHEfMCYyfkpYwfgkSdHoSrpo.jpg)

可能会导致大量保护性拷贝（Defensive Copy），导致效率降低；也有可能发生竞争条件（race condition），出现不可预知的错误；为了避免race condition，需要使用锁（Lock），但是这更会导致代码效率降低，并且有可能导致死锁（Dead Lock）

2. Inheritance All 全部继承：

由于继承时，子类将继承父类全部的属性，所以有可能导致子类过于庞大，逻辑过于复杂。尤其是当父类具有存储属性（stored properties）的时候，子类必须全部继承，并且小心翼翼得初始化，避免损坏父类中的逻辑。如果需要重写（override）父类的方法，则必须要小心思考如何重写以及何时重写。

3. Lost Type Relationships 不能反应类型关系：

![-w200](http://ac-HSNl7zbI.clouddn.com/66GlgQgMNwhd9GQTCoETyFr54Lewk3d2szKOMNk6.jpg)

上图中，两个类（Label、Number）拥有相同的父类（Ordered），但是在 Number 中调用 Order 类必须要使用强制解析（as！）来判断 Other 的属性，这样做既不优雅，也非常容易出Bug（如果 Other 碰巧为Label类）


## protocol oriented programming 面向协议编程
> 面向协议编程的优点

#### 解耦

#### Strong Type Safety 类型安全

#### Code Abstraction 代码抽象

