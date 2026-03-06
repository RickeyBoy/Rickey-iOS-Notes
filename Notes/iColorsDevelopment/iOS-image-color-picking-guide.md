# iOS 图片取色完全指南：从像素格式到工程实践

> 本文从一个真实的取色 Bug 出发，系统梳理 iOS 图片取色所需的基础知识，包括色彩模型、色彩空间、位深度、像素格式、图片文件格式，以及业界主流的取色方案对比。

## 起因：一个 Display P3 引发的取色 Bug

在开发一个取色功能时，遇到了一个诡异的问题：用户用 iPhone 拍照后进行取色，得到的颜色跟肉眼看到的完全不一样。

问题代码：

```swift
guard let pixelData = self.cgImage?.dataProvider?.data else { return nil }
let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
let pixelInfo: Int = (pixelWidth * Int(point.y * scale) + Int(point.x * scale)) * 4

let r = CGFloat(data[pixelInfo]) / 255.0
let g = CGFloat(data[pixelInfo+1]) / 255.0
let b = CGFloat(data[pixelInfo+2]) / 255.0
```

这段代码假设所有图片都是 8-bit RGBA 格式。但现在 iPhone 拍摄的照片使用 **Display P3** 广色域，部分图片的像素数据是 **16-bit per channel**。当遇到这类图片时：

1. **偏移量算错** — 每像素实际占 8 字节（4 通道 × 2 字节），但代码按 `× 4` 计算
2. **数值解析错** — 16-bit 值域是 0~65535，用 `UInt8` 读只取了低 8 位，再除以 255，得到的颜色完全不对

要理解并修复这个问题，需要掌握一系列图片和色彩的基础知识。

---

## 一、色彩模型

色彩模型定义**如何用数字描述颜色**，但不定义具体哪个数字对应哪个物理颜色（那是色彩空间的事）。

### 1.1 RGB

RGB 是**加色模型**，通过混合红、绿、蓝三种光来生成颜色。

| 分量 | 归一化范围 | 8-bit 范围 | 说明 |
|------|-----------|-----------|------|
| R (红) | 0.0 ~ 1.0 | 0 ~ 255 | 红光强度 |
| G (绿) | 0.0 ~ 1.0 | 0 ~ 255 | 绿光强度 |
| B (蓝) | 0.0 ~ 1.0 | 0 ~ 255 | 蓝光强度 |

- `(0, 0, 0)` = 黑色（无光）
- `(255, 255, 255)` = 白色（全光）

RGB 直接对应屏幕像素的发光方式（每个像素由红、绿、蓝子像素组成），是像素存储和取色的底层数据格式。

**局限性**：RGB 不是感知均匀的。从 `(100, 0, 0)` 到 `(110, 0, 0)` 的视觉差异与 `(200, 0, 0)` 到 `(210, 0, 0)` 的视觉差异并不相同。

### 1.2 HSB/HSV

HSB（也叫 HSV）是 RGB 的**柱坐标变换**，更符合人类对颜色的直觉理解。

| 分量 | 范围 | 说明 |
|------|------|------|
| H (色相 Hue) | 0° ~ 360° | 色轮位置。0°=红，120°=绿，240°=蓝 |
| S (饱和度 Saturation) | 0% ~ 100% | 颜色纯度。0%=灰色，100%=最纯 |
| B (明度 Brightness) | 0% ~ 100% | 0%=黑色，100%=最亮 |

**HSB vs HSL**：两者不同。HSB 中 B=100%, S=0% 是白色；HSL 中 L=100% 不管 H 和 S 都是白色。设计工具（Photoshop、Figma、Sketch）普遍使用 HSB，CSS/Web 开发常用 HSL。

在 iOS 中，`UIColor` 提供了 `getHue(_:saturation:brightness:alpha:)` 方法进行 RGB 和 HSB 的互转。HSB 通常用来构建用户可见的取色器 UI。

### 1.3 CIELAB

CIELAB（L\*a\*b\*）是国际照明委员会（CIE）在 1976 年定义的**感知均匀**色彩模型，与设备无关。

