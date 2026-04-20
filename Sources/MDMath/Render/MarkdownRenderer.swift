import Foundation
#if os(iOS)
import UIKit
#endif

struct RenderedDocumentModel: Hashable {
    var blocks: [RenderedBlock]
    var unstableTail: Bool
}

struct RenderedBlock: Identifiable, Hashable {
    enum OverflowLayoutIntent: Hashable {
        case natural
        case scroll
        case measure
    }

    enum Content: Hashable {
        case paragraph([RenderInline])
        case heading(level: Int, content: [RenderInline])
        case quote([RenderedBlock])
        case unorderedList([[RenderedBlock]])
        case orderedList(start: Int?, items: [[RenderedBlock]])
        case code(language: String?, content: String)
        case table(RenderTable)
        case math(MathRenderRequest)
        case toolCall(ToolCallNode)
        case toolOutput(language: String?, content: String, id: String)
        case image(source: String, alt: String)
        case thematicBreak
        case incomplete(IncompleteNode)
    }

    struct Layout: Hashable {
        var overflowBehavior: MarkdownOverflowBehavior

        var overflowIntent: OverflowLayoutIntent

        var requiresHorizontalScroll: Bool {
            overflowIntent == .scroll
        }
    }

    var id: String
    var stableKey: String
    var content: Content
    var layout: Layout
    var isStable: Bool
}

@MainActor
final class DocumentParseCache {
    private var storage: [String: RenderDocument] = [:]

    func value(for source: String) -> RenderDocument? {
        storage[source]
    }

    func insert(_ document: RenderDocument, for source: String) {
        storage[source] = document
    }
}

@MainActor
final class BlockRenderCache {
    private var storage: [String: RenderedBlock] = [:]

    func value(for cacheKey: String) -> RenderedBlock? {
        storage[cacheKey]
    }

    func insert(_ block: RenderedBlock, for cacheKey: String) {
        storage[cacheKey] = block
    }
}

@MainActor
final class MathLayoutCache {
    struct Metrics: Hashable {
        var width: CGFloat
        var height: CGFloat
        var ascent: CGFloat
        var descent: CGFloat
    }

    static let shared = MathLayoutCache()

    private(set) var requestCount = 0
    private var metricsStorage: [MathRenderRequest: Metrics] = [:]
    private var imageStorage: [MathRenderRequest: Data] = [:]
    private var imageScaleStorage: [MathRenderRequest: CGFloat] = [:]

    func metrics(for request: MathRenderRequest) -> Metrics? {
        metricsStorage[request]
    }

    func image(for request: MathRenderRequest) -> UIImage? {
        guard let data = imageStorage[request] else { return nil }
        let scale = imageScaleStorage[request] ?? 1
        return UIImage(data: data, scale: scale)
    }

    func insert(
        request: MathRenderRequest,
        metrics: Metrics,
        imageData: Data?,
        imageScale: CGFloat?
    ) {
        requestCount += 1
        metricsStorage[request] = metrics
        if let imageData {
            imageStorage[request] = imageData
            imageScaleStorage[request] = imageScale ?? 1
        }
    }
}

@MainActor
final class MarkdownRenderer {
    private let blockCache = BlockRenderCache()

    func render(
        document: RenderDocument,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat? = nil
    ) -> RenderedDocumentModel {
        var renderedBlocks: [RenderedBlock] = []
        for block in document.blocks {
            let cacheKey = cacheKey(for: block, configuration: configuration, layoutWidth: layoutWidth)
            if let cached = blockCache.value(for: cacheKey), block.isStable {
                renderedBlocks.append(cached)
                continue
            }

            let rendered = renderBlock(
                block,
                configuration: configuration,
                layoutWidth: layoutWidth
            )
            blockCache.insert(rendered, for: cacheKey)
            renderedBlocks.append(rendered)
        }

        return RenderedDocumentModel(
            blocks: renderedBlocks,
            unstableTail: document.unstableTail
        )
    }

    private func renderBlock(
        _ block: RenderBlock,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) -> RenderedBlock {
        let content: RenderedBlock.Content
        let overflowIntent: RenderedBlock.OverflowLayoutIntent

        switch block.kind {
        case .paragraph(let contentRuns):
            content = .paragraph(contentRuns)
            overflowIntent = .natural

        case .heading(let level, let contentRuns):
            content = .heading(level: level, content: contentRuns)
            overflowIntent = .natural

        case .quote(let blocks):
            content = .quote(
                blocks.map {
                    renderBlock($0, configuration: configuration, layoutWidth: layoutWidth)
                }
            )
            overflowIntent = .natural

        case .unorderedList(let items):
            content = .unorderedList(
                items.map { item in
                    item.map {
                        renderBlock($0, configuration: configuration, layoutWidth: layoutWidth)
                    }
                }
            )
            overflowIntent = .natural

        case .orderedList(let start, let items):
            content = .orderedList(
                start: start,
                items: items.map { item in
                    item.map {
                        renderBlock($0, configuration: configuration, layoutWidth: layoutWidth)
                    }
                }
            )
            overflowIntent = .natural

        case .code(let language, let source):
            content = .code(language: language, content: source)
            overflowIntent = overflowIntentForCode(
                source,
                configuration: configuration,
                layoutWidth: layoutWidth
            )

        case .table(let table):
            content = .table(table)
            overflowIntent = overflowIntentForTable(
                table,
                configuration: configuration,
                layoutWidth: layoutWidth
            )

        case .math(let math):
            let request = MathRenderRequest(
                latex: math.latex,
                displayMode: math.displayMode,
                fontSize: configuration.math.fontSize,
                scale: math.displayMode == .inline ? configuration.math.inlineScale : configuration.math.blockScale,
                foregroundHex: configuration.math.foregroundHex,
                widthConstraint: math.displayMode == .block ? layoutWidth : nil
            )
            content = .math(request)
            overflowIntent = overflowIntentForMath(
                request,
                configuration: configuration,
                layoutWidth: layoutWidth
            )

        case .toolCall(let toolCall):
            content = .toolCall(toolCall)
            overflowIntent = .natural

        case .toolOutput(let language, let output, let id):
            content = .toolOutput(language: language, content: output, id: id)
            overflowIntent = overflowIntentForCode(
                output,
                configuration: configuration,
                layoutWidth: layoutWidth
            )

        case .image(let source, let alt):
            content = .image(source: source, alt: alt)
            overflowIntent = .natural

        case .thematicBreak:
            content = .thematicBreak
            overflowIntent = .natural

        case .incomplete(let node):
            content = .incomplete(node)
            overflowIntent = .natural
        }

        return RenderedBlock(
            id: block.id,
            stableKey: block.stableKey,
            content: content,
            layout: .init(
                overflowBehavior: configuration.overflowBehavior,
                overflowIntent: overflowIntent
            ),
            isStable: block.isStable
        )
    }

