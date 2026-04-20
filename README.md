# MDMath

基于 `swift-markdown` 与 `LaTeXSwiftUI` 的 SwiftUI Markdown 排版包，目标是为 **AI 输出场景** 提供更稳定的 Markdown + 数学公式混排体验。

当前版本重点解决 4 类问题：

- 使用 `swift-markdown` 做块级语义解析，而不是正则拼接整棵视图树
- 使用 `LaTeXSwiftUI` 统一承接 inline / block 数学公式渲染
- 面向 AI tool streaming，尽量容忍未闭合代码块与未完成公式
- 优化 inline baseline、block overflow scroll，并尽量贴合系统字号

## 设计目标

- **更适合流式输出**：内容一边生成一边显示时，尽量避免因为半截 Markdown 导致整段排版抖动
- **更适合中英混排 / CJK 场景**：inline 公式默认按 CJK 文本度量做缩放
- **更适合聊天与工具结果展示**：block 数学与代码块优先保证可读性，不强行压缩
- **尽量保持系统风格**：字号、层级、留白、代码字体都贴近 SwiftUI 默认语义

## 特性

- 使用 `swift-markdown` 做块级 AST 解析
- 使用 `LaTeXSwiftUI` 负责 inline / block 数学公式渲染
- 提供 `MarkdownMath.RenderMode.streaming`
- 自动补全未闭合代码围栏（````` / `~~~`）
- 未闭合数学分隔符不会触发错误解析，而是按普通文本显示
- block 公式默认支持超宽时水平滚动
- inline 数学公式沿用系统字号，并默认按 CJK 文本度量做 baseline 匹配
- 支持标题、段落、引用、列表、代码块、图片、分隔线等常见块级结构

## 依赖

- [swift-markdown](https://github.com/swiftlang/swift-markdown)
- [LaTeXSwiftUI](https://github.com/colinc86/LaTeXSwiftUI)

## 平台要求

- `iOS 17+`
- `macOS 13+`
- `Swift 6`

## 安装

```swift
dependencies: [
    .package(url: "https://github.com/your-org/MDMath.git", branch: "main")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "MDMath", package: "MDMath")
    ]
)
```

## 快速开始

```swift
import MDMath
import SwiftUI

struct ContentView: View {
    let markdown = """
    # 勾股定理

    行内公式 $a^2+b^2=c^2$。

    $$
    \\int_0^1 x^2 dx = \\frac{1}{3}
    $$
    """

    var body: some View {
        ScrollView {
            MarkdownMath(markdown, renderMode: .streaming)
                .padding()
        }
    }
}
```

## 核心 API

### `MarkdownMath`

```swift
public init(
    _ source: String,
    renderMode: MarkdownMath.RenderMode = .final,
    theme: MarkdownMathTheme = .init(),
    resourceOptions: MarkdownMathResourceOptions = .init()
)
```

参数说明：

- `source`：原始 Markdown 字符串
- `renderMode`：渲染模式，决定是否启用 streaming 容错
- `theme`：字号、留白、圆角、公式 baseline 策略等主题配置
- `resourceOptions`：图片 / 链接地址重写与图片 URL 解析配置

### `MarkdownMath.RenderMode`

```swift
public enum RenderMode {
    case final
    case streaming
}
```

- `final`：适用于已经完整生成完成的 Markdown
- `streaming`：适用于 AI 持续输出中的中间态内容

### `MarkdownMathTheme`

当前可配置项包括：

- `bodyFont`
- `codeFont`
- `headingFonts`
- `blockSpacing`
- `listItemSpacing`
- `contentPadding`
- `blockCornerRadius`
- `usesCJKInlineMathMetrics`

示例：

```swift
let theme = MarkdownMathTheme(
    bodyFont: .body,
    codeFont: .footnote.monospaced(),
    headingFonts: [
        1: .largeTitle,
        2: .title,
        3: .title2,
    ],
    blockSpacing: 16,
    listItemSpacing: 10,
    contentPadding: 12,
    blockCornerRadius: 14,
    usesCJKInlineMathMetrics: true
)
```

```swift
MarkdownMath(markdown, renderMode: .streaming, theme: theme)
```

### `MarkdownMathResourceOptions`

用于统一处理图片与链接地址。

当前支持：

- 按 prefix 批量重写地址
- 使用自定义闭包进一步改写地址
- 为 block 图片提供自定义 `URL` 解析逻辑，便于对接 App 内部相对路径

示例：

```swift
let resourceOptions = MarkdownMathResourceOptions(
    prefixRewriteRules: [
        .init(prefix: "/images/", replacement: "../media/"),
        .init(prefix: "/docs/", replacement: "gradpath://docs/")
    ],
    imageURLResolver: { source in
        URL(fileURLWithPath: source, relativeTo: Bundle.main.resourceURL)
    }
)