| 分量 | 范围 | 说明 |
|------|------|------|
| L\* | 0 ~ 100 | 明度。0=黑，100=白 |
| a\* | 约 -128 ~ +127 | 绿色（负）↔ 红色（正）|
| b\* | 约 -128 ~ +127 | 蓝色（负）↔ 黄色（正）|

CIELAB 的核心价值：给定的数值变化（ΔE）在整个色彩空间内对应近似相等的视觉变化。当你需要判断"取到的颜色跟目标色差多少"时，Lab 空间的 ΔE 计算比 RGB 欧氏距离有意义得多。

**小结**

| 模型 | 最佳用途 |
|------|---------|
| RGB | 像素存储、渲染、取色底层数据 |
| HSB | 取色器 UI、基于色相的颜色操作 |
| Lab | 颜色差异度量、感知均匀的颜色比较 |

---

## 二、色彩空间

色彩空间 = 色彩模型 + 三个具体定义：

1. **原色（Primaries）** — R、G、B 三个基准色的精确色度坐标
2. **白点（White Point）** — "白色"的色温定义
3. **传输函数（Transfer Function / Gamma）** — 线性光值到编码值的映射曲线

同样的 `(255, 0, 0)` 在 sRGB 和 Display P3 里是**不同的红色**。

### 2.1 sRGB

| 属性 | 值 |
|------|-----|
| 原色 | R(0.64, 0.33), G(0.30, 0.60), B(0.15, 0.06) |
| 白点 | D65 (6504K) |
| 传输函数 | 分段：接近零时线性，之后约 γ2.2 |
| CIE 1931 色域覆盖 | ~35% |

sRGB 是互联网、Windows 和绝大多数消费显示器的默认色彩空间，1996 年由 HP 和微软联合标准化（IEC 61966-2-1）。

它的传输函数并非简单的 γ=2.2 幂函数，而是在接近零的部分有一段线性区域，过渡到移位幂函数。实践中很多实现近似为纯 γ2.2。

### 2.2 Display P3

| 属性 | 值 |
|------|-----|
| 原色 | R(0.680, 0.320), G(0.265, 0.690), B(0.150, 0.060) |
| 白点 | D65（与 sRGB 相同）|
| 传输函数 | 与 sRGB 相同 |
| CIE 1931 色域覆盖 | ~45% |

Display P3 是 Apple 对 DCI-P3 电影标准的消费级适配。它保留了 DCI-P3 的广色域原色，但将白点从电影的氙灯 (~6300K) 换成 D65，传输函数换成 sRGB 曲线。

**与 sRGB 的关系**：Display P3 在 CIE xy 色度图上比 sRGB 大约 **25%**，体积上大约 **50%**。额外的颜色主要在红色、橙色和绿色方向——这些色相可以达到更高的饱和度。

**Apple 设备时间线**：

| 时间 | 设备 |
|------|------|
| 2015 年底 | iMac Retina 5K（首款 P3 显示器的 Apple 设备）|
| 2016.3 | 9.7 寸 iPad Pro |
| **2016.9** | **iPhone 7 / 7 Plus**（首款 P3 显示 + P3 相机的 iPhone）|
| 2017+ | 所有新 iPhone、iPad 和 Retina Mac |

### 2.3 Adobe RGB

| 属性 | 值 |
|------|-----|
| 原色 | R(0.64, 0.33), G(0.21, 0.71), B(0.15, 0.06) |
| 白点 | D65 |
| 传输函数 | 纯 γ2.2 |
| CIE 1931 色域覆盖 | ~52.1% |

Adobe RGB 的设计目标是涵盖 CMYK 打印机可达的大部分颜色，色域优势主要在青绿区域。它是印刷摄影工作流的标准工作空间。

iOS 可以读取和显示 Adobe RGB 图片（通过嵌入的 ICC 配置文件），但 Display P3 的色域并不完全包含 Adobe RGB——部分 Adobe RGB 的绿色和青色超出了 P3 范围，Core Graphics 会自动进行色域映射。