    private func overflowIntentForCode(
        _ source: String,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) -> RenderedBlock.OverflowLayoutIntent {
        guard configuration.overflowBehavior == .scrollIfNeeded else { return .natural }
        guard let layoutWidth else { return .measure }

        let contentWidth = estimatedMonospaceWidth(for: source)
        return contentWidth > layoutWidth ? .scroll : .natural
    }

    private func overflowIntentForTable(
        _ table: RenderTable,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) -> RenderedBlock.OverflowLayoutIntent {
        guard configuration.overflowBehavior == .scrollIfNeeded else { return .natural }
        guard let layoutWidth else { return .measure }

        let contentWidth = estimatedTableWidth(for: table)
        return contentWidth > layoutWidth ? .scroll : .natural
    }

    private func overflowIntentForMath(
        _ request: MathRenderRequest,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) -> RenderedBlock.OverflowLayoutIntent {
        guard request.displayMode == .block else { return .natural }
        guard configuration.overflowBehavior == .scrollIfNeeded else { return .natural }
        guard let layoutWidth else { return .measure }

        if let metrics = MathLayoutCache.shared.metrics(for: request) {
            return metrics.width > layoutWidth ? .scroll : .natural
        }

        let estimatedWidth = estimatedMathWidth(
            latex: request.latex,
            fontSize: request.fontSize * request.scale
        )
        return estimatedWidth > layoutWidth ? .scroll : .natural
    }

    private func estimatedTableWidth(for table: RenderTable) -> CGFloat {
        let columnCount = table.rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return 0 }

        var columnWidths = Array(repeating: CGFloat(120), count: columnCount)
        for row in table.rows {
            for (index, cell) in row.enumerated() {
                let width = estimatedBodyTextWidth(for: plainText(from: cell.content)) + 20
                columnWidths[index] = max(columnWidths[index], width)
            }
        }

        return columnWidths.reduce(0, +) + CGFloat(columnCount + 1)
    }

    private func estimatedMonospaceWidth(for source: String) -> CGFloat {
        let longestLine = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .max(by: { $0.count < $1.count }) ?? ""
        return estimatedWidth(
            for: longestLine,
            font: .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        ) + 24
    }

    private func estimatedBodyTextWidth(for source: String) -> CGFloat {
        estimatedWidth(
            for: source,
            font: .preferredFont(forTextStyle: .body)
        )
    }

    private func estimatedMathWidth(latex: String, fontSize: CGFloat) -> CGFloat {
        let sanitized = latex.replacingOccurrences(of: "\\", with: "")
        let baseWidth = estimatedWidth(
            for: sanitized,
            font: .systemFont(ofSize: fontSize)
        )
        return max(baseWidth * 0.92, CGFloat(latex.count) * fontSize * 0.42)
    }

    private func plainText(from runs: [RenderInline]) -> String {
        runs.reduce(into: "") { text, run in
            switch run {
            case .text(let value):
                text.append(value)
            case .softBreak, .lineBreak:
                text.append(" ")
            case .emphasis(let nested), .strong(let nested):
                text.append(plainText(from: nested))
            case .code(let code):
                text.append(code)
            case .link(let label, _):
                text.append(plainText(from: label))
            case .image(let alt, _):
                text.append(alt)
            case .math(let math):
                text.append(math.latex)
            }
        }
    }

    private func estimatedWidth(for source: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((source as NSString).size(withAttributes: attributes).width)
    }

    private func cacheKey(
        for block: RenderBlock,
        configuration: MarkdownConfiguration,
        layoutWidth: CGFloat?
    ) -> String {
        let widthBucket: Int
        if let layoutWidth {
            widthBucket = Int((layoutWidth / 16).rounded(.toNearestOrAwayFromZero))
        } else {
            widthBucket = 0
        }

        let mathKey = [
            String(describing: configuration.math.fontSize),
            String(describing: configuration.math.inlineScale),
            String(describing: configuration.math.blockScale),
            configuration.math.foregroundHex
        ].joined(separator: ":")

        return [
            block.stableKey,
            configuration.overflowBehavior.rawValue,
            mathKey,
            "w\(widthBucket)"
        ].joined(separator: "|")
    }
}
