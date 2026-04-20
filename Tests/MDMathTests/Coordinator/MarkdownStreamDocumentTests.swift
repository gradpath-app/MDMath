import Foundation
import Testing
@testable import MDMath

@MainActor
struct MarkdownStreamDocumentTests {
    @Test
    func accumulatesToolStreamingState() async {
        let document = MarkdownStreamDocument(configuration: .init(streamingBatchWindow: .zero))

        document.apply(.textDelta("先输出正文"))
        document.apply(.toolCallStart(id: "tool-1", name: "search"))
        document.apply(.toolArgumentsDelta(id: "tool-1", delta: "{\"q\":\"hi\""))
        document.apply(.toolArgumentsDelta(id: "tool-1", delta: "}"))
        document.apply(.toolCallEnd(id: "tool-1"))
        document.apply(.toolOutput(id: "tool-1", content: "[]", language: "json"))
        await document.rebuildNow()

        #expect(document.renderedDocument.blocks.contains {
            if case .toolCall(let tool) = $0.content {
                return tool.id == "tool-1" && tool.arguments == "{\"q\":\"hi\"}" && tool.state == .completed
            }
            return false
        })

        #expect(document.renderedDocument.blocks.contains {
            if case .toolOutput(let language, let content, let id) = $0.content {
                return id == "tool-1" && language == "json" && content == "[]"
            }
            return false
        })
    }

    @Test
    func rendersPlainChineseTextSynchronously() {
        let coordinator = MarkdownCoordinator()
        let rendered = coordinator.renderedDocument(
            markdown: "高等数学",
            toolCalls: [],
            configuration: .init(),
            layoutWidth: nil
        )

        #expect(rendered.blocks.count == 1)
        guard case .paragraph(let runs) = rendered.blocks.first?.content else {
            Issue.record("应渲染为段落块")
            return
        }
        #expect(runs.contains {
            if case .text(let t) = $0 { return t == "高等数学" }
            return false
        })
    }

    @Test
    func keepsUniqueIDsAcrossStablePrefixAndTail() async {
        let coordinator = MarkdownCoordinator()
        let rendered = coordinator.renderedDocument(
            markdown: """
            重复段落

            重复段落
            """,
            toolCalls: [],
            configuration: .init(),
            layoutWidth: 320
        )

        let ids = rendered.blocks.map(\.id)
        #expect(ids.count == Set(ids).count)
    }
}