### 2.4 ProPhoto RGB

| 属性 | 值 |
|------|-----|
| 原色 | 部分使用虚拟原色以最大化覆盖 |
| 白点 | D50 (5003K)——与其他空间不同 |
| 传输函数 | 纯 γ1.8 |
| CIE 1931 色域覆盖 | ~79.2% |

ProPhoto RGB 覆盖了 CIE L\*a\*b\* 中超过 90% 的表面色，但约 13% 的可表示颜色是**虚拟色**——不对应任何可见光。

**关键注意**：因为色域极广，8-bit 编码会导致明显的色带（banding）。使用 ProPhoto RGB **必须搭配 16-bit 位深**。

**色域对比总结**

| 色彩空间 | CIE 覆盖 | 相对 sRGB | 白点 | Gamma |
|----------|---------|----------|------|-------|
| sRGB | ~35% | 1.0x（基准）| D65 | ~2.2（分段）|
| Display P3 | ~45% | ~1.25x | D65 | sRGB 曲线 |
| Adobe RGB | ~52% | ~1.5x | D65 | 2.2 |
| ProPhoto RGB | ~79% | ~2.3x | D50 | 1.8 |

---

## 三、位深度

位深度决定每个颜色通道有多少个离散级别。更多位 = 更细的渐变 = 更少的色带。

| 位深 | 每通道值域 | RGB 总颜色数 | 每通道字节 | 典型用途 |
|------|-----------|-------------|-----------|---------|
| 8-bit | 0 ~ 255 | ~1677 万 | 1（`UInt8`）| 消费级图片，JPEG |
| 10-bit | 0 ~ 1023 | ~10.7 亿 | 需特殊打包 | HDR 视频，专业相机 |
| 16-bit | 0 ~ 65535 | ~281 万亿 | 2（`UInt16`）| RAW 处理，专业编辑 |

几个关键事实：

- **iPhone 照片（HEIC）是 8-bit**，不是 10-bit。这是非常常见的误解。
- iPhone **视频**可以是 10-bit Dolby Vision HDR（iPhone 12 起）。
- **Apple ProRAW** 是 12-bit 或 14-bit 传感器数据，存储在 DNG 格式中。
- 位深太低 + 色域太广 = 可见色带。这就是 ProPhoto RGB 强制要求 16-bit 的原因。

除整数位深外，iOS 还支持**浮点格式**：

| 格式 | 范围 | 用途 |
|------|------|------|
| 16-bit 半精度浮点 | ~6.1e-5 到 65504 | Core Image、Metal、扩展范围色 |
| 32-bit 单精度浮点 | IEEE 754 全范围 | Core Image、科学计算 |

浮点格式可以表示 [0, 1] 范围之外的值，这对**扩展范围颜色**（extended range colors）和 HDR 内容至关重要。

---

## 四、像素格式

### 4.1 CGImage 的关键属性

当你拿到一个 `CGImage` 时，以下属性描述了它的像素数据布局：

```swift
cgImage.bitsPerComponent  // 每通道位数：8 或 16
cgImage.bitsPerPixel      // 每像素总位数：32 (RGBA8) 或 64 (RGBA16)
cgImage.bytesPerRow       // 每行字节数（可能包含对齐填充）
cgImage.width             // 像素宽度
cgImage.height            // 像素高度
cgImage.colorSpace        // 色彩空间（sRGB、Display P3 等）
cgImage.alphaInfo         // Alpha 通道配置
cgImage.bitmapInfo        // 组合标志：alphaInfo + 字节序
```

> **bytesPerRow 的坑**：`bytesPerRow` 可能大于 `width × bytesPerPixel`，因为系统会做内存对齐填充。计算像素偏移时**必须用 bytesPerRow**，不能假设紧密排列。

### 4.2 RGBA vs BGRA

在 iOS（ARM，小端序）上，**原生最优格式是 BGRA**。

