import Foundation
import Markdown

enum MarkdownMathParser {
    static func parse(
        _ source: String,
        renderMode: MarkdownMath.RenderMode
    ) -> MarkdownMathDocument {
        let normalizedSource = renderMode == .streaming
            ? MarkdownStreamNormalizer.normalize(source)
            : source
        let extracted = MarkdownMathExtractor.extract(from: normalizedSource)
        let document = Document(parsing: extracted.markdown)
        let blocks = document.children.compactMap { convertBlock($0, extracted: extracted) }
        return MarkdownMathDocument(blocks: blocks)
    }

    private static func convertBlock(
        _ markup: Markup,
        extracted: ExtractedMathDocument
    ) -> MarkdownMathBlock? {
        if let heading = markup as? Heading {
            let inline = inlineMarkdown(from: heading, extracted: extracted)
            return .heading(level: heading.level, text: restoreInlineMath(inline, extracted: extracted))
        }

        if let paragraph = markup as? Paragraph {
            let inline = inlineMarkdown(from: paragraph, extracted: extracted)

            if let blockMath = standaloneBlockMath(inline: inline, extracted: extracted) {
                return .mathBlock(blockMath.originalSource)
            }

            if let image = standaloneImage(in: paragraph, extracted: extracted) {
                return image
            }

            return .paragraph(restoreInlineMath(inline, extracted: extracted))
        }

        if let quote = markup as? BlockQuote {
            return .blockquote(quote.children.compactMap { convertBlock($0, extracted: extracted) })
        }

        if let unorderedList = markup as? UnorderedList {
            let items = Array(unorderedList.listItems.map { listItem in
                listItem.children.compactMap { convertBlock($0, extracted: extracted) }
            })
            return .unorderedList(items: items)
        }

        if let orderedList = markup as? OrderedList {
            let items = Array(orderedList.listItems.map { listItem in
                listItem.children.compactMap { convertBlock($0, extracted: extracted) }
            })
            return .orderedList(start: Int(orderedList.startIndex), items: items)
        }

        if let codeBlock = markup as? CodeBlock {
            return .codeBlock(language: codeBlock.language, code: codeBlock.code)
        }

        if markup is ThematicBreak {
            return .thematicBreak
        }

        let fallback = restoreInlineMath(
            inlineMarkdown(from: markup, extracted: extracted),
            extracted: extracted
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? nil : .paragraph(fallback)
    }

    private static func standaloneBlockMath(
        inline: String,
        extracted: ExtractedMathDocument
    ) -> ExtractedMathToken? {
        let normalized = inline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = extracted.tokens[normalized], token.isBlock else {
            return nil
        }
        return token
    }

    private static func standaloneImage(
        in paragraph: Paragraph,
        extracted: ExtractedMathDocument
    ) -> MarkdownMathBlock? {
        guard paragraph.childCount == 1, let image = paragraph.child(at: 0) as? Image else {
            return nil
        }

        return .image(
            source: image.source,
            alt: restoreInlineMath(
                inlineMarkdown(from: image, extracted: extracted),
                extracted: extracted
            )
        )
    }

    private static func inlineMarkdown(
        from markup: Markup,
        extracted: ExtractedMathDocument
    ) -> String {
        markup.children.map { inlineMarkdownNode($0, extracted: extracted) }.joined()
    }

    private static func inlineMarkdownNode(
        _ markup: Markup,
        extracted: ExtractedMathDocument
    ) -> String {
        switch markup {
        case let text as Markdown.Text:
            return MarkdownInlineEscaper.escape(text.string, tokenKeys: Set(extracted.tokens.keys))
        case is SoftBreak:
            return "\n"
        case is LineBreak:
            return "  \n"
        case let emphasis as Emphasis:
            return "*\(inlineMarkdown(from: emphasis, extracted: extracted))*"
        case let strong as Strong:
            return "**\(inlineMarkdown(from: strong, extracted: extracted))**"
        case let strikethrough as Strikethrough:
            return "~~\(inlineMarkdown(from: strikethrough, extracted: extracted))~~"
        case let inlineCode as InlineCode:
            return "`\(inlineCode.code.replacingOccurrences(of: "`", with: "\\`"))`"
        case let link as Link:
            let label = inlineMarkdown(from: link, extracted: extracted)
            let destination = MarkdownInlineEscaper.escapeLinkDestination(link.destination ?? "")
            return "[\(label)](\(destination))"
        case let image as Image:
            let alt = inlineMarkdown(from: image, extracted: extracted)
            let source = MarkdownInlineEscaper.escapeLinkDestination(image.source ?? "")
            return "![\(alt)](\(source))"
        case let html as InlineHTML:
            return html.rawHTML
        case let html as HTMLBlock:
            return html.rawHTML
        default:
            return inlineMarkdown(from: markup, extracted: extracted)
        }
    }

    private static func restoreInlineMath(
        _ source: String,
        extracted: ExtractedMathDocument
    ) -> String {
        guard source.contains("MDMATH_TOKEN_") else {
            return escapeLiteralMathOpeners(in: source)
        }

        let pattern = #"MDMATH_TOKEN_\d+_"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return escapeLiteralMathOpeners(in: source)
        }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)
        guard matches.isEmpty == false else {
            return escapeLiteralMathOpeners(in: source)
        }

