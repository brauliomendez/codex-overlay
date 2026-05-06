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

        guard let codexPath = resolveCodexPath() else {
            throw CodexExecutorError.executableNotFound
        }

        let lastMessageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-overlay-\(UUID().uuidString).txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        var arguments = [
            "exec",
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

        let environment = ProcessInfo.processInfo.environment
        process.environment = environment.merging(["TERM": "xterm-256color"]) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let output = ProcessOutput()

                let append: @Sendable (Data) -> Void = { data in
                    guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else {
                        return
                    }

                    output.append(chunk)
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

    private func resolveCodexPath() -> String? {
        let environment = ProcessInfo.processInfo.environment

        if let configured = environment["CODEX_EXECUTABLE"], FileManager.default.isExecutableFile(atPath: configured) {
            return configured
        }

        for path in [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ] where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return resolveFromLoginShell()
    }

    private func resolveFromLoginShell() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v codex"]

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

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let path, FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }

        return path
    }
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
