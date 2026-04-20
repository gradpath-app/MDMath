# MDMath

基于 `swift-markdown` 与 `LaTeXSwiftUI` 的 SwiftUI Markdown 排版包，目标是更适合 AI 输出与数学公式混排。

## 特性

- 使用 `swift-markdown` 做块级 AST 解析
- 使用 `LaTeXSwiftUI` 负责 inline / block 数学公式渲染
- 提供 `streaming` 模式，容忍 AI 输出中的未闭合代码围栏与未完成公式
- block 公式默认支持超宽时水平滚动
- inline 数学公式沿用系统字号，并默认按 CJK 文本度量做基线匹配

## 安装

```swift
.package(url: "https://github.com/your-org/MDMath.git", branch: "main")
```

## 使用

```swift
import MDMath

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