        var output = ""
        var cursor = source.startIndex

        for match in matches {
            guard let range = Range(match.range, in: source) else {
                continue
            }

            output += escapeLiteralMathOpeners(in: String(source[cursor..<range.lowerBound]))
            let key = String(source[range])
            output += extracted.tokens[key]?.originalSource ?? key
            cursor = range.upperBound
        }

        output += escapeLiteralMathOpeners(in: String(source[cursor...]))
        return output
    }

    private static func escapeLiteralMathOpeners(in source: String) -> String {
        var output = ""
        let characters = Array(source)
        var index = 0

        while index < characters.count {
            if index + 1 < characters.count, characters[index] == "$", characters[index + 1] == "$" {
                output += #"\$\$"#
                index += 2
                continue
            }

            if characters[index] == "$" {
                output += #"\$"#
                index += 1
                continue
            }

            if index + 1 < characters.count, characters[index] == "\\", characters[index + 1] == "(" {
                output += #"\\("#
                index += 2
                continue
            }

            if index + 1 < characters.count, characters[index] == "\\", characters[index + 1] == "[" {
                output += #"\\["#
                index += 2
                continue
            }

            if hasPrefix(characters, at: index, literal: #"\begin{"#) {
                output += #"\\begin{"#
                index += 7
                continue
            }

            output.append(characters[index])
            index += 1
        }

        return output
    }

    private static func hasPrefix(
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
}

private enum MarkdownInlineEscaper {
    private static let inlineSpecials = CharacterSet(charactersIn: "\\`*_[]()!~")

    static func escape(_ input: String, tokenKeys: Set<String>) -> String {
        guard input.contains("MDMATH_TOKEN_") else {
            return escapePlainText(input)
        }

        let pattern = #"MDMATH_TOKEN_\d+_"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return escapePlainText(input)
        }

        let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = regex.matches(in: input, range: nsRange)
        guard matches.isEmpty == false else {
            return escapePlainText(input)
        }

        var escaped = ""
        var cursor = input.startIndex

        for match in matches {
            guard let range = Range(match.range, in: input) else {
                continue
            }

            escaped += escapePlainText(String(input[cursor..<range.lowerBound]))
            let token = String(input[range])
            escaped += tokenKeys.contains(token) ? token : escapePlainText(token)
            cursor = range.upperBound
        }

        escaped += escapePlainText(String(input[cursor...]))
        return escaped
    }

    static func escapeLinkDestination(_ input: String) -> String {
        input.replacingOccurrences(of: ")", with: #"\)"#)
    }

    private static func escapePlainText(_ input: String) -> String {
        var output = ""
        output.reserveCapacity(input.count)

        for scalar in input.unicodeScalars {
            if inlineSpecials.contains(scalar) {
                output.append("\\")
            }
            output.unicodeScalars.append(scalar)
        }

        return output
    }
}
