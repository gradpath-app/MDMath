import Foundation

struct MathTokenScanner {
    struct MathToken: Hashable, Sendable {
        var placeholder: String
        var latex: String
        var displayMode: MathNode.DisplayMode
    }

    struct Result: Hashable, Sendable {
        var protectedMarkdown: String
        var tokens: [MathToken]
        var hasUnmatchedInlineMath: Bool
        var hasUnmatchedBlockMath: Bool
        var hasUnmatchedCodeFence: Bool
    }

    func scan(_ source: String) -> Result {
        var output = ""
        var tokens: [MathToken] = []
        var hasUnmatchedInlineMath = false
        var hasUnmatchedBlockMath = false
        var isInsideFence = false

        var index = source.startIndex
        while index < source.endIndex {
            if isFenceDelimiter(at: index, in: source) {
                let delimiter = source[index..<source.index(index, offsetBy: 3)]
                output.append(contentsOf: delimiter)
                index = source.index(index, offsetBy: 3)
                while index < source.endIndex, source[index] != "\n" {
                    output.append(source[index])
                    index = source.index(after: index)
                }
                isInsideFence.toggle()
                continue
            }

            if !isInsideFence, source[index] == "`" {
                let backtickCount = repeatedCount(of: "`", from: index, in: source)
                let delimiter = String(repeating: "`", count: backtickCount)
                output.append(delimiter)
                index = source.index(index, offsetBy: backtickCount)

                if let closing = findInlineCodeEnd(
                    delimiter: delimiter,
                    from: index,
                    in: source
                ) {
                    output.append(contentsOf: source[index..<closing.lowerBound])
                    output.append(delimiter)
                    index = closing.upperBound
                } else {
                    output.append(contentsOf: source[index...])
                    index = source.endIndex
                }
                continue
            }

            if !isInsideFence, source[index] == "$" {
                let isBlock = source.index(after: index) < source.endIndex && source[source.index(after: index)] == "$"
                let delimiter = isBlock ? "$$" : "$"
                let start = source.index(index, offsetBy: delimiter.count)

                if let closing = findMathEnd(
                    delimiter: delimiter,
                    from: start,
                    in: source
                ) {
                    let latex = String(source[start..<closing.lowerBound])
                    let placeholder = placeholder(for: tokens.count, displayMode: isBlock ? .block : .inline)
                    tokens.append(
                        MathToken(
                            placeholder: placeholder,
                            latex: latex,
                            displayMode: isBlock ? .block : .inline
                        )
                    )
                    output.append(placeholder)
                    index = closing.upperBound
                    continue
                } else {
                    if isBlock {
                        hasUnmatchedBlockMath = true
                    } else {
                        hasUnmatchedInlineMath = true
                    }
                }
            }

            output.append(source[index])
            index = source.index(after: index)
        }

        return Result(
            protectedMarkdown: output,
            tokens: tokens,
            hasUnmatchedInlineMath: hasUnmatchedInlineMath,
            hasUnmatchedBlockMath: hasUnmatchedBlockMath,
            hasUnmatchedCodeFence: isInsideFence
        )
    }

    private func placeholder(for index: Int, displayMode: MathNode.DisplayMode) -> String {
        switch displayMode {
        case .inline:
            "MDMATHINLINE\(index)TOKEN"
        case .block:
            "MDMATHBLOCK\(index)TOKEN"
        }
    }

    private func repeatedCount(of character: Character, from index: String.Index, in source: String) -> Int {
        var count = 0
        var cursor = index
        while cursor < source.endIndex, source[cursor] == character {
            count += 1
            cursor = source.index(after: cursor)
        }
        return count
    }

    private func isFenceDelimiter(at index: String.Index, in source: String) -> Bool {
        guard source.distance(from: index, to: source.endIndex) >= 3 else { return false }
        guard source[index] == "`" else { return false }

        let previous = index > source.startIndex ? source[source.index(before: index)] : "\n"
        guard previous == "\n" || previous == "\r" else { return false }

        let next1 = source[source.index(after: index)]
        let next2 = source[source.index(index, offsetBy: 2)]
        return next1 == "`" && next2 == "`"
    }

    private func findInlineCodeEnd(
        delimiter: String,
        from index: String.Index,
        in source: String
    ) -> (lowerBound: String.Index, upperBound: String.Index)? {
        guard !delimiter.isEmpty else { return nil }
        var cursor = index
        while cursor < source.endIndex {
            if source[cursor...].hasPrefix(delimiter) {
                return (cursor, source.index(cursor, offsetBy: delimiter.count))
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }

    private func findMathEnd(
        delimiter: String,
        from index: String.Index,
        in source: String
    ) -> (lowerBound: String.Index, upperBound: String.Index)? {
        guard !delimiter.isEmpty else { return nil }
        var cursor = index
        while cursor < source.endIndex {
            if source[cursor] == "\\", source.index(after: cursor) < source.endIndex {
                cursor = source.index(cursor, offsetBy: 2)
                continue
            }
            if source[cursor...].hasPrefix(delimiter) {
                return (cursor, source.index(cursor, offsetBy: delimiter.count))
            }
            cursor = source.index(after: cursor)
        }
        return nil
    }
}
