import Foundation
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

@Test
func rewritesStandaloneImageSourceUsingPrefixRule() {
    let resourceOptions = MarkdownMathResourceOptions(
        prefixRewriteRules: [
            .init(prefix: "/images/", replacement: "../media/")
        ]
    )

    let document = MarkdownMathParser.parse(
        "![](/images/abc.png)",
        renderMode: .final,
        resourceOptions: resourceOptions
    )

    #expect(document.blocks == [.image(source: "../media/abc.png", alt: "")])
}

@Test
func rewritesInlineLinksAndImagesUsingSharedRules() {
    let resourceOptions = MarkdownMathResourceOptions(
        prefixRewriteRules: [
            .init(prefix: "/images/", replacement: "../media/"),
            .init(prefix: "/docs/", replacement: "app://docs/")
        ]
    )

    let document = MarkdownMathParser.parse(
        "查看[说明](/docs/intro) 和 ![封面](/images/cover.png)",
        renderMode: .final,
        resourceOptions: resourceOptions
    )

    #expect(document.blocks == [.paragraph("查看[说明](app://docs/intro) 和 ![封面](../media/cover.png)")])
}

@Test
func resolvesImageURLWithCustomResolverBeforeDefaultURLParsing() {
    let resourceOptions = MarkdownMathResourceOptions(
        imageURLResolver: { source in
            URL(string: "app://resolved/\(source)")
        }
    )

    let resolvedURL = resourceOptions.resolveImageURL(for: "media/abc.png")

    #expect(resolvedURL?.absoluteString == "app://resolved/media/abc.png")
}
