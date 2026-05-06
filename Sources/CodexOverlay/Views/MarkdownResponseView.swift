import SwiftUI

struct MarkdownResponseView: View {
    let markdown: String
    let isPlaceholder: Bool

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let text):
                    markdownText(text)
                case .bulletList(let items):
                    bulletList(items)
                case .numberedList(let items):
                    numberedList(items)
                case .code(let code, let language):
                    codeBlock(code, language: language)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func markdownText(_ text: String) -> some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)

        return Text(attributed)
            .font(.body)
            .foregroundStyle(isPlaceholder ? .tertiary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    markdownText(item)
                }
            }
        }
    }

    private func numberedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    markdownText(item)
                }
            }
        }
    }

    private func codeBlock(_ code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.quaternary)
        }
    }
}

private enum MarkdownBlock {
    case paragraph(String)
    case bulletList([String])
    case numberedList([String])
    case code(String, language: String?)

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var language: String?
        var isInCodeBlock = false

        func flushMarkdown() {
            appendMarkdownBlocks(from: markdownLines, to: &blocks)
            markdownLines.removeAll()
        }

        func flushCode() {
            blocks.append(.code(codeLines.joined(separator: "\n"), language: language))
            codeLines.removeAll()
            language = nil
        }

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if isInCodeBlock {
                    flushCode()
                    isInCodeBlock = false
                } else {
                    flushMarkdown()
                    language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
            } else {
                markdownLines.append(line)
            }
        }

        if isInCodeBlock {
            flushCode()
        } else {
            flushMarkdown()
        }

        return blocks.isEmpty ? [.paragraph(text)] : blocks
    }

    private static func appendMarkdownBlocks(from lines: [String], to blocks: inout [MarkdownBlock]) {
        var paragraphLines: [String] = []
        var bulletItems: [String] = []
        var numberedItems: [String] = []

        func flushParagraph() {
            let text = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraphLines.removeAll()
        }

        func flushBullets() {
            if !bulletItems.isEmpty {
                blocks.append(.bulletList(bulletItems))
            }
            bulletItems.removeAll()
        }

        func flushNumbers() {
            if !numberedItems.isEmpty {
                blocks.append(.numberedList(numberedItems))
            }
            numberedItems.removeAll()
        }

        func flushAll() {
            flushParagraph()
            flushBullets()
            flushNumbers()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushAll()
                continue
            }

            if let item = bulletItem(from: line) {
                flushParagraph()
                flushNumbers()
                bulletItems.append(item)
                continue
            }

            if let item = numberedItem(from: line) {
                flushParagraph()
                flushBullets()
                numberedItems.append(item)
                continue
            }

            flushBullets()
            flushNumbers()
            paragraphLines.append(line)
        }

        flushAll()
    }

    private static func bulletItem(from line: String) -> String? {
        for prefix in ["- ", "* "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }

        return nil
    }

    private static func numberedItem(from line: String) -> String? {
        var digitCount = 0

        for character in line {
            if character.isNumber {
                digitCount += 1
            } else {
                break
            }
        }

        guard digitCount > 0 else {
            return nil
        }

        let dotIndex = line.index(line.startIndex, offsetBy: digitCount)
        guard line.indices.contains(dotIndex), line[dotIndex] == "." else {
            return nil
        }

        let itemStart = line.index(after: dotIndex)
        guard line.indices.contains(itemStart), line[itemStart] == " " else {
            return nil
        }

        return String(line[line.index(after: itemStart)...])
    }
}
