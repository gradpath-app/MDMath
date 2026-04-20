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
}
