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
                    kind: .code(
                        language: "swift",
                        content: "let query = \"a very long line that should overflow in a narrow container\""
                    ),
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

        let rendered = await renderer.render(
            document: document,
            configuration: .init(),
            layoutWidth: 120
        )
        #expect(rendered.blocks.count == 2)
        let requiresScroll = rendered.blocks.filter { $0.layout.overflowIntent == .scroll }.count
        #expect(requiresScroll == rendered.blocks.count)
    }

    @Test
    func shortCodeBlockUsesNaturalLayoutIntentWhenItFits() async {
        let renderer = MarkdownRenderer()
        let document = RenderDocument(
            source: "",
            blocks: [
                .init(
                    id: "code",
                    stableKey: "code",
                    kind: .code(language: "swift", content: "print(1)"),
                    isStable: true
                )
            ],
            unstableTail: false
        )

        let rendered = await renderer.render(
            document: document,
            configuration: .init(),
            layoutWidth: 320
        )

        #expect(rendered.blocks.first?.layout.overflowIntent == .natural)
    }

    @MainActor
    @Test
    func blockMathReceivesWidthConstraintAndPrecomputedIntent() async {
        let renderer = MarkdownRenderer()
        let request = MathRenderRequest(
            latex: "\\int_0^1 x^2 \\, dx",
            displayMode: .block,
            fontSize: 17,
            scale: 1.15,
            foregroundHex: "#111827",
            widthConstraint: 240
        )
        MathLayoutCache.shared.insert(
            request: request,
            metrics: .init(width: 180, height: 32, ascent: 32, descent: 0),
            imageData: nil,
            imageScale: nil
        )

        let document = RenderDocument(
            source: "",
            blocks: [
                .init(
                    id: "math",
                    stableKey: "math",
                    kind: .math(.init(latex: "\\int_0^1 x^2 \\, dx", displayMode: .block)),
                    isStable: true
                )
            ],
            unstableTail: false
        )

        let rendered = await renderer.render(
            document: document,
            configuration: .init(),
            layoutWidth: 240
        )

        guard case .math(let mathRequest) = rendered.blocks.first?.content else {
            Issue.record("应生成 math request")
            return
        }

        #expect(mathRequest.widthConstraint == 240)
        #expect(rendered.blocks.first?.layout.overflowIntent == .natural)
    }
}