| 格式 | 内存布局 | 对应 bitmapInfo | 说明 |
|------|---------|----------------|------|
| RGBA | `[R][G][B][A]` | `premultipliedLast` | 常用，直觉友好 |
| BGRA | `[B][G][R][A]` | `premultipliedFirst + byteOrder32Little` | iOS 原生最优，GPU 友好 |

如果你创建了 RGBA 的 CGContext 却按 BGRA 顺序读取，红色和蓝色会互换——取出来的颜色色相完全不对。

**iOS 上常见的像素配置**

| 格式 | bitsPerComponent | bitsPerPixel | bytesPerPixel | 布局 |
|------|-----------------|-------------|--------------|------|
| RGBA8 | 8 | 32 | 4 | R, G, B, A |
| BGRA8 | 8 | 32 | 4 | B, G, R, A |
| RGBA16 | 16 | 64 | 8 | R, G, B, A (UInt16) |
| RGBAf | 32 | 128 | 16 | R, G, B, A (Float32) |

### 4.3 预乘 Alpha（Premultiplied Alpha）

iOS 默认使用**预乘 Alpha**（premultiplied alpha），即存储的 RGB 值已经乘过 Alpha。

```
原始色：R=255, G=0, B=0, A=128  → "纯红，50% 透明"
预乘后：R=128, G=0, B=0, A=128  → 存储的值
// 因为：255 × (128/255) ≈ 128
```

**为什么用预乘？**

1. **合成更快** — 标准 "over" 操作每通道少一次乘法
2. **避免颜色溢出** — 混合直通 Alpha 颜色在子像素边界可能产生光晕

**取色时的影响**：如果 Alpha < 255，需要**反预乘**才能得到真实颜色：

```swift
let a = CGFloat(pixelData[offset + 3]) / 255.0
guard a > 0 else { return .clear }
let r = CGFloat(pixelData[offset]) / 255.0 / a    // 反预乘
let g = CGFloat(pixelData[offset + 1]) / 255.0 / a
let b = CGFloat(pixelData[offset + 2]) / 255.0 / a
```

### 4.4 CGBitmapContext 支持的格式组合

创建 `CGBitmapContext` 时，只有特定的参数组合是合法的：

| 色彩空间 | bitsPerComponent | bitmapInfo | 说明 |
|---------|-----------------|-----------|------|
| RGB | 8 | premultipliedFirst + byteOrder32Little | BGRA8（原生最优）|
| RGB | 8 | premultipliedLast | RGBA8（常用）|
| RGB | 8 | noneSkipFirst + byteOrder32Little | BGRx8（无 Alpha）|
| RGB | 8 | noneSkipLast | RGBx8（无 Alpha）|
| RGB | 16 | premultipliedLast | RGBA16 |
| RGB | 32 (float) | premultipliedLast + floatComponents | RGBAf |
| Gray | 8 | .none | 灰度 8-bit |

---

## 五、图片文件格式

### 5.1 JPEG

| 属性 | 支持情况 |
|------|---------|
| 位深 | **仅 8-bit** |
| 通道 | 3 (RGB)，**不支持 Alpha** |
| 色彩空间 | sRGB（默认），可通过嵌入 ICC 支持 P3、Adobe RGB |
| 压缩 | 有损（DCT） |

JPEG 压缩原理：图片从 RGB 转换为 Y'CbCr（亮度 + 色度），色度通道降采样（4:2:0 或 4:2:2），每个 8×8 块进行 DCT 变换、量化（有损步骤）和熵编码。

### 5.2 PNG

| 属性 | 支持情况 |
|------|---------|
| 位深 | 1, 2, 4, 8, 或 **16-bit** |
| 通道 | 1~4（灰度、灰度+Alpha、RGB、RGBA）|
| Alpha | **完整支持**（8 或 16 bit）|
| 色彩空间 | 通过嵌入 ICC 或 sRGB chunk |
| 压缩 | 无损（DEFLATE） |

16-bit PNG 每通道 65536 级，一个 RGBA16 PNG 每像素 8 字节，文件大小约为同尺寸 8-bit PNG 的两倍。

