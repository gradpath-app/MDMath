import Foundation

struct MarkdownMathDocument: Equatable {
    var blocks: [MarkdownMathBlock]
}

indirect enum MarkdownMathBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case blockquote([MarkdownMathBlock])
    case unorderedList(items: [[MarkdownMathBlock]])
    case orderedList(start: Int, items: [[MarkdownMathBlock]])
    case codeBlock(language: String?, code: String)
    case mathBlock(String)
    case image(source: String?, alt: String)
    case thematicBreak
}

struct ExtractedMathToken: Equatable {
    let placeholder: String
    let originalSource: String
    let isBlock: Bool
}

struct ExtractedMathDocument: Equatable {
    let markdown: String
    let tokens: [String: ExtractedMathToken]
}

