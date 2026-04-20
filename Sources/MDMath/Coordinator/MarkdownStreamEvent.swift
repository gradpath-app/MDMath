import Foundation

public enum MarkdownStreamEvent: Hashable, Sendable {
    case textDelta(String)
    case toolCallStart(id: String, name: String)
    case toolArgumentsDelta(id: String, delta: String)
    case toolCallEnd(id: String)
    case toolOutput(id: String, content: String, language: String?)
    case replaceAll(String)
}
