import SwiftUI

public struct MarkdownConfiguration {
    public var theme: MarkdownTheme
    public var math: MarkdownMathConfiguration
    public var overflowBehavior: MarkdownOverflowBehavior
    public var baseURL: URL?
    public var streamingBatchWindow: Duration

    public init(
        theme: MarkdownTheme = .default,
        math: MarkdownMathConfiguration = .default,
        overflowBehavior: MarkdownOverflowBehavior = .scrollIfNeeded,
        baseURL: URL? = nil,
        streamingBatchWindow: Duration = .milliseconds(24)
    ) {
        self.theme = theme
        self.math = math
        self.overflowBehavior = overflowBehavior
        self.baseURL = baseURL
        self.streamingBatchWindow = streamingBatchWindow
    }
}

public struct MarkdownTheme {
    public var bodyFont: Font
    public var headingFont: Font
    public var codeFont: Font
    public var textColor: Color
    public var secondaryTextColor: Color
    public var linkColor: Color
    public var codeBackgroundColor: Color
    public var quoteAccentColor: Color
    public var tableBorderColor: Color
    public var blockBackgroundColor: Color
    public var blockSpacing: CGFloat
    public var inlineSpacing: CGFloat

    public init(
        bodyFont: Font,
        headingFont: Font,
        codeFont: Font,
        textColor: Color,
        secondaryTextColor: Color,
        linkColor: Color,
        codeBackgroundColor: Color,
        quoteAccentColor: Color,
        tableBorderColor: Color,
        blockBackgroundColor: Color,
        blockSpacing: CGFloat,
        inlineSpacing: CGFloat
    ) {
        self.bodyFont = bodyFont
        self.headingFont = headingFont
        self.codeFont = codeFont
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.linkColor = linkColor
        self.codeBackgroundColor = codeBackgroundColor
        self.quoteAccentColor = quoteAccentColor
        self.tableBorderColor = tableBorderColor
        self.blockBackgroundColor = blockBackgroundColor
        self.blockSpacing = blockSpacing
        self.inlineSpacing = inlineSpacing
    }

    public static let `default` = MarkdownTheme(
        bodyFont: .body,
        headingFont: .title3.weight(.semibold),
        codeFont: .system(.body, design: .monospaced),
        textColor: .primary,
        secondaryTextColor: .secondary,
        linkColor: .blue,
        codeBackgroundColor: Color(uiColor: .secondarySystemBackground),
        quoteAccentColor: Color(uiColor: .systemBlue),
        tableBorderColor: Color(uiColor: .separator),
        blockBackgroundColor: Color(uiColor: .secondarySystemBackground),
        blockSpacing: 12,
        inlineSpacing: 4
    )
}

public struct MarkdownMathConfiguration: Hashable, Sendable {
    public var fontSize: CGFloat
    public var inlineScale: CGFloat
    public var blockScale: CGFloat
    public var textAlignment: TextAlignment
    public var foregroundHex: String

    public init(
        fontSize: CGFloat = 17,
        inlineScale: CGFloat = 1.0,
        blockScale: CGFloat = 1.15,
        textAlignment: TextAlignment = .leading,
        foregroundHex: String = "#111827"
    ) {
        self.fontSize = fontSize
        self.inlineScale = inlineScale
        self.blockScale = blockScale
        self.textAlignment = textAlignment
        self.foregroundHex = foregroundHex
    }

    public static let `default` = MarkdownMathConfiguration()
}

public enum MarkdownOverflowBehavior: String, Hashable, Sendable {
    case wrap
    case scrollIfNeeded
}
