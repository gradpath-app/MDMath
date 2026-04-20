import Testing
@testable import MDMath

@Test
func extractsStandaloneMathBlocks() {
    let document = MarkdownMathParser.parse("$$x^2 + y^2 = z^2$$", renderMode: .final)
    #expect(document.blocks == [.mathBlock("$$x^2 + y^2 = z^2$$")])
}

@Test
func keepsIncompleteStreamingMathAsPlainParagraph() {
    let document = MarkdownMathParser.parse("The result is $x^2 +", renderMode: .streaming)
    #expect(document.blocks == [.paragraph("The result is \\$x^2 +")])
}

@Test
func closesUnfinishedFencesDuringStreamingPreview() {
    let document = MarkdownMathParser.parse(
        """
        ```swift
        let value = 42
        """,
        renderMode: .streaming
    )

    #expect(document.blocks == [.codeBlock(language: "swift", code: "let value = 42\n")])
}