### 5.3 HEIF/HEIC

| 属性 | 支持情况 |
|------|---------|
| 位深 | 8-bit 或 10-bit（规范支持 16-bit）|
| 通道 | 3 (RGB) 或 4 (RGBA) |
| Alpha | 支持 |
| 色彩空间 | sRGB、Display P3 等 |
| 压缩 | 有损或无损（HEVC） |
| 压缩率 | 同等画质下约为 JPEG 的 **2 倍** |

> **关键事实：iPhone HEIC 照片是 8-bit**。尽管 HEIF 规范支持 10-bit 及更高，Apple iPhone 相机拍摄的 HEIC 静态照片始终是 8-bit per channel。不过 HEIC 照片包含额外的 8-bit **HDR 增益图**（gain map），使系统能在 HDR 屏幕上展示扩展动态范围，但基础图像数据是 8-bit。

不同厂商的 HEIF 实现有差异：

| 厂商 | HEIF 位深 |
|------|----------|
| Apple iPhone | 8-bit（附 HDR 增益图）|
| Canon (R5, R6 等) | 10-bit |
| Nikon (Z8, Z9) | 10-bit |

**格式对比**

| 特性 | JPEG | PNG | HEIF/HEIC |
|------|------|-----|-----------|
| 最大位深 | 8-bit | 16-bit | 16-bit（iPhone 实际 8-bit）|
| Alpha 通道 | 不支持 | 支持 | 支持 |
| 有损压缩 | 支持 | 不支持 | 支持 |
| 无损压缩 | 不支持 | 支持 | 支持 |
| 广色域 (P3) | 通过 ICC | 通过 ICC | 原生 |
| HDR 增益图 | 不支持 | 不支持 | 支持 |
| 文件大小 | 小 | 大 | 最小 |

---

## 六、iOS 取色方案对比

### 方案 A：dataProvider 直接读原始数据

```swift
guard let cgImage = image.cgImage,
      let data = cgImage.dataProvider?.data,
      let bytes = CFDataGetBytePtr(data) else { return nil }

let offset = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
let r = bytes[offset]
let g = bytes[offset + 1]
let b = bytes[offset + 2]
```

**特点**：
- 最快，零拷贝，仅指针运算
- **致命缺陷**：读到的是图片的**原始像素数据**，格式完全取决于源图片
- 必须自己处理 8/16-bit、RGBA/BGRA、不同色彩空间等差异
- 本文开头的 Bug 就是这个方案导致的

**适用场景**：已知图片格式固定且追求极致性能的场景。生产环境不推荐。

### 方案 B：CGContext 重绘（推荐）

```swift
// 使用 Device RGB，系统根据设备自动适配（P3 屏保留广色域）
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

guard let context = CGContext(
    data: &pixelData,
    width: width, height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else { return nil }

context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
// 现在 pixelData 保证是 RGBA8 格式，不管源图片是什么格式
```

**特点**：
- **业界最主流**。Stack Overflow、简书、掘金上绝大多数取色方案都是此方式
- 你定义输出格式，Core Graphics 自动完成所有转换：
  - 16-bit → 8-bit 降采样
  - Display P3 → sRGB 色彩空间转换
  - BGRA → RGBA 字节重排
  - 直通 Alpha → 预乘 Alpha
- 代价：需要分配完整的像素缓冲区并重绘（12MP ≈ 48MB）

**适用场景**：通用取色，各类图片来源不可控的生产环境。

### 方案 C：Core Image

```swift
// CIAreaAverage —— 取区域平均色
let filter = CIFilter(name: "CIAreaAverage", parameters: [
    kCIInputImageKey: ciImage,
    kCIInputExtentKey: CIVector(cgRect: extent)
])
```

**特点**：
- CIImage 是操作图（recipe），不是像素缓冲区，只有在 render 时才产生像素
- 适合取**区域平均色**或主题色提取
- 创建 CIContext + 渲染管线的开销大，单像素取色太重
- Core Image 内部有三级色彩空间管理（输入、工作、输出）

