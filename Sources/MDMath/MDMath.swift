import LaTeXSwiftUI
import SwiftUI

public struct MarkdownMathTheme {
    public var bodyFont: Font
    public var codeFont: Font
    public var headingFonts: [Int: Font]
    public var blockSpacing: CGFloat
    public var listItemSpacing: CGFloat
    public var contentPadding: CGFloat
    public var blockCornerRadius: CGFloat
    public var usesCJKInlineMathMetrics: Bool

    public init(
        bodyFont: Font = .body,
        codeFont: Font = .callout.monospaced(),
        headingFonts: [Int: Font] = [
            1: .largeTitle,
            2: .title,
            3: .title2,
            4: .title3,
            5: .headline,
            6: .subheadline,
        ],
        blockSpacing: CGFloat = 14,
        listItemSpacing: CGFloat = 10,
        contentPadding: CGFloat = 12,
        blockCornerRadius: CGFloat = 12,
        usesCJKInlineMathMetrics: Bool = true
    ) {
        self.bodyFont = bodyFont
        self.codeFont = codeFont
        self.headingFonts = headingFonts
        self.blockSpacing = blockSpacing
        self.listItemSpacing = listItemSpacing
        self.contentPadding = contentPadding
        self.blockCornerRadius = blockCornerRadius
        self.usesCJKInlineMathMetrics = usesCJKInlineMathMetrics
    }
}

public struct MarkdownMath: View {
    public enum RenderMode: Sendable {
        case final
        case streaming
    }

    private let source: String
    private let renderMode: RenderMode
    private let theme: MarkdownMathTheme

    public init(
        _ source: String,
        renderMode: RenderMode = .final,
        theme: MarkdownMathTheme = .init()
    ) {
        self.source = source
        self.renderMode = renderMode
        self.theme = theme
    }

    public var body: some View {
        MarkdownMathDocumentView(
            document: MarkdownMathParser.parse(source, renderMode: renderMode),
            theme: theme,
            renderMode: renderMode
        )
    }
}
