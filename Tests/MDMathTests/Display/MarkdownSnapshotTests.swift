#if os(iOS)
import SnapshotTesting
import SwiftUI
import Testing

@testable import MDMath

@MainActor
struct MarkdownSnapshotTests {
    private static let shouldRecord = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

    private let layout = SwiftUISnapshotLayout.fixed(width: 402, height: 874)

    @Test
    func mathLayout() async {
        let markdown = """
            已知有界区域 $\\Omega$ 由下式围成：

            $$\\iiint_{\\Omega} f(x^2+y^2+z^2)\\, dV$$

            以及行内公式 $E = mc^2$ 在中文文本里应保持良好的 baseline。
            """
        await warmMathCache(for: markdown)

        let view = SnapshotContainer {
            MarkdownBlock(
                markdown: markdown
            )
            .padding(20)
        }

        assertSnapshot(
            of: view,
            as: .wait(for: 0.4, on: .image(layout: layout)),
            record: Self.shouldRecord ? .all : nil
        )
    }

    @Test
    func overflowBlocks() async {
        let markdown = """
            下面的代码块、表格和 display math 都应走统一 overflow scroll 容器。

            ```json
            {"tool":"search","arguments":{"query":"a very long query string that should overflow horizontally for snapshot verification","top_k":10,"filters":["school","subject","chapter"]}}
            ```

            | 字段 | 描述 |
            | --- | --- |
            | very_long_column_name | this is a deliberately long cell used to verify horizontal overflow behavior |

            $$\\sum_{k=1}^{n} \\frac{1}{k(k+1)} = 1 - \\frac{1}{n+1}$$
            """
        await warmMathCache(for: markdown)

        let view = SnapshotContainer {
            MarkdownBlock(
                markdown: markdown
            )
            .padding(20)
        }

        assertSnapshot(
            of: view,
            as: .wait(for: 0.4, on: .image(layout: layout)),
            record: Self.shouldRecord ? .all : nil
        )
    }

    @Test
    func examQuestionMathLayout() async {
        let markdown = """
            题干核心公式：

            $$\\iint_{D} \\frac{f\\left(x^{2}+y^{2}\\right)}{\\sqrt{x^{2}+y^{2}}}\\, dx\\, dy$$

            对照 display math 中体积分写法：

            $$\\iiint_{\\Omega} f\\left(x^{2}+y^{2}+z^{2}\\right)\\, dV$$

            解析核心公式：

            $$\\int_{0}^{v} d\\theta \\int_{1}^{u} f\\left(r^{2}\\right)\\, dr$$

            结论：$\\frac{\\partial F}{\\partial u}=v f\\left(u^{2}\\right)$
            """
        await warmMathCache(for: markdown)

        let view = SnapshotContainer {
            MarkdownBlock(
                markdown: markdown
            )
            .padding(20)
        }

        assertSnapshot(
            of: view,
            as: .wait(for: 0.4, on: .image(layout: layout)),
            record: Self.shouldRecord ? .all : nil
        )
    }

    @Test
    func streamingToolState() async {
        let document = MarkdownStreamDocument(configuration: .init(streamingBatchWindow: .zero))
        document.apply(.textDelta("AI 正在调用工具并逐步补全参数。"))
        document.apply(.toolCallStart(id: "tool-1", name: "search"))
        document.apply(.toolArgumentsDelta(id: "tool-1", delta: "{\"query\":\"gradpath markdown package\""))
        document.apply(.toolArgumentsDelta(id: "tool-1", delta: ",\"top_k\":5}"))
        document.apply(.toolOutput(id: "tool-1", content: "[{\"title\":\"MDMath\"}]", language: "json"))
        await document.rebuildNow()

        let view = SnapshotContainer {
            StreamingMarkdownBlock(document: document)
                .padding(20)
        }

        assertSnapshot(
            of: view,
            as: .wait(for: 0.3, on: .image(layout: layout)),
            record: Self.shouldRecord ? .all : nil
        )
    }
}

extension MarkdownSnapshotTests {
    private func warmMathCache(
        for markdown: String,
        configuration: MarkdownConfiguration = .init()
    ) async {
        let parser = MarkdownParser()
        let renderer = MarkdownRenderer()
        let document = parser.parse(markdown: markdown)
        let rendered = renderer.render(document: document, configuration: configuration)

        for request in mathRequests(in: rendered.blocks, configuration: configuration) {
            _ = await MathRenderService.shared.render(request: request)
        }
    }

    private func mathRequests(
        in blocks: [RenderedBlock],
        configuration: MarkdownConfiguration
    ) -> [MathRenderRequest] {
        blocks.flatMap { mathRequests(in: $0, configuration: configuration) }
    }

    private func mathRequests(
        in block: RenderedBlock,
        configuration: MarkdownConfiguration
    ) -> [MathRenderRequest] {
        switch block.content {
        case .paragraph(let runs):
            mathRequests(in: runs, configuration: configuration)
        case .heading(_, let runs):
            mathRequests(in: runs, configuration: configuration)
        case .quote(let blocks):
            mathRequests(in: blocks, configuration: configuration)
        case .unorderedList(let items):
            items.flatMap { mathRequests(in: $0, configuration: configuration) }
        case .orderedList(_, let items):
            items.flatMap { mathRequests(in: $0, configuration: configuration) }
        case .math(let request):
            [request]
        case .table(let table):
            table.rows.flatMap { row in
                row.flatMap { cell in
                    mathRequests(in: cell.content, configuration: configuration)
                }
            }
        default:
            []
        }
    }

    private func mathRequests(
        in runs: [RenderInline],
        configuration: MarkdownConfiguration
    ) -> [MathRenderRequest] {
        runs.reduce(into: [MathRenderRequest]()) { requests, run in
            switch run {
            case .math(let math):
                requests.append(
                    MathRenderRequest(
                        latex: math.latex,
                        displayMode: math.displayMode,
                        fontSize: configuration.math.fontSize,
                        scale: math.displayMode == .inline ? configuration.math.inlineScale : configuration.math.blockScale,
                        foregroundHex: configuration.math.foregroundHex,
                        widthConstraint: nil
                    )
                )
            case .emphasis(let nested), .strong(let nested):
                requests.append(contentsOf: mathRequests(in: nested, configuration: configuration))
            case .link(let label, _):
                requests.append(contentsOf: mathRequests(in: label, configuration: configuration))
            default:
                break
            }
        }
    }
}

private struct SnapshotContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.white
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 402, height: 874)
    }
}
#endif