MarkdownMath(
    markdown,
    renderMode: .final,
    resourceOptions: resourceOptions
)
```

这样：

- `![](/images/abc.png)` 会先改写成 `![](../media/abc.png)`
- `[](/docs/intro)` 会先改写成 `[](gradpath://docs/intro)`
- block 图片在渲染时会继续通过 `imageURLResolver` 转成 `AsyncImage` 可加载的 `URL`

## 支持的数学分隔符

当前会优先抽取并恢复以下完整数学片段：

- `$...$`
- `$$...$$`
- `\\(...\\)`
- `\\[...\\]`
- `\\begin{...} ... \\end{...}`

说明：

- 只有 **完整闭合** 的数学片段会进入 LaTeX 渲染流程
- 未闭合分隔符在 `streaming` 模式下会保留为普通文本，避免中间态闪烁
- 独立一段的 block 数学会被识别为单独块元素

## Streaming 策略

`MarkdownMath.RenderMode.streaming` 主要做两件事：

### 1. 补全未闭合代码围栏

如果流式输出中出现：

<pre><code>```swift
let value = 42
</code></pre>

内部会在解析前临时补一个结束围栏，使 `swift-markdown` 仍然能稳定识别为代码块。

### 2. 跳过未完成数学

如果流式输出中出现：

```text
The result is $x^2 +
```

不会错误地把整段当成数学公式，而是先按普通文本展示，等闭合后再恢复为公式。

## 排版策略

### Inline Math Baseline

- inline 内容统一通过 `LaTeXSwiftUI` 渲染
- 默认启用 `.script(.cjk)`，改善中文上下文中的公式高度与基线表现
- 默认沿用系统 `Font.body / title / headline` 语义字号

### Block Math Overflow

- block 数学优先尝试常规宽度布局
- 如果内容超出可用宽度，则自动切换到水平滚动容器
- 目标是优先保留公式完整性，而不是强制压缩到窄列

### Code Block

- 代码块使用横向滚动容器
- 默认使用 monospaced 字体
- 保留语言标签显示

## 当前支持的块级元素

- 标题
- 段落
- 引用
- 有序列表
- 无序列表
- 代码块
- 图片
- 分隔线
- 独立 block 数学

## 当前限制

当前实现还是第一版原型，以下能力尚未补齐：

- 尚未完整覆盖 GFM 所有语法细节
- 暂未实现表格、任务列表、脚注等专门样式
- 暂未对嵌套复杂 inline 结构做更细粒度的原生 SwiftUI 拼装
- 图片目前走 `AsyncImage` 的基础能力，未加入缓存与占位策略定制
- block math 的横向滚动已支持，但还没有渐隐遮罩、拖动提示等增强交互
- 还没有针对超长 AI 对话做增量 diff / 局部重排优化

## 包内结构

```text
Sources/MDMath/
├── MDMath.swift
├── MarkdownMathModels.swift
├── MarkdownMathExtractor.swift
├── MarkdownMathParser.swift
├── MarkdownStreamNormalizer.swift
└── MarkdownMathDocumentView.swift
```

职责说明：

- `MDMath.swift`：公开入口与主题定义
- `MarkdownMathExtractor.swift`：提取完整数学片段
- `MarkdownMathParser.swift`：将 Markdown AST 转换为内部块模型
- `MarkdownStreamNormalizer.swift`：处理 streaming 中的未闭合围栏
- `MarkdownMathDocumentView.swift`：将内部块模型渲染成 SwiftUI 视图

更详细的设计说明见：

- `docs/ARCHITECTURE.md`

## 测试

运行：

```bash
swift test
```

当前测试覆盖：

- 独立 block 数学识别
- streaming 模式下未闭合数学回退为文本
- streaming 模式下未闭合代码围栏自动补全

## 路线建议

如果下一步准备接入实际产品，建议优先继续补这些能力：

- 表格与任务列表支持
- 更细粒度的 inline token 渲染
- 增量更新与局部重排
- 代码块语法高亮
- 图片缓存 / 占位 / 点击放大
- 对 AI message / tool result 的专门样式层
