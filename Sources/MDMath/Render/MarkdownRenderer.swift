import Foundation
#if os(iOS)
import UIKit
#endif

struct RenderedDocumentModel: Hashable {
    var blocks: [RenderedBlock]
    var unstableTail: Bool
}

struct RenderedBlock: Identifiable, Hashable {
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
        var requiresHorizontalScroll: Bool
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

    func value(for stableKey: String) -> RenderedBlock? {
        storage[stableKey]
    }

    func insert(_ block: RenderedBlock, for stableKey: String) {
        storage[stableKey] = block
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
        configuration: MarkdownConfiguration
    ) -> RenderedDocumentModel {
        var renderedBlocks: [RenderedBlock] = []
        for block in document.blocks {
            if let cached = blockCache.value(for: block.stableKey), block.isStable {
                renderedBlocks.append(cached)
                continue
            }

            let rendered = renderBlock(block, configuration: configuration)
            blockCache.insert(rendered, for: block.stableKey)
            renderedBlocks.append(rendered)
        }

        return RenderedDocumentModel(
            blocks: renderedBlocks,
            unstableTail: document.unstableTail
        )
    }

    private func renderBlock(
        _ block: RenderBlock,
        configuration: MarkdownConfiguration
    ) -> RenderedBlock {
        let content: RenderedBlock.Content
        let requiresHorizontalScroll: Bool

        switch block.kind {
        case .paragraph(let contentRuns):
            content = .paragraph(contentRuns)
            requiresHorizontalScroll = false

        case .heading(let level, let contentRuns):
            content = .heading(level: level, content: contentRuns)
            requiresHorizontalScroll = false

        case .quote(let blocks):
            content = .quote(blocks.map { renderBlock($0, configuration: configuration) })
            requiresHorizontalScroll = false

        case .unorderedList(let items):
            content = .unorderedList(
                items.map { item in
                    item.map { renderBlock($0, configuration: configuration) }
                }
            )
            requiresHorizontalScroll = false

        case .orderedList(let start, let items):
            content = .orderedList(
                start: start,
                items: items.map { item in
                    item.map { renderBlock($0, configuration: configuration) }
                }
            )
            requiresHorizontalScroll = false

        case .code(let language, let source):
            content = .code(language: language, content: source)
            requiresHorizontalScroll = true

        case .table(let table):
            content = .table(table)
            requiresHorizontalScroll = true

        case .math(let math):
            let request = MathRenderRequest(
                latex: math.latex,
                displayMode: math.displayMode,
                fontSize: configuration.math.fontSize,
                scale: math.displayMode == .inline ? configuration.math.inlineScale : configuration.math.blockScale,
                foregroundHex: configuration.math.foregroundHex,
                widthConstraint: nil
            )
            content = .math(request)
            requiresHorizontalScroll = math.displayMode == .block

        case .toolCall(let toolCall):
            content = .toolCall(toolCall)
            requiresHorizontalScroll = false

        case .toolOutput(let language, let output, let id):
            content = .toolOutput(language: language, content: output, id: id)
            requiresHorizontalScroll = true

        case .image(let source, let alt):
            content = .image(source: source, alt: alt)
            requiresHorizontalScroll = false

        case .thematicBreak:
            content = .thematicBreak
            requiresHorizontalScroll = false

        case .incomplete(let node):
            content = .incomplete(node)
            requiresHorizontalScroll = false
        }

        return RenderedBlock(
            id: block.id,
            stableKey: block.stableKey,
            content: content,
            layout: .init(
                overflowBehavior: configuration.overflowBehavior,
                requiresHorizontalScroll: requiresHorizontalScroll
            ),
            isStable: block.isStable
        )
    }
}
