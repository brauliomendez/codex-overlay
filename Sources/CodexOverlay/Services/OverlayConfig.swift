import Foundation

struct CodexDefaults: Sendable {
    var model: String
    var reasoningEffort: String
    var serviceTier: String

    static func load() -> CodexDefaults {
        let fallback = CodexDefaults(model: "Codex default", reasoningEffort: "Codex default", serviceTier: "fast")
        let path = "\(NSHomeDirectory())/.codex/config.toml"

        guard
            let content = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            return fallback
        }

        return CodexDefaults(
            model: topLevelValue(named: "model", in: content) ?? fallback.model,
            reasoningEffort: topLevelValue(named: "model_reasoning_effort", in: content) ?? fallback.reasoningEffort,
            serviceTier: topLevelValue(named: "service_tier", in: content) ?? fallback.serviceTier
        )
    }

    private static func topLevelValue(named key: String, in content: String) -> String? {
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("[") {
                return nil
            }

            guard line.hasPrefix("\(key)"), let separator = line.firstIndex(of: "=") else {
                continue
            }

            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }

        return nil
    }
}

struct OverlayConfig: Sendable {
    var model: String?
    var reasoningEffort: String?
    var serviceTier: String?
    var workingDirectory: String

    var summary: String {
        [
            "model=\(model ?? "default")",
            "reasoning=\(reasoningEffort ?? "default")",
            "tier=\(serviceTier ?? "default")"
        ]
        .joined(separator: "  ")
    }
}
