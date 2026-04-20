import CryptoKit
import Foundation
import Markdown

struct MarkdownParser {
    func parse(
        markdown source: String,
        toolCalls: [ToolCallNode] = []
    ) -> RenderDocument {
        let scanner = MathTokenScanner()
        let scan = scanner.scan(source)
        let document = Document(parsing: scan.protectedMarkdown)
        let visitor = MarkdownASTVisitor(mathTokens: scan.tokens)
        var blocks = visitor.blocks(from: document)
        blocks.append(contentsOf: toolBlocks(from: toolCalls))

        if scan.hasUnmatchedCodeFence {
            blocks.append(
                RenderBlock(
                    id: "",
                    stableKey: Self.blockStableKey(prefix: "incomplete-code", source: source),
                    kind: .incomplete(.init(kind: .codeFence, preview: source)),
                    isStable: false
                )
            )
        } else if scan.hasUnmatchedBlockMath {
            blocks.append(
                RenderBlock(
                    id: "",
                    stableKey: Self.blockStableKey(prefix: "incomplete-block-math", source: source),
                    kind: .incomplete(.init(kind: .blockMath, preview: source)),
                    isStable: false
                )
            )
        } else if scan.hasUnmatchedInlineMath {
            blocks.append(
                RenderBlock(
                    id: "",
                    stableKey: Self.blockStableKey(prefix: "incomplete-inline-math", source: source),
                    kind: .incomplete(.init(kind: .inlineMath, preview: source)),
                    isStable: false
                )
            )
        }

        if let preview = incompleteTablePreview(in: source) {
            blocks.append(
                RenderBlock(
                    id: "",
                    stableKey: Self.blockStableKey(prefix: "incomplete-table", source: preview),
                    kind: .incomplete(.init(kind: .table, preview: preview)),
                    isStable: false
                )
            )
        }

        blocks = Self.assignUniqueIDs(to: blocks)

        let hasIncompleteToolArguments = toolCalls.contains { $0.state == .streaming }
        let hasIncompleteTable = blocks.contains {
            if case .incomplete(let node) = $0.kind {
                return node.kind == .table
            }
            return false
        }

        return RenderDocument(
            source: source,
            blocks: blocks,
            unstableTail: scan.hasUnmatchedInlineMath ||
                scan.hasUnmatchedBlockMath ||
                scan.hasUnmatchedCodeFence ||
                hasIncompleteTable ||
                hasIncompleteToolArguments
        )
    }

    static func blockID(prefix: String, source: String) -> String {
        "\(prefix)-\(digest(for: source))"
    }

    static func blockStableKey(prefix: String, source: String) -> String {
        "\(prefix)-\(digest(for: source))"
    }

    private static func digest(for source: String) -> String {
        let bytes = SHA256.hash(data: Data(source.utf8))
        return bytes.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func toolBlocks(from toolCalls: [ToolCallNode]) -> [RenderBlock] {
        toolCalls.flatMap { toolCall -> [RenderBlock] in
            var blocks: [RenderBlock] = [
                RenderBlock(
                    id: "",
                    stableKey: Self.blockStableKey(
                        prefix: "tool-call",
                        source: toolCall.id + ":" + toolCall.name + ":" + toolCall.arguments
                    ),
                    kind: .toolCall(toolCall),
                    isStable: toolCall.state == .completed
                )
            ]

            if toolCall.state == .streaming {
                blocks.append(
                    RenderBlock(
                        id: "",
                        stableKey: Self.blockStableKey(
                            prefix: "incomplete-tool-arguments",
                            source: toolCall.id + ":" + toolCall.arguments
                        ),
                        kind: .incomplete(.init(kind: .toolArguments, preview: toolCall.arguments)),
                        isStable: false
                    )
                )
            }

            if let output = toolCall.output {
                blocks.append(
                    RenderBlock(
                        id: "",
                        stableKey: Self.blockStableKey(
                            prefix: "tool-output",
                            source: toolCall.id + ":" + (toolCall.outputLanguage ?? "") + ":" + output
                        ),
                        kind: .toolOutput(language: toolCall.outputLanguage, content: output, id: toolCall.id),
                        isStable: toolCall.state == .completed
                    )
                )
            }

            return blocks
        }
    }

    private func incompleteTablePreview(in source: String) -> String? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let lastNonEmptyIndex = lines.lastIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return nil
        }

