import Foundation
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

public struct MarkdownMathResourceOptions {
    public enum ResourceKind: Sendable {
        case link
        case image
    }

    public struct PrefixRewriteRule: Sendable, Equatable {
        public var prefix: String
        public var replacement: String

        public init(prefix: String, replacement: String) {
            self.prefix = prefix
            self.replacement = replacement
        }
    }

    public typealias AddressTransformer = @Sendable (_ source: String, _ kind: ResourceKind) -> String
    public typealias ImageURLResolver = @Sendable (_ source: String) -> URL?

    public var prefixRewriteRules: [PrefixRewriteRule]
    public var addressTransformer: AddressTransformer?
    public var imageURLResolver: ImageURLResolver?

    public init(
        prefixRewriteRules: [PrefixRewriteRule] = [],
        addressTransformer: AddressTransformer? = nil,
        imageURLResolver: ImageURLResolver? = nil
    ) {
        self.prefixRewriteRules = prefixRewriteRules
        self.addressTransformer = addressTransformer
        self.imageURLResolver = imageURLResolver
    }

    func rewriteAddress(_ source: String, kind: ResourceKind) -> String {
        let rewritten = prefixRewriteRules.firstMatch(in: source) ?? source
        return addressTransformer?(rewritten, kind) ?? rewritten
    }

    func resolveImageURL(for source: String) -> URL? {
        imageURLResolver?(source) ?? URL(string: source)
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
    private let resourceOptions: MarkdownMathResourceOptions

    public init(
        _ source: String,
        renderMode: RenderMode = .final,
        theme: MarkdownMathTheme = .init(),
        resourceOptions: MarkdownMathResourceOptions = .init()
    ) {
        self.source = source
        self.renderMode = renderMode
        self.theme = theme
        self.resourceOptions = resourceOptions
    }

    public var body: some View {
        MarkdownMathDocumentView(
            document: MarkdownMathParser.parse(
                source,
                renderMode: renderMode,
                resourceOptions: resourceOptions
            ),
            theme: theme,
            renderMode: renderMode,
            resourceOptions: resourceOptions
        )
    }
}

private extension Array where Element == MarkdownMathResourceOptions.PrefixRewriteRule {
    func firstMatch(in source: String) -> String? {
        for rule in self where source.hasPrefix(rule.prefix) {
            return rule.replacement + source.dropFirst(rule.prefix.count)
        }
        return nil
    }
}
