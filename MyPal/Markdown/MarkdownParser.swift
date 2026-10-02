import Foundation

enum MarkdownBlock: Equatable {
    case paragraph(AttributedString)
    case heading(level: Int, AttributedString)
    case bullet(level: Int, AttributedString)
    case numbered(Int, AttributedString)
    case quote(AttributedString)
    case code(String)
    case rule
}

/// Small block-level Markdown parser. Inline styling (bold, italic, code, links) is delegated to
/// Foundation's `AttributedString(markdown:)`, so it's linear-time and handles partial input
/// (unterminated `**` or code fences) gracefully while a reply is still streaming.
enum MarkdownParser {

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(inline(paragraph.joined(separator: "\n"))))
            paragraph.removeAll()
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    inCode = false
                } else {
                    flushParagraph()
                    inCode = true
                }
                continue
            }
            if inCode {
                codeLines.append(line)
                continue
            }
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            if let heading = heading(from: trimmed) {
                flushParagraph()
                blocks.append(heading)
                continue
            }
            if isRule(trimmed) {
                flushParagraph()
                blocks.append(.rule)
                continue
            }
            if let content = bulletContent(of: trimmed) {
                flushParagraph()
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                blocks.append(.bullet(level: min(indent / 2, 3), inline(content)))
                continue
            }
            if let (number, content) = numberedContent(of: trimmed) {
                flushParagraph()
                blocks.append(.numbered(number, inline(content)))
                continue
            }
            if trimmed.hasPrefix(">") {
                flushParagraph()
                let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append(.quote(inline(content)))
                continue
            }
            paragraph.append(trimmed)
        }

        if inCode { blocks.append(.code(codeLines.joined(separator: "\n"))) } // still streaming
        flushParagraph()
        return blocks
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    // MARK: Line classification

    private static func heading(from line: String) -> MarkdownBlock? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, inline(content))
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }

    private static func bulletContent(of line: String) -> String? {
        for marker in ["- ", "* ", "+ ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    private static func numberedContent(of line: String) -> (Int, String)? {
        let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, digits.count <= 3, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return (number, String(rest.dropFirst(2)))
    }
}

// MARK: - Cache

private final class BlockBox {
    let blocks: [MarkdownBlock]
    init(_ blocks: [MarkdownBlock]) { self.blocks = blocks }
}

/// Finished messages are parsed once; scrolling a row back on-screen is a cache hit.
enum MarkdownCache {
    private static let cache: NSCache<NSString, BlockBox> = {
        let cache = NSCache<NSString, BlockBox>()
        cache.countLimit = 400
        return cache
    }()

    static func blocks(for text: String, key: String) -> [MarkdownBlock] {
        let cacheKey = "\(key)#\(text.utf8.count)" as NSString
        if let hit = cache.object(forKey: cacheKey) { return hit.blocks }
        let parsed = MarkdownParser.parse(text)
        cache.setObject(BlockBox(parsed), forKey: cacheKey)
        return parsed
    }
}

// MARK: - Plain-text preview

extension String {
    /// Single-line, marker-free version for list previews and accessibility labels.
    var markdownStripped: String {
        let lines = split(separator: "\n", omittingEmptySubsequences: true).map { line -> String in
            var text = line.trimmingCharacters(in: .whitespaces)
            while text.hasPrefix("#") { text.removeFirst() }
            for marker in ["- ", "* ", "+ "] where text.hasPrefix(marker) {
                text.removeFirst(2)
                break
            }
            return text.trimmingCharacters(in: .whitespaces)
        }
        var result = lines.joined(separator: " ")
        for token in ["**", "__", "```", "`"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result
    }
}