**适用场景**：图片主题色提取、区域平均色分析。不适合实时拖动取色。

### 方案 D：vImage（Accelerate 框架）

```swift
let format = vImage_CGImageFormat(
    bitsPerComponent: 8,
    bitsPerPixel: 32,
    colorSpace: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: ...
)
var buffer = try vImage_Buffer(cgImage: cgImage, format: format)
// 通过 buffer.data 访问像素
```

**特点**：
- Apple 官方高性能图像处理框架，SIMD 优化
- `vImageConverter` 可以精确控制任意格式间的色彩空间转换
- API 较复杂，单像素取色有点 overkill

**适用场景**：批量像素处理、需要最高色彩精度控制的专业场景。

**方案对比总结**

| 维度 | dataProvider (A) | CGContext (B) | Core Image (C) | vImage (D) |
|------|-----------------|---------------|----------------|------------|
| 格式安全 | 危险 | **安全** | 安全 | 安全 |
| 色彩空间处理 | 无 | **自动转换** | 3 级管线 | 精细控制 |
| 16-bit/P3 支持 | 需手动处理 | **自动** | 自动 | 自动 |
| 单像素性能 | 最快 | 缓存后 O(1) | 最慢 | 中等 |
| 批量性能 | 快但脆弱 | 好 | 好 | **最佳** |
| API 复杂度 | 低但易错 | **适中** | 较高 | 较高 |
| 可靠性 | 差 | **好** | 好 | 好 |

---

## 七、工程实践：PixelReader 缓存方案

方案 B（CGContext 重绘）的问题是：如果每次取色都重新创建 CGContext 并绘制，在拖动放大镜时（每秒 60+ 次）会非常卡顿。解决方案是**缓存**——只在初始化时绘制一次，后续取色做数组索引查找。

```swift
public final class PixelReader {
    private let pixelData: [UInt8]  // 缓存的像素数据
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    private let colorSpace: CGColorSpace

    /// 初始化时一次性完成绘制和缓存
    public init?(image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }
        self.width = cgImage.width
        self.height = cgImage.height

        // 使用 Device RGB，系统会根据设备能力自动适配（P3 屏保留广色域）
        self.colorSpace = CGColorSpaceCreateDeviceRGB()

        let bytesPerPixel = 4
        self.bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &data,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cgImage, in: CGRect(origin: .zero,
                     size: CGSize(width: width, height: height)))
        self.pixelData = data  // 缓存
    }

    /// 快速查询——仅数组索引，O(1)
    /// 注意：因为 CGContext 使用 premultipliedLast，需要反预乘还原真实颜色
    public func color(at point: CGPoint) -> UIColor? {
        let x = Int(point.x)
        let y = Int(point.y)
        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        let offset = y * bytesPerRow + x * 4

        // 反预乘 Alpha，还原真实 RGB 值
        let a = CGFloat(pixelData[offset + 3]) / 255.0
        guard a > 0 else { return nil }
        let r = min(CGFloat(pixelData[offset])     / 255.0 / a, 1.0)
        let g = min(CGFloat(pixelData[offset + 1]) / 255.0 / a, 1.0)
        let b = min(CGFloat(pixelData[offset + 2]) / 255.0 / a, 1.0)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
```

在视图层只创建一次，缓存复用：

```swift
@State private var pixelReader: PixelReader? = nil

.onFirstAppear {
    fixedImage = UIImage.fixedOrientation(for: image) ?? image
    pixelReader = PixelReader(image: fixedImage) // 只创建一次
}
```

| | 无缓存 | PixelReader 缓存 |
|---|---|---|
| 每次取色 | 分配缓冲区 + CGContext + draw | 数组下标访问 |
| 时间复杂度 | O(W×H) / 次 | O(1) / 次 |
| 拖动时开销 | 每秒 60+ 次全量位图解码 | 仅初始化时一次 |

本质上是一个经典的**空间换时间优化**。

---