        var start = lastNonEmptyIndex
        while start > 0, !lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            start -= 1
        }

        let candidate = Array(lines[start...lastNonEmptyIndex])
        guard let header = candidate.first, looksLikeTableRow(header) else {
            return nil
        }

        if candidate.count == 1 {
            return header
        }

        let headerPipeCount = pipeCount(in: header)
        let separator = candidate[1]
        guard looksLikeSeparatorRow(separator, expectedPipeCount: headerPipeCount) else {
            return candidate.joined(separator: "\n")
        }

        let dataRows = candidate.dropFirst(2)
        guard let lastRow = dataRows.last else {
            return nil
        }

        if pipeCount(in: lastRow) < headerPipeCount || !source.hasSuffix("\n") {
            return candidate.joined(separator: "\n")
        }

        if dataRows.dropLast().contains(where: { pipeCount(in: $0) < headerPipeCount }) {
            return candidate.joined(separator: "\n")
        }

        return nil
    }

    private func looksLikeTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        return trimmed.hasPrefix("|") || trimmed.hasSuffix("|") || trimmed.contains(" | ")
    }

    private func looksLikeSeparatorRow(_ line: String, expectedPipeCount: Int) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard pipeCount(in: trimmed) >= max(expectedPipeCount - 1, 1) else { return false }

        let segments = trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !segments.isEmpty else { return false }
        return segments.allSatisfy { segment in
            let core = segment.replacingOccurrences(of: ":", with: "")
            return core.count >= 3 && core.allSatisfy { $0 == "-" }
        }
    }

    private func pipeCount(in line: String) -> Int {
        line.reduce(into: 0) { count, character in
            if character == "|" {
                count += 1
            }
        }
    }

    static func assignUniqueIDs(to blocks: [RenderBlock]) -> [RenderBlock] {
        var occurrences: [String: Int] = [:]
        return blocks.map { assignUniqueID(to: $0, occurrences: &occurrences) }
    }

    private static func assignUniqueID(
        to block: RenderBlock,
        occurrences: inout [String: Int]
    ) -> RenderBlock {
        var block = block

        switch block.kind {
        case .quote(let nested):
            block.kind = .quote(nested.map { assignUniqueID(to: $0, occurrences: &occurrences) })

        case .unorderedList(let items):
            block.kind = .unorderedList(
                items.map { item in
                    item.map { assignUniqueID(to: $0, occurrences: &occurrences) }
                }
            )

        case .orderedList(let start, let items):
            block.kind = .orderedList(
                start: start,
                items: items.map { item in
                    item.map { assignUniqueID(to: $0, occurrences: &occurrences) }
                }
            )

        default:
            break
        }

        let occurrence = occurrences[block.stableKey, default: 0]
        occurrences[block.stableKey] = occurrence + 1
        block.id = "\(block.stableKey)#\(occurrence)"
        return block
    }
}

private struct MarkdownASTVisitor {
    private let mathLookup: [String: MathTokenScanner.MathToken]

    init(mathTokens: [MathTokenScanner.MathToken]) {
        self.mathLookup = Dictionary(uniqueKeysWithValues: mathTokens.map { ($0.placeholder, $0) })
    }

    func blocks(from document: Document) -> [RenderBlock] {
        document.children.flatMap { block(from: $0, stable: true) }
    }

