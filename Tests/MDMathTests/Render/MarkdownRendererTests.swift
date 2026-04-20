import Testing
@testable import MDMath

struct MarkdownRendererTests {
    @Test
    func codeAndTablesRequireHorizontalOverflowHandling() async {
        let renderer = MarkdownRenderer()
        let document = RenderDocument(
            source: "",
            blocks: [
                .init(
                    id: "code",
                    stableKey: "code",
                    kind: .code(language: "swift", content: "print(1)"),
                    isStable: true
                ),
                .init(
                    id: "table",
                    stableKey: "table",
                    kind: .table(
                        .init(
                            rows: [[
                                .init(content: [.text("A")], isHeader: true),
                                .init(content: [.text("B")], isHeader: true)
                            ]]
                        )
                    ),
                    isStable: true
                )
            ],
            unstableTail: false
        )

        let rendered = await renderer.render(document: document, configuration: .init())
        #expect(rendered.blocks.count == 2)
        let requiresScroll = rendered.blocks.filter(\.layout.requiresHorizontalScroll).count
        #expect(requiresScroll == rendered.blocks.count)
    }
}
