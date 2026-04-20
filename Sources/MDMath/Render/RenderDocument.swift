import Foundation

struct RenderDocument: Hashable, Sendable {
    var source: String
    var blocks: [RenderBlock]
    var unstableTail: Bool
}

struct MathNode: Hashable, Sendable {
    enum DisplayMode: String, Hashable, Sendable {
        case inline
        case block
    }

    var latex: String
    var displayMode: DisplayMode
}

struct ToolCallNode: Hashable, Sendable {
    enum State: String, Hashable, Sendable {
        case streaming
        case completed
    }

    var id: String
    var name: String
    var arguments: String
    var output: String?
    var outputLanguage: String?
    var state: State
}

struct IncompleteNode: Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case inlineMath
        case blockMath
        case codeFence
        case table
        case toolArguments
    }

    var kind: Kind
    var preview: String
}

enum RenderInline: Hashable, Sendable {
    case text(String)
    case softBreak
    case lineBreak
    case emphasis([RenderInline])
    case strong([RenderInline])
    case code(String)
    case link(label: [RenderInline], destination: String)
    case image(alt: String, source: String)
    case math(MathNode)
}

struct RenderTable: Hashable, Sendable {
    var rows: [[RenderTableCell]]
}

struct RenderTableCell: Hashable, Sendable {
    var content: [RenderInline]
    var isHeader: Bool
}

indirect enum RenderBlockKind: Hashable, Sendable {
    case paragraph([RenderInline])
    case heading(level: Int, content: [RenderInline])
    case quote([RenderBlock])
    case unorderedList([[RenderBlock]])
    case orderedList(start: Int?, items: [[RenderBlock]])
    case code(language: String?, content: String)
    case table(RenderTable)
    case math(MathNode)
    case toolCall(ToolCallNode)
    case toolOutput(language: String?, content: String, id: String)
    case image(source: String, alt: String)
    case thematicBreak
    case incomplete(IncompleteNode)
}

struct RenderBlock: Identifiable, Hashable, Sendable {
    var id: String
    var stableKey: String
    var kind: RenderBlockKind
    var isStable: Bool
}
