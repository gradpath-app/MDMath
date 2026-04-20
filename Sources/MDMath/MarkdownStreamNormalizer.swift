import Foundation

enum MarkdownStreamNormalizer {
    static func normalize(_ source: String) -> String {
        var normalized = source
        normalized = closeFenceIfNeeded(in: normalized, marker: "```")
        normalized = closeFenceIfNeeded(in: normalized, marker: "~~~")
        return normalized
    }

    private static func closeFenceIfNeeded(in source: String, marker: String) -> String {
        var isInsideFence = false

        for line in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(marker) {
                isInsideFence.toggle()
            }
        }

        guard isInsideFence else {
            return source
        }

        return source + "\n" + marker
    }
}

