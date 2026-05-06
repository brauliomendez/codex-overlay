import SwiftUI

struct OverlayView: View {
    @EnvironmentObject private var model: OverlayViewModel
    @FocusState private var promptFocused: Bool

    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.showsSettings {
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(alignment: .leading, spacing: 14) {
                workspace
                actions
            }
            .padding(18)
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 360, idealHeight: 430)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                promptFocused = true
            }
        }
        .onExitCommand {
            onClose()
        }
        .onChange(of: model.isShowingResponse) { _, isShowingResponse in
            if !isShowingResponse {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    promptFocused = true
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Overlay")
                    .font(.headline)

                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    model.showsSettings.toggle()
                }
            } label: {
                Image(systemName: model.showsSettings ? "gearshape.fill" : "gearshape")
            }
            .buttonStyle(.borderless)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.thinMaterial)
    }

    private var settingsPanel: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $model.selectedModel) {
                    ForEach(model.modelOptions, id: \.self) { option in
                        Text(option == "Default" ? model.defaultModelLabel : option).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 220)

                Text("Reasoning")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Reasoning", selection: $model.selectedReasoningEffort) {
                    ForEach(model.reasoningOptions, id: \.self) { option in
                        Text(option == "Default" ? model.defaultReasoningLabel : option).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                Text("Tier")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Tier", selection: $model.selectedServiceTier) {
                    ForEach(model.serviceTierOptions, id: \.self) { option in
                        Text(option == "Default" ? model.defaultServiceTierLabel : option).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.isShowingResponse ? "Response" : "Prompt")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(model.runSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ZStack(alignment: .topLeading) {
                if model.isShowingResponse {
                    responseOutput
                } else {
                    promptInput
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var promptInput: some View {
        TextEditor(text: $model.prompt)
            .font(.system(.body, design: .monospaced))
            .focused($promptFocused)
            .scrollContentBackground(.hidden)
            .padding(8)
    }

    private var responseOutput: some View {
        ScrollView {
            MarkdownResponseView(markdown: responseText, isPlaceholder: model.isRunning || model.response.isEmpty)
                .padding(12)
        }
    }

    private var responseText: String {
        if !model.response.isEmpty {
            return model.response
        }

        return model.isRunning ? "Loading..." : "No response yet."
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if model.isShowingResponse {
                Button {
                    model.newPrompt()
                } label: {
                    Label("New Prompt", systemImage: "square.and.pencil")
                }
                .disabled(model.isRunning)

                Button {
                    model.copyResponse()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.response.isEmpty || model.isRunning)

                Button {
                    model.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .disabled(!model.isRunning)
            } else {
                Button {
                    model.runPrompt()
                } label: {
                    Label("Run", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    model.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(model.prompt.isEmpty)
            }

            Spacer()
        }
    }
}