## 八、取色常见坑点

| 坑点 | 说明 | 解决方案 |
|------|------|---------|
| **Scale 倍率** | `UIImage.size` 是点（point），不是像素。@3x 设备上 100pt = 300px | 取色坐标需要乘以 `UIImage.scale` |
| **色彩空间选择** | `CGColorSpace(name: CGColorSpace.sRGB)!` 会强制转换到 sRGB，丢失 P3 色域 | 用 `CGColorSpaceCreateDeviceRGB()` 让系统根据设备自动适配，P3 屏保留广色域 |
| **bytesPerRow 填充** | 系统可能在行尾添加对齐字节 | 始终用 `bytesPerRow` 计算偏移，不要用 `width × 4` |
| **图片方向** | CGImage 不存方向信息，UIImage 的 `imageOrientation` 可能是旋转/镜像的 | 取色前先调用 `fixedOrientation` 校正方向 |
| **预乘 Alpha** | 半透明区域的 RGB 不是原始值 | 需要反预乘：`R_real = R_stored / A` |
| **HEIC ≠ 10-bit** | iPhone 照片是 8-bit HEIC，不要误判为 16-bit | 检查 `cgImage.bitsPerComponent` 确认实际位深 |
| **内存** | 12MP RGBA8 ≈ 48MB，48MP（iPhone 15 Pro）≈ 192MB | 注意内存压力，必要时降采样 |
| **16-bit 像素** | 部分 PNG 或专业相机输出是 16-bit | 用 CGContext 重绘方案自动转换，或检查 `bitsPerComponent` 分支处理 |

---

## 参考资料

- [TN2313: Best Practices for Color Management](https://developer.apple.com/library/archive/technotes/tn2313/_index.html)
- [WWDC17: Get Started with Display P3](https://developer.apple.com/videos/play/wwdc2017/821/)
- [CGImageAlphaInfo - Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgimagealphainfo)
- [CGBitmapInfo - Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgbitmapinfo)
- [vImage.PixelBuffer - Apple Developer Documentation](https://developer.apple.com/documentation/accelerate/vimage/pixelbuffer)
- [displayP3 - Apple Developer Documentation](https://developer.apple.com/documentation/coregraphics/cgcolorspace/displayp3)

- [Color Management across Apple Frameworks - JuniperPhoton](https://juniperphoton.substack.com/p/color-management-across-apple-frameworks-cf7)
- [Adventures in Wide Color - Pete Edmonston](https://medium.com/@heypete/adventures-in-wide-color-an-ios-exploration-2934669e0cc2)
- [Work with Wider Color - Sue Lan](https://suelan.github.io/2020/05/09/20190509-Work-with-Wider-Color/)
- [Accessing Raw Pixels of UIImage - Ralf Ebert](https://www.ralfebert.com/ios/examples/image-processing/uiimage-raw-pixels/)
- [sRGB vs Adobe RGB vs ProPhoto RGB - Photography Life](https://photographylife.com/srgb-vs-adobe-rgb-vs-prophoto-rgb)
- [CIAreaAverage - Hacking with Swift](https://www.hackingwithswift.com/example-code/media/how-to-read-the-average-color-of-a-uiimage-using-ciareaaverage)
- [Swift Accelerate and vImage - Kodeco](https://www.kodeco.com/19456196-swift-accelerate-and-vimage-getting-started)

- [iOS 像素读取详解 - 简书](https://www.jianshu.com/p/96efa99fca3d)
- [Bitmap 详解与实践 - 简书](https://www.jianshu.com/p/362c2f03d378)
- [获取图片某区域像素颜色 - cnblogs](https://www.cnblogs.com/wangbinios/p/5147408.html)
- [iOS 像素读取 - 掘金](https://juejin.cn/post/7035898143380078600)
- [iOS-Palette 颜色提取 - 知乎](https://zhuanlan.zhihu.com/p/27278462)
- [CGImage dataProvider 像素读取 - CSDN](https://blog.csdn.net/jeffasd/article/details/50008801)
