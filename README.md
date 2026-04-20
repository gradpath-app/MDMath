# MDMath

MDMath 是一个 iOS-first 的 Markdown 排版 Swift Package，面向 AI / chat 场景设计，按四层架构组织：

- Parser Layer：Markdown 与数学、tool streaming 语义解析
- Render Layer：块级渲染模型、布局意图与缓存
- Display Layer：SwiftUI 原生视图树 + KaTeX 数学显示
- Coordinator Layer：streaming 调度、frontier 增量更新、缓存串联

当前版本聚焦 iOS 聊天类 Markdown 子集，支持：

- 段落、标题、列表、引用
- 粗体、斜体、链接、行内代码、代码块
- 表格、图片
- inline math / display math
- AI tool call / tool output streaming
- 未闭合公式、未闭合 code fence、半截表格、半截 tool arguments 的容错尾部

## 环境要求

- Xcode 26+
- Swift 6
- iOS 18+

`Package.swift` 当前声明平台为 `.iOS(.v18)`。

## 安装方式

### 方式一：作为本地 Package 引入

如果 MDMath 以 vendor 形式存在于工程仓库中，可以直接在 Xcode 中 `Add Local...`，选择当前目录。

也可以在上层工程的 `Package.swift` 中使用本地路径：

```swift
.package(path: "vendor/MDMath")
```

然后把 `MDMath` 加入目标依赖：

```swift
.target(
    name: "YourFeature",
    dependencies: [
        "MDMath"
    ]
)
```

### 方式二：作为远程 Package 引入

如果后续仓库发布到 Git 仓库，可按标准 SPM 方式接入：

```swift
.package(url: "https://your.git/MDMath.git", branch: "main")
```

## 快速开始

### 1. 静态块级渲染

```swift
import MDMath
import SwiftUI

struct DemoView: View {
    let markdown = """
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

### 2. 静态行内渲染

适合标题、副标题、列表项等只需要一小段 inline markdown 的场景：

```swift
MarkdownInline(
    markdown: "结论：$\\frac{\\partial F}{\\partial u}=v f(u^2)$"
)
```

### 3. 自定义基础配置

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
    baseURL: URL(string: "https://example.com/assets/"),
    streamingBatchWindow: .milliseconds(24)
)
```

```swift
MarkdownBlock(
    markdown: markdown,
    configuration: configuration
)
```

## Streaming 接入

MDMath 的 streaming 入口不是“每次全量替换整串 markdown”，而是 `MarkdownStreamDocument + MarkdownStreamEvent`。

推荐接法：

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

### 可用事件

```swift
MarkdownStreamEvent.textDelta(String)
MarkdownStreamEvent.toolCallStart(id:name:)
MarkdownStreamEvent.toolArgumentsDelta(id:delta:)
MarkdownStreamEvent.toolCallEnd(id:)
MarkdownStreamEvent.toolOutput(id:content:language:)
MarkdownStreamEvent.replaceAll(String)
```

### AI 输出流推荐映射

如果你的上层模型流里同时包含正文与工具调用，建议按下面的方式映射：

1. 普通文本 token：映射为 `.textDelta(...)`
2. 工具开始：映射为 `.toolCallStart(id:name:)`
3. 工具参数增量：映射为 `.toolArgumentsDelta(id:delta:)`
4. 工具参数结束：映射为 `.toolCallEnd(id:)`
5. 工具返回结果：映射为 `.toolOutput(id:content:language:)`

示例：

```swift
document.apply(.textDelta("正在查询资料。\\n\\n"))
document.apply(.toolCallStart(id: "tool-1", name: "search"))
document.apply(.toolArgumentsDelta(id: "tool-1", delta: "{\"query\":\"gradpath markdown\""))
document.apply(.toolArgumentsDelta(id: "tool-1", delta: ",\"top_k\":5}"))
document.apply(.toolCallEnd(id: "tool-1"))
document.apply(.toolOutput(id: "tool-1", content: "[{\"title\":\"MDMath\"}]", language: "json"))
document.apply(.textDelta("\\n\\n下面继续回答。"))
```

## 显示行为说明

### 数学渲染

- 数学节点使用本地打包的 KaTeX 资源，不依赖 CDN
- 数学渲染通过 `WKWebView` 测量 `width / height / ascent / descent`
- inline math 会做 baseline 对齐
- display math 会根据容器宽度与测量结果决定是否横向滚动

### Overflow 行为

当前统一使用 `OverflowContainer` 处理横向溢出，覆盖：

- 代码块
- 表格
- display math
- tool output

可配置项：

```swift
MarkdownOverflowBehavior.wrap
MarkdownOverflowBehavior.scrollIfNeeded
```

默认是 `.scrollIfNeeded`。

### 图片

如果 markdown 中使用相对路径图片，需要传入 `baseURL`：

```swift
let configuration = MarkdownConfiguration(
    baseURL: URL(string: "https://example.com/content/")
)
```

## 公开 API

主要公开入口如下：

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

## 接入建议

### 聊天消息场景

推荐：

- 文本消息正文：`StreamingMarkdownBlock`
- 最终落库后纯展示：`MarkdownBlock`
- 标题 / 标签 / 小段 inline 内容：`MarkdownInline`

### 性能建议

- 流式输出时优先用 `MarkdownStreamDocument`，不要每个 token 都整串重传
- 同一个消息 cell 内复用同一个 `MarkdownStreamDocument`
- 消息完成后，可以保留同一个文档对象直接展示，减少视图重建

## 迁移说明

MDMath 当前是非兼容重写，接入时请按新接口迁移：

- 旧的 `StructuredText / InlineText` 不再保留
- 静态块内容迁移到 `MarkdownBlock`
- 静态行内内容迁移到 `MarkdownInline`
- AI streaming 从“整串 markdown 全量替换”迁移到 `MarkdownStreamDocument`

## 已知边界

- 当前只覆盖 iOS，不覆盖 macOS / tvOS / watchOS / visionOS
- 当前聚焦 AI/chat markdown 子集，不追求完整 GFM 全量特性
- tool call / tool output 属于聊天语义扩展，不是标准 Markdown 语法

## 验证方式

建议在 iPhone 17 Pro 模拟器上验证：

```bash
xcodebuild -scheme MDMath -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## 最小接入清单

如果你只想最快接入，可按下面做：

1. 把 `MDMath` 加到上层 target 依赖
2. 聊天消息正文用 `StreamingMarkdownBlock(document:)`
3. 普通只读展示用 `MarkdownBlock(markdown:)`
4. 模型流 token 映射到 `MarkdownStreamEvent`
5. 如果有相对图片，补 `baseURL`

