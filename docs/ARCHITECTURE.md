# MDMath 架构说明

## 总览

`MDMath` 的目标不是做一个“完整的 Markdown 浏览器”，而是做一个偏 **AI 聊天 / 工具输出 / 数学内容展示** 的排版层。

设计上拆成 4 层：

```text
Raw Markdown
    ↓
Streaming Normalize
    ↓
Math Extract
    ↓
swift-markdown AST
    ↓
Internal Block Model
    ↓
SwiftUI Rendering + LaTeXSwiftUI
```

## 分层说明

### 1. Streaming Normalize

文件：

- `Sources/MDMath/MarkdownStreamNormalizer.swift`

职责：

- 在 `streaming` 模式下对中间态文本做“最小修复”
- 当前只处理未闭合代码围栏

原则：

- 只做让解析器“更稳定”的修复
- 不做语义猜测过强的自动补全
- 尽量保证最终完整文本到来后，不会与中间态逻辑冲突

### 2. Math Extract

文件：

- `Sources/MDMath/MarkdownMathExtractor.swift`

职责：

- 在进入 `swift-markdown` 前，先提取完整数学片段
- 用占位符替换，避免 Markdown 解析阶段破坏数学分隔符

为什么先抽数学：

- `$...$` 很容易和普通文本、转义字符、流式中间态互相干扰
- 若直接交给 Markdown 解析，恢复成本更高
- 先抽取能把“完整数学”和“未完成数学”明确区分开

当前支持的数学边界：

- `$...$`
- `$$...$$`
- `\\(...\\)`
- `\\[...\\]`
- `\\begin{...}...\\end{...}`

### 3. Markdown AST → Internal Block Model

文件：

- `Sources/MDMath/MarkdownMathParser.swift`
- `Sources/MDMath/MarkdownMathModels.swift`

职责：

- 使用 `swift-markdown` 解析块级结构
- 转换成包内部更稳定的块模型
- 在转换 inline link / image 与 block image 时应用资源地址重写规则

为什么不直接把 AST 渲染成 SwiftUI：

- 外部渲染层最好不要直接耦合第三方 AST 细节
- 内部块模型更适合后续做 streaming diff、主题系统和平台定制
- 有利于将来替换渲染层或补充额外语义节点

当前块模型包括：

- `paragraph`
- `heading`
- `blockquote`
- `unorderedList`
- `orderedList`
- `codeBlock`
- `mathBlock`
- `image`
- `thematicBreak`

### 4. SwiftUI Rendering

文件：

- `Sources/MDMath/MarkdownMathDocumentView.swift`

职责：

- 将内部块模型映射到 SwiftUI
- inline / block 数学统一使用 `LaTeXSwiftUI`
- 控制滚动、字号、留白、容器样式
- block 图片可通过自定义 resolver 将相对地址转成 App 内可加载的 `URL`

核心策略：

- 普通文本与 inline math 共用同一套 `LaTeX(...)` 视图
- block math 单独包裹在 overflow 容器中
- 代码块优先保证横向可滚动，而不是换行压缩

## 主题系统

文件：

- `Sources/MDMath/MDMath.swift`

`MarkdownMathTheme` 目前是轻量级主题层，用来统一：

- 文本字号
- 标题字号
- 代码字体
- 块间距
- 列表项间距
- 内容内边距
- 圆角
- 是否启用 CJK inline 数学度量

这个主题层的目标不是做完整 Design System，而是先把“和系统字号对齐”这件事固定住。

## 关于 baseline 和字号匹配

当前策略：

- 默认使用 SwiftUI 语义字体，如 `.body`、`.title`
- inline 数学默认使用 `.script(.cjk)`

这样做的原因：

- AI 聊天产品里常见的是中文 / 英文 / 数学混排
- 若按纯 Latin x-height 估算，公式容易显得偏小或偏低
- 使用 CJK 度量通常更接近中文正文视觉重心

## 关于 block overflow

block 数学与代码块都可能非常宽。

这里采取的策略不是自动缩放，而是：

- 优先按正常宽度布局
- 放不下时切到横向滚动

原因：

- 数学公式缩放过度会损失可读性
- AI 输出的代码与公式经常本来就应允许横向浏览

## 为什么先做“块级稳定”，再做“细粒度 inline”

这是有意取舍：

- AI 输出的首要问题通常是块结构稳定性
- 只要标题、段落、列表、代码块、公式这些主结构稳定，阅读体验就已经大幅提升
- 更细粒度的 inline token 渲染可以作为下一阶段优化

## 已知演进方向

后续可继续往这几个方向演进：

- 增量 diff 渲染，避免长文每次全量重排
- 更完整的 inline token tree
- 表格 / 任务列表 / 脚注 / 引用嵌套增强
- 代码高亮与复制工具栏
- 图片缩放、点击预览、缓存
- AI 消息级主题系统
