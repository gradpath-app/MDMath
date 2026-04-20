# MDMath

MDMath 是一个 iOS-first 的 Markdown 排版 Swift Package，面向 AI / chat 消息渲染场景设计。它使用 `swift-markdown` 解析 Markdown，用本地 KaTeX + `WKWebView` 渲染数学公式，并通过 block 级模型支持 streaming、缓存、baseline 对齐和横向 overflow 控制。

- GitHub: `https://github.com/gradpath-app/MDMath.git`
- Gitea: `https://git.gradpath.spokey.cn/gradpath/MDMath.git`

## 特性

- 原生 SwiftUI 文档视图树，不把整篇 Markdown 放进单个 WebView
- 支持 inline math / display math，KaTeX 资源本地打包，不走 CDN
- 支持 inline baseline 对齐、display math 尺寸稳定和横向滚动
- 支持段落、标题、列表、引用、链接、粗斜体、行内代码、代码块、表格、图片
- 支持 AI tool call / tool output streaming 事件模型
- 支持未闭合公式、未闭合 code fence、半截表格、半截 tool arguments 的容错尾部
- 支持 `DocumentParseCache`、`BlockRenderCache`、`MathLayoutCache` 多级缓存

## 架构

MDMath 按四层组织：

1. Parser Layer：保护数学 token，解析 Markdown AST，产出 `RenderDocument`
2. Render Layer：把 IR 转为 block 级渲染模型、布局意图和数学渲染请求
3. Display Layer：用 SwiftUI 渲染文档主体，用 KaTeX WebView 渲染数学节点
4. Coordinator Layer：管理 streaming、frontier 增量更新、缓存失效和视图身份稳定性

## 环境要求

- Xcode 26+
- Swift 6
- iOS 18+

当前只覆盖 iOS，不承诺 macOS / tvOS / watchOS / visionOS 兼容。

## 安装

### Swift Package

推荐使用 GitHub 远程：

```swift
.package(url: "https://github.com/gradpath-app/MDMath.git", branch: "main")
```

也可以使用 Gitea 远程：

```swift
.package(url: "https://git.gradpath.spokey.cn/gradpath/MDMath.git", branch: "main")
```

然后添加 target 依赖：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "MDMath"
    ]
)
```

### 本地 vendor

如果作为主工程 vendor 包接入：

```swift
.package(path: "vendor/MDMath")
```

## 基础用法

### 静态块级 Markdown

```swift
import MDMath
import SwiftUI

struct DemoView: View {
    private let markdown = """
    已知有界区域 $\\Omega$ 由下式围成：

    $$\\iiint_{\\Omega} f(x^2+y^2+z^2)\\, dV$$

    以及行内公式 $E = mc^2$。
    """

    var body: some View {
        ScrollView {
            MarkdownBlock(markdown: markdown)
                .padding(16)
        }
    }
}
```

### 行内 Markdown

```swift
MarkdownInline(
    markdown: "结论：$\\frac{\\partial F}{\\partial u}=v f(u^2)$"
)
```

## Streaming 用法

流式消息推荐使用 `MarkdownStreamDocument`。不要每个 token 都重新传一整段 Markdown；这样会放大解析、渲染和 SwiftUI diff 成本。

```swift
import MDMath
import SwiftUI

struct ChatMessageView: View {
    @State private var document = MarkdownStreamDocument()

    var body: some View {
        StreamingMarkdownBlock(document: document)
            .task {
                document.apply(.textDelta("先输出正文\\n\\n"))
                document.apply(.textDelta("已知 $x^2 + y^2 = 1$。"))
            }
    }
}
```

### Streaming 事件

```swift
MarkdownStreamEvent.textDelta(String)
MarkdownStreamEvent.toolCallStart(id:name:)
MarkdownStreamEvent.toolArgumentsDelta(id:delta:)
MarkdownStreamEvent.toolCallEnd(id:)
MarkdownStreamEvent.toolOutput(id:content:language:)
MarkdownStreamEvent.replaceAll(String)
```

### Tool call 映射

```swift
document.apply(.textDelta("正在查询资料。\\n\\n"))
document.apply(.toolCallStart(id: "tool-1", name: "search"))
document.apply(.toolArgumentsDelta(id: "tool-1", delta: "{\"query\":\"gradpath markdown\""))
document.apply(.toolArgumentsDelta(id: "tool-1", delta: ",\"top_k\":5}"))
document.apply(.toolCallEnd(id: "tool-1"))
document.apply(.toolOutput(id: "tool-1", content: "[{\"title\":\"MDMath\"}]", language: "json"))
document.apply(.textDelta("\\n\\n下面继续回答。"))
```

## 配置

```swift
let configuration = MarkdownConfiguration(
    theme: .default,
    math: MarkdownMathConfiguration(
        fontSize: 17,
        inlineScale: 1.0,
        blockScale: 1.15,
        textAlignment: .leading,
        foregroundHex: "#111827"
    ),
    overflowBehavior: .scrollIfNeeded,
    baseURL: URL(string: "https://example.com/content/"),
    streamingBatchWindow: .milliseconds(24)
)
```

```swift
MarkdownBlock(
    markdown: markdown,
    configuration: configuration
)
```

### Overflow

`MarkdownOverflowBehavior` 控制代码块、表格、display math 和 tool output 的横向溢出行为：

```swift
MarkdownOverflowBehavior.wrap
MarkdownOverflowBehavior.scrollIfNeeded
```

默认值是 `.scrollIfNeeded`。

### 图片

相对路径图片需要配置 `baseURL`：

```swift
let configuration = MarkdownConfiguration(
    baseURL: URL(string: "https://example.com/content/")
)
```

## 公开 API

主要公开入口：

```swift
MarkdownBlock
MarkdownInline
StreamingMarkdownBlock
MarkdownConfiguration
MarkdownTheme
MarkdownMathConfiguration
MarkdownOverflowBehavior
MarkdownStreamDocument
MarkdownStreamEvent
```

内部核心类型包括 `RenderDocument`、`RenderBlock`、`RenderInline`、`MathRenderRequest`、`ToolCallNode`、`IncompleteNode`，不作为上层稳定 API 使用。

## 接入建议

- 聊天 streaming 消息：使用 `StreamingMarkdownBlock(document:)`
- 消息完成后的只读展示：可以继续持有同一个 `MarkdownStreamDocument`，也可以落成字符串后使用 `MarkdownBlock(markdown:)`
- 标题、列表项等短内容：使用 `MarkdownInline(markdown:)`
- 高频 token 流：优先映射成 `MarkdownStreamEvent`，避免全量重传整串 markdown
- 同一个消息 cell 内复用同一个 `MarkdownStreamDocument`，不要在 `body` 中反复创建

## 迁移说明

这是非兼容重写：

- 不保留旧 `StructuredText / InlineText` 接口
- 块级内容迁移到 `MarkdownBlock`
- 行内内容迁移到 `MarkdownInline`
- AI streaming 从“整串 markdown 全量替换”迁移到 `MarkdownStreamDocument` 事件模型

## 验证

首测设备固定为 iPhone 17 Pro：

```bash
xcodebuild -scheme MDMath -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

当前默认 `swift test` 不作为首选验证方式，因为包是 iOS-first，并依赖 `UIKit` / `WebKit`。

## 最小接入清单

1. 把 `MDMath` 加入上层 target 依赖
2. 普通展示使用 `MarkdownBlock(markdown:)`
3. 流式聊天消息使用 `MarkdownStreamDocument + StreamingMarkdownBlock`
4. 模型输出 token 映射到 `MarkdownStreamEvent`
5. 有相对图片时配置 `baseURL`