    private func block(from markup: any Markup, stable: Bool) -> [RenderBlock] {
        switch markup {
        case let heading as Heading:
            return [makeBlock(.heading(level: heading.level, content: inline(from: heading)), stable: stable)]

        case let paragraph as Paragraph:
            let inlineContent = inline(from: paragraph)
            if inlineContent.count == 1, case .image(let alt, let source) = inlineContent[0] {
                return [makeBlock(.image(source: source, alt: alt), stable: stable)]
            }
            if let math = standaloneBlockMath(in: inlineContent) {
                return [makeBlock(.math(math), stable: stable)]
            }
            return [makeBlock(.paragraph(inlineContent), stable: stable)]

        case let quote as BlockQuote:
            let quoteBlocks = quote.children.flatMap { block(from: $0, stable: stable) }
            return [makeBlock(.quote(quoteBlocks), stable: stable)]

        case let unorderedList as UnorderedList:
            let items = Array(unorderedList.listItems).map { listItem in
                listItem.children.flatMap { block(from: $0, stable: stable) }
            }
            return [makeBlock(.unorderedList(items), stable: stable)]

        case let orderedList as OrderedList:
            let items = Array(orderedList.listItems).map { listItem in
                listItem.children.flatMap { block(from: $0, stable: stable) }
            }
            return [makeBlock(.orderedList(start: Int(orderedList.startIndex), items: items), stable: stable)]

        case let codeBlock as CodeBlock:
            let language = codeBlock.language?.isEmpty == true ? nil : codeBlock.language
            if language?.lowercased() == "math" {
                let math = MathNode(
                    latex: codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines),
                    displayMode: .block
                )
                return [makeBlock(.math(math), stable: stable)]
            }
            return [makeBlock(.code(language: language, content: codeBlock.code), stable: stable)]

        case _ as ThematicBreak:
            return [makeBlock(.thematicBreak, stable: stable)]

        case let table as Markdown.Table:
            return [makeBlock(.table(renderTable(from: table)), stable: stable)]

        default:
            return markup.children.flatMap { block(from: $0, stable: stable) }
        }
    }

    private func renderTable(from table: Markdown.Table) -> RenderTable {
        var rows: [[RenderTableCell]] = []

        rows.append(
            Array(table.head.children).map { cell in
                RenderTableCell(content: inline(from: cell), isHeader: true)
            }
        )

        rows.append(
            contentsOf: Array(table.body.rows).map { row in
                Array(row.children).map { cell in
                    RenderTableCell(content: inline(from: cell), isHeader: false)
                }
            }
        )

        return RenderTable(rows: rows)
    }

    private func inline(from markup: any Markup) -> [RenderInline] {
        var result: [RenderInline] = []
        for child in markup.children {
            switch child {
            case let text as Markdown.Text:
                result.append(contentsOf: restoreMath(in: text.plainText))

            case _ as SoftBreak:
                result.append(.softBreak)

            case _ as LineBreak:
                result.append(.lineBreak)

            case let emphasis as Emphasis:
                result.append(.emphasis(inline(from: emphasis)))

            case let strong as Strong:
                result.append(.strong(inline(from: strong)))

            case let inlineCode as InlineCode:
                result.append(.code(inlineCode.code))

            case let link as Markdown.Link:
                result.append(
                    .link(
                        label: inline(from: link),
                        destination: link.destination ?? ""
                    )
                )

            case let image as Markdown.Image:
                result.append(
                    .image(
                        alt: image.plainText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                        source: image.source ?? ""
                    )
                )

            default:
                result.append(contentsOf: inline(from: child))
            }
        }

        return mergeTextRuns(in: result)
    }

    private func restoreMath(in text: String) -> [RenderInline] {
        guard !text.isEmpty else { return [] }

        let placeholders = mathLookup.keys.sorted { lhs, rhs in
            lhs.count > rhs.count || (lhs.count == rhs.count && lhs < rhs)
        }

        var output: [RenderInline] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            var matched = false

            for placeholder in placeholders where text[cursor...].hasPrefix(placeholder) {
                if cursor < text.endIndex, cursor > text.startIndex {
                    let previous = text[text.startIndex..<cursor]
                    if !previous.isEmpty, output.isEmpty {
                        output.append(.text(String(previous)))
                    }
                }

                if let token = mathLookup[placeholder] {
                    output.append(
                        .math(
                            MathNode(
                                latex: token.latex,
                                displayMode: token.displayMode
                            )
                        )
                    )
                }
                cursor = text.index(cursor, offsetBy: placeholder.count)
                matched = true
                break
            }

            if matched {
                let nextPlaceholderIndex = placeholders.compactMap { placeholder -> String.Index? in
                    text[cursor...].range(of: placeholder)?.lowerBound
                }.min()

                let chunkEnd = nextPlaceholderIndex ?? text.endIndex
                if cursor < chunkEnd {
                    output.append(.text(String(text[cursor..<chunkEnd])))
                    cursor = chunkEnd
                }
                continue
            }

            let next = placeholders.compactMap { placeholder -> String.Index? in
                text[cursor...].range(of: placeholder)?.lowerBound
            }.min() ?? text.endIndex
            output.append(.text(String(text[cursor..<next])))
            cursor = next
        }

        return mergeTextRuns(in: output)
    }

    private func mergeTextRuns(in content: [RenderInline]) -> [RenderInline] {
        var merged: [RenderInline] = []

        for inline in content {
            if case .text(let text) = inline,
               case .text(let previous)? = merged.last {
                merged[merged.count - 1] = .text(previous + text)
            } else {
                merged.append(inline)
            }
        }

        return merged
    }

    private func standaloneBlockMath(in content: [RenderInline]) -> MathNode? {
        let meaningful = content.filter { inline in
            switch inline {
            case .text(let text):
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .softBreak, .lineBreak:
                false
            default:
                true
            }
        }

        guard meaningful.count == 1, case .math(let math) = meaningful[0], math.displayMode == .block else {
            return nil
        }

        return math
    }

    private func makeBlock(_ kind: RenderBlockKind, stable: Bool) -> RenderBlock {
        let source = stableSource(for: kind)
        return RenderBlock(
            id: "",
            stableKey: MarkdownParser.blockStableKey(prefix: "stable", source: source),
            kind: kind,
            isStable: stable
        )
    }

    private func stableSource(for kind: RenderBlockKind) -> String {
        switch kind {
        case .paragraph(let content):
            "paragraph:\(content)"
        case .heading(let level, let content):
            "heading:\(level):\(content)"
        case .quote(let blocks):
            "quote:\(blocks.map(\.stableKey).joined(separator: ","))"
        case .unorderedList(let items):
            "ul:\(items.flatMap { $0.map(\.stableKey) }.joined(separator: ","))"
        case .orderedList(let start, let items):
            "ol:\(start ?? 0):\(items.flatMap { $0.map(\.stableKey) }.joined(separator: ","))"
        case .code(let language, let content):
            "code:\(language ?? ""):\(content)"
        case .table(let table):
            "table:\(table)"
        case .math(let math):
            "math:\(math.displayMode.rawValue):\(math.latex)"
        case .toolCall(let toolCall):
            "tool-call:\(toolCall)"
        case .toolOutput(let language, let content, let id):
            "tool-output:\(id):\(language ?? ""):\(content)"
        case .image(let source, let alt):
            "image:\(source):\(alt)"
        case .thematicBreak:
            "hr"
        case .incomplete(let node):
            "incomplete:\(node.kind.rawValue):\(node.preview)"
        }
    }
}
