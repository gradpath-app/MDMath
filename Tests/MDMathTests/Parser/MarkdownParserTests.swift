import Testing
@testable import MDMath

struct MarkdownParserTests {
    @Test
    func parsesInlineAndBlockMath() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            已知 $x^2 + y^2 = 1$。

            $$\\int_0^1 x^2\\,dx = \\frac{1}{3}$$
            """
        )

        #expect(document.blocks.count == 2)

        guard case .paragraph(let runs) = document.blocks[0].kind else {
            Issue.record("第一段应为段落")
            return
        }

        #expect(runs.contains {
            if case .math(let math) = $0 {
                return math.displayMode == .inline && math.latex == "x^2 + y^2 = 1"
            }
            return false
        })

        guard case .math(let math) = document.blocks[1].kind else {
            Issue.record("第二段应为 block math")
            return
        }

        #expect(math.displayMode == .block)
        #expect(math.latex == "\\int_0^1 x^2\\,dx = \\frac{1}{3}")
    }

    @Test
    func preservesMultilineInlineMath() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            设直线 $\\begin{cases}
            x=0,\\\\
            y=0
            \\end{cases}$ 绕轴旋转
            """
        )

        guard case .paragraph(let runs) = document.blocks.first?.kind else {
            Issue.record("应解析为段落")
            return
        }

        let mathRuns = runs.compactMap { inline -> MathNode? in
            if case .math(let math) = inline { return math }
            return nil
        }

        #expect(mathRuns.count == 1)
        #expect(mathRuns.first?.latex == "\\begin{cases}\nx=0,\\\\\ny=0\n\\end{cases}")
    }

    @Test
    func separatesBlockMathFromAdjacentParagraphs() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            已知有界区域 $\\Omega$ 由下式围成：

            $$\\iiint_{\\Omega} f(x^2+y^2+z^2)\\, dV$$

            以及行内公式 $E = mc^2$ 在中文文本里应保持良好的 baseline。
            """
        )

        #expect(document.blocks.count == 3)

        guard case .paragraph = document.blocks[safe: 0]?.kind else {
            Issue.record("第一块应为段落")
            return
        }

        guard case .math(let math) = document.blocks[safe: 1]?.kind else {
            Issue.record("第二块应为 block math")
            return
        }

        #expect(math.displayMode == .block)
        #expect(math.latex == "\\iiint_{\\Omega} f(x^2+y^2+z^2)\\, dV")

        guard case .paragraph(let runs) = document.blocks[safe: 2]?.kind else {
            Issue.record("第三块应为段落")
            return
        }

        #expect(runs.contains {
            if case .math(let inlineMath) = $0 {
                return inlineMath.displayMode == .inline && inlineMath.latex == "E = mc^2"
            }
            return false
        })
    }

    @Test
    func marksUnclosedCodeFenceAsUnstableTail() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            ```json
            {"a": 1
            """
        )

        #expect(document.unstableTail)
        #expect(document.blocks.contains {
            if case .incomplete(let node) = $0.kind {
                return node.kind == .codeFence
            }
            return false
        })
    }

    @Test
    func assignsUniqueIDsToDuplicateBlocks() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            重复段落

            重复段落
            """
        )

        let ids = document.blocks.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test
    func marksIncompleteTableTail() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: """
            | 字段 | 值 |
            | --- | --- |
            | a |
            """
        )

        #expect(document.unstableTail)
        #expect(document.blocks.contains {
            if case .incomplete(let node) = $0.kind {
                return node.kind == .table
            }
            return false
        })
    }

    @Test
    func parserBuildsToolNodesAndStreamingToolArgumentPlaceholder() {
        let parser = MarkdownParser()
        let document = parser.parse(
            markdown: "先输出正文",
            toolCalls: [
                ToolCallNode(
                    id: "tool-1",
                    name: "search",
                    arguments: "{\"q\":\"gradpath\"",
                    output: nil,
                    outputLanguage: nil,
                    state: .streaming
                )
            ]
        )

        #expect(document.blocks.contains {
            if case .toolCall(let node) = $0.kind {
                return node.id == "tool-1" && node.name == "search"
            }
            return false
        })

        #expect(document.blocks.contains {
            if case .incomplete(let node) = $0.kind {
                return node.kind == .toolArguments
            }
            return false
        })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
