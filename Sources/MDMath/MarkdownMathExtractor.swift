import Foundation

enum MarkdownMathExtractor {
    static func extract(from source: String) -> ExtractedMathDocument {
        var output = ""
        var tokens: [String: ExtractedMathToken] = [:]
        var counter = 0

        let characters = Array(source)
        var index = 0

        while index < characters.count {
            if let (token, nextIndex) = consumeMathToken(characters, from: index, counter: counter) {
                output += token.placeholder
                tokens[token.placeholder] = token
                counter += 1
                index = nextIndex
                continue
            }

            output.append(characters[index])
            index += 1
        }

        return ExtractedMathDocument(markdown: output, tokens: tokens)
    }

    private static func consumeMathToken(
        _ characters: [Character],
        from index: Int,
        counter: Int
    ) -> (ExtractedMathToken, Int)? {
        if matches(characters, at: index, literal: "$$"),
           let close = findClosing(characters, from: index + 2, open: "$$", close: "$$") {
            return makeToken(characters, start: index, end: close, counter: counter, isBlock: true)
        }

        if matches(characters, at: index, literal: #"\["#),
           let close = findClosing(characters, from: index + 2, open: #"\["#, close: #"\]"#) {
            return makeToken(characters, start: index, end: close, counter: counter, isBlock: true)
        }

        if matches(characters, at: index, literal: #"\("#),
           let close = findClosing(characters, from: index + 2, open: #"\("#, close: #"\)"#) {
            return makeToken(characters, start: index, end: close, counter: counter, isBlock: false)
        }

        if matches(characters, at: index, literal: #"\begin{"#),
           let close = findEnvironmentEnd(characters, from: index) {
            return makeToken(characters, start: index, end: close, counter: counter, isBlock: true)
        }

        if characters[index] == "$",
           isInlineDollarCandidate(characters, at: index),
           let close = findInlineDollarClose(characters, from: index + 1) {
            return makeToken(characters, start: index, end: close, counter: counter, isBlock: false)
        }

        return nil
    }

    private static func makeToken(
        _ characters: [Character],
        start: Int,
        end: Int,
        counter: Int,
        isBlock: Bool
    ) -> (ExtractedMathToken, Int) {
        let original = String(characters[start..<end])
        let placeholder = "MDMATH_TOKEN_\(counter)_"
        let token = ExtractedMathToken(
            placeholder: placeholder,
            originalSource: original,
            isBlock: isBlock
        )
        return (token, end)
    }

    private static func matches(
        _ characters: [Character],
        at index: Int,
        literal: String
    ) -> Bool {
        let literalCharacters = Array(literal)
        guard index + literalCharacters.count <= characters.count else {
            return false
        }

        for offset in literalCharacters.indices where characters[index + offset] != literalCharacters[offset] {
            return false
        }

        return true
    }

    private static func findClosing(
        _ characters: [Character],
        from index: Int,
        open: String,
        close: String
    ) -> Int? {
        var cursor = index
        while cursor < characters.count {
            if matches(characters, at: cursor, literal: close) {
                return cursor + close.count
            }
            cursor += 1
        }
        return nil
    }

    private static func findEnvironmentEnd(
        _ characters: [Character],
        from index: Int
    ) -> Int? {
        let envNameStart = index + 7
        var cursor = envNameStart

        while cursor < characters.count, characters[cursor] != "}" {
            cursor += 1
        }

        guard cursor < characters.count else {
            return nil
        }

        let name = String(characters[envNameStart..<cursor])
        let closing = #"\\end{\#(name)}"#
        guard let range = String(characters[(cursor + 1)...]).range(of: closing, options: .regularExpression) else {
            return nil
        }

        let suffix = String(characters[(cursor + 1)...])
        let endOffset = suffix.distance(from: suffix.startIndex, to: range.upperBound)
        return cursor + 1 + endOffset
    }

    private static func isInlineDollarCandidate(_ characters: [Character], at index: Int) -> Bool {
        if index > 0, characters[index - 1] == "\\" {
            return false
        }

        if index + 1 < characters.count, characters[index + 1] == "$" {
            return false
        }

        if index + 1 < characters.count, characters[index + 1].isWhitespace {
            return false
        }

        return true
    }

    private static func findInlineDollarClose(
        _ characters: [Character],
        from index: Int
    ) -> Int? {
        var cursor = index

        while cursor < characters.count {
            let character = characters[cursor]
            if character == "\n" {
                return nil
            }

            if character == "$",
               characters[cursor - 1] != "\\",
               (cursor == 0 || characters[cursor - 1].isWhitespace == false) {
                return cursor + 1
            }

            cursor += 1
        }

        return nil
    }
}

