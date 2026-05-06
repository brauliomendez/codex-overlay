import AppKit
import Foundation

@MainActor
final class OverlayViewModel: ObservableObject {
    static let shared = OverlayViewModel()

    @Published var prompt = ""
    @Published var response = ""
    @Published var status = "Ready"
    @Published var isRunning = false
    @Published var workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).path
    @Published var selectedModel = "Default"
    @Published var selectedReasoningEffort = "Default"
    @Published var selectedServiceTier = "fast"
    @Published var showsSettings = false
    @Published var isShowingResponse = false

    let codexDefaults = CodexDefaults.load()
    let modelOptions = ["Default", "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex", "gpt-5.3-codex-spark", "gpt-5.2"]
    let reasoningOptions = ["Default", "low", "medium", "high", "xhigh"]
    let serviceTierOptions = ["Default", "fast", "auto"]

    private var runTask: Task<Void, Never>?

    private init() {}

    var runSummary: String {
        "model=\(effectiveModelName)  reasoning=\(effectiveReasoningEffort)  tier=\(effectiveServiceTier)"
    }

    var defaultModelLabel: String {
        "Default (\(codexDefaults.model))"
    }

    var defaultReasoningLabel: String {
        "Default (\(codexDefaults.reasoningEffort))"
    }

    var defaultServiceTierLabel: String {
        "Default (\(codexDefaults.serviceTier))"
    }

    func runPrompt() {
        guard !isRunning else {
            return
        }

        response = ""
        status = "Running codex exec..."
        isRunning = true
        isShowingResponse = true

        let currentPrompt = prompt
        let currentConfig = currentConfig

        runTask = Task {
            do {
                let executor = CodexExecutor()
                let result = try await executor.run(prompt: currentPrompt, config: currentConfig) { [weak self] chunk in
                    Task { @MainActor in
                        self?.response += chunk
                    }
                }

                response = result.output
                isRunning = false

                if result.exitCode == 0 {
                    status = "Done."
                } else {
                    status = "Codex exited with code \(result.exitCode)."
                }
            } catch {
                response = error.localizedDescription
                isRunning = false
                status = error.localizedDescription
            }
        }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        prompt = ""
        response = ""
        isRunning = false
        isShowingResponse = false
        status = "Ready"
    }

    func newPrompt() {
        runTask?.cancel()
        runTask = nil
        prompt = ""
        response = ""
        isRunning = false
        isShowingResponse = false
        status = "Ready"
    }

    func copyResponse() {
        guard !response.isEmpty else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(response, forType: .string)
        status = "Copied to clipboard."
    }

    func clear() {
        prompt = ""
        response = ""
        isShowingResponse = false
        status = "Ready"
    }

    private var currentConfig: OverlayConfig {
        OverlayConfig(
            model: selectedModel == "Default" ? nil : selectedModel,
            reasoningEffort: selectedReasoningEffort == "Default" ? nil : selectedReasoningEffort,
            serviceTier: selectedServiceTier == "Default" ? nil : selectedServiceTier,
            workingDirectory: workingDirectory
        )
    }

    private var effectiveModelName: String {
        selectedModel == "Default" ? codexDefaults.model : selectedModel
    }

    private var effectiveReasoningEffort: String {
        selectedReasoningEffort == "Default" ? codexDefaults.reasoningEffort : selectedReasoningEffort
    }

    private var effectiveServiceTier: String {
        selectedServiceTier == "Default" ? codexDefaults.serviceTier : selectedServiceTier
    }
}
