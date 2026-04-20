import Foundation

@MainActor
final class MarkdownCoordinator {
    private let parser = MarkdownParser()
    private let parserCache = DocumentParseCache()
    private let renderer = MarkdownRenderer()

    private var stablePrefixSource = ""
    private var stablePrefixBlocks: [RenderBlock] = []

    func renderedDocument(
        markdown source: String,
        toolCalls: [ToolCallNode],
        configuration: MarkdownConfiguration
    ) -> RenderedDocumentModel {
        let appendedToolBlocks = makeToolBlocks(from: toolCalls)
        let document = parse(markdown: source, appendedToolBlocks: appendedToolBlocks)
        return renderer.render(document: document, configuration: configuration)
    }

    private func parse(
        markdown source: String,
        appendedToolBlocks: [RenderBlock]
    ) -> RenderDocument {
        if appendedToolBlocks.isEmpty, let cached = parserCache.value(for: source) {
            return cached
        }

        let frontierIndex = stableFrontierIndex(in: source)
        let stablePrefix = String(source[..<frontierIndex])
        let tail = String(source[frontierIndex...])

        let stableBlocks: [RenderBlock]
        if stablePrefix == stablePrefixSource {
            stableBlocks = stablePrefixBlocks
        } else {
            let parsedPrefix = parser.parse(markdown: stablePrefix)
            stableBlocks = parsedPrefix.blocks.map {
                var block = $0
                block.isStable = true
                return block
            }
            stablePrefixSource = stablePrefix
            stablePrefixBlocks = stableBlocks
        }

        let tailDocument = parser.parse(markdown: tail, appendedToolBlocks: appendedToolBlocks)
        let tailBlocks = tailDocument.blocks.map {
            var block = $0
            block.isStable = false
            return block
        }

        let combined = RenderDocument(
            source: source,
            blocks: stableBlocks + tailBlocks,
            unstableTail: tailDocument.unstableTail
        )

        if appendedToolBlocks.isEmpty {
            parserCache.insert(combined, for: source)
        }

        return combined
    }

    private func makeToolBlocks(from toolCalls: [ToolCallNode]) -> [RenderBlock] {
        toolCalls.flatMap { toolCall -> [RenderBlock] in
            var blocks: [RenderBlock] = [
                RenderBlock(
                    id: MarkdownParser.blockID(prefix: "tool-call", source: toolCall.id + toolCall.arguments),
                    stableKey: MarkdownParser.blockStableKey(prefix: "tool-call", source: toolCall.id + toolCall.arguments),
                    kind: .toolCall(toolCall),
                    isStable: toolCall.state == .completed
                )
            ]

            if let output = toolCall.output {
                blocks.append(
                    RenderBlock(
                        id: MarkdownParser.blockID(prefix: "tool-output", source: toolCall.id + output),
                        stableKey: MarkdownParser.blockStableKey(prefix: "tool-output", source: toolCall.id + output),
                        kind: .toolOutput(language: toolCall.outputLanguage, content: output, id: toolCall.id),
                        isStable: toolCall.state == .completed
                    )
                )
            }

            return blocks
        }
    }

    private func stableFrontierIndex(in source: String) -> String.Index {
        if source.isEmpty { return source.startIndex }

        var cursor = source.startIndex
        var isInsideFence = false
        var lastSafeIndex = source.startIndex

        while cursor < source.endIndex {
            if isFenceDelimiter(at: cursor, in: source) {
                isInsideFence.toggle()
            }

            if !isInsideFence, source[cursor] == "\n" {
                let next = source.index(after: cursor)
                if next < source.endIndex, source[next] == "\n" {
                    lastSafeIndex = next
                } else {
                    lastSafeIndex = next
                }
            }

            cursor = source.index(after: cursor)
        }

        return isInsideFence ? lastSafeIndex : max(lastSafeIndex, source.startIndex)
    }

    private func isFenceDelimiter(at index: String.Index, in source: String) -> Bool {
        guard source.distance(from: index, to: source.endIndex) >= 3 else { return false }
        guard source[index] == "`" else { return false }
        let next1 = source[source.index(after: index)]
        let next2 = source[source.index(index, offsetBy: 2)]
        return next1 == "`" && next2 == "`"
    }
}
