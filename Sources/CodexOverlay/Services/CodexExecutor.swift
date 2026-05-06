import Foundation

struct CodexExecutionResult {
    let output: String
    let exitCode: Int32
}

enum CodexExecutorError: LocalizedError {
    case emptyPrompt
    case executableNotFound

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            "Write a prompt before running Codex."
        case .executableNotFound:
            "Could not find the codex executable. Set CODEX_EXECUTABLE or make codex available from your login shell."
        }
    }
}

struct CodexExecutor: Sendable {
    func run(
        prompt: String,
        config: OverlayConfig,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> CodexExecutionResult {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw CodexExecutorError.emptyPrompt
        }

        guard let launchContext = resolveCodexLaunchContext() else {
            throw CodexExecutorError.executableNotFound
        }

        let lastMessageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-overlay-\(UUID().uuidString).txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchContext.executablePath)
        var arguments = [
            "exec",
            "--json",
            "--ephemeral",
            "--color",
            "never",
            "--output-last-message",
            lastMessageURL.path,
            "--skip-git-repo-check",
            "--dangerously-bypass-approvals-and-sandbox",
            "--cd",
            config.workingDirectory
        ]

        if let model = config.model {
            arguments.append(contentsOf: ["--model", model])
        }

        if let reasoningEffort = config.reasoningEffort {
            arguments.append(contentsOf: ["--config", "model_reasoning_effort=\"\(reasoningEffort)\""])
        }

        if let serviceTier = config.serviceTier {
            arguments.append(contentsOf: ["--config", "service_tier=\"\(serviceTier)\""])
        }

        arguments.append(trimmedPrompt)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        if let pathEnvironment = launchContext.pathEnvironment {
            environment["PATH"] = pathEnvironment
        }
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let output = ProcessOutput()
                let streamFormatter = CodexStreamFormatter()

                let append: @Sendable (Data) -> Void = { data in
                    guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else {
                        return
                    }

                    output.append(chunk)
                    if let displayText = streamFormatter.append(chunk) {
                        onOutput(displayText)
                    }
                }

                stdout.fileHandleForReading.readabilityHandler = { handle in
                    append(handle.availableData)
                }
                stderr.fileHandleForReading.readabilityHandler = { handle in
                    append(handle.availableData)
                }

                process.terminationHandler = { terminatedProcess in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil

                    append(stdout.fileHandleForReading.readDataToEndOfFile())
                    append(stderr.fileHandleForReading.readDataToEndOfFile())

                    let lastMessage = (try? String(contentsOf: lastMessageURL, encoding: .utf8))?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    try? FileManager.default.removeItem(at: lastMessageURL)

                    let fallbackOutput = output.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalOutput = lastMessage?.isEmpty == false ? lastMessage! : fallbackOutput

                    continuation.resume(
                        returning: CodexExecutionResult(
                            output: finalOutput,
                            exitCode: terminatedProcess.terminationStatus
                        )
                    )
                }

                do {
                    try process.run()
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    try? FileManager.default.removeItem(at: lastMessageURL)
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
            try? FileManager.default.removeItem(at: lastMessageURL)
        }
    }

    private func resolveCodexLaunchContext() -> CodexLaunchContext? {
        let environment = ProcessInfo.processInfo.environment
        let shellPath = resolveFromLoginShell(command: "printf '%s\\n' \"$PATH\"")

        if let configured = environment["CODEX_EXECUTABLE"], FileManager.default.isExecutableFile(atPath: configured) {
            return CodexLaunchContext(executablePath: configured, pathEnvironment: shellPath)
        }

        for path in [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ] where FileManager.default.isExecutableFile(atPath: path) {
            return CodexLaunchContext(executablePath: path, pathEnvironment: shellPath)
        }

        guard let shellCodexPath = resolveFromLoginShell(command: "command -v codex") else {
            return nil
        }

        return CodexLaunchContext(executablePath: shellCodexPath, pathEnvironment: shellPath)
    }

    private func resolveFromLoginShell(command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { !$0.isEmpty }
    }
}

private final class CodexStreamFormatter: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = ""
    private var emittedMessages: Set<String> = []

    func append(_ chunk: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        pending += chunk
        let lines = pending.components(separatedBy: .newlines)
        pending = lines.last ?? ""

        let messages = lines.dropLast().compactMap(formatLine)
        guard !messages.isEmpty else {
            return nil
        }

        return messages.joined(separator: "\n\n") + "\n\n"
    }

    private func formatLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else {
            return nil
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else {
            return nil
        }

        switch type {
        case "turn.started":
            return once("Thinking...")

        case "turn.completed":
            return once("Finalizing...")

        case "item.started":
            guard let item = object["item"] as? [String: Any] else {
                return nil
            }

            if item["type"] as? String == "command_execution", let command = item["command"] as? String {
                return "Running command:\n`\(command)`"
            }

            return nil

        case "item.completed":
            guard let item = object["item"] as? [String: Any], let itemType = item["type"] as? String else {
                return nil
            }

            if itemType == "command_execution", let command = item["command"] as? String {
                let output = (item["aggregated_output"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let output, !output.isEmpty {
                    return "Command finished:\n`\(command)`\n\n```text\n\(output)\n```"
                }

                return "Command finished:\n`\(command)`"
            }

            if itemType == "agent_message" {
                return once("Writing final response...")
            }

            return nil

        default:
            return nil
        }
    }

    private func once(_ message: String) -> String? {
        guard !emittedMessages.contains(message) else {
            return nil
        }

        emittedMessages.insert(message)
        return message
    }
}

private struct CodexLaunchContext {
    let executablePath: String
    let pathEnvironment: String?
}

private final class ProcessOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }

    func append(_ chunk: String) {
        lock.lock()
        text += chunk
        lock.unlock()
    }
}
