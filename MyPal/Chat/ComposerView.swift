import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isEnabled: Bool
    let isReplying: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var dictation = Dictation.shared

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum Action { case send, stop, dictate, stopDictating }

    /// The trailing button is send / stop while there's something to act on, and a mic otherwise.
    private var action: Action {
        if isReplying { return .stop }
        if dictation.isRecording { return .stopDictating }
        return canSend ? .send : .dictate
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(isEnabled ? (dictation.isRecording ? "Listening…" : "Message") : "Unavailable", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .focused(isFocused)
                .disabled(!isEnabled)
                .textInputAutocapitalization(.sentences)
                .padding(.leading, 16)
                .padding(.vertical, 11)

            Button(action: perform) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(background))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: action == .stopDictating)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .accessibilityLabel(accessibilityLabel)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.snappy(duration: 0.15), value: isReplying)
        .onDisappear { dictation.stop() }
        .alert(
            "Dictation",
            isPresented: Binding(get: { dictation.errorMessage != nil }, set: { if !$0 { dictation.clearError() } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.errorMessage ?? "")
        }
    }

    private var symbol: String {
        switch action {
        case .send: "arrow.up"
        case .stop: "stop.fill"
        case .dictate: "mic.fill"
        case .stopDictating: "waveform"
        }
    }

    private var background: AnyShapeStyle {
        switch action {
        case .stopDictating: AnyShapeStyle(Color.red)
        case .dictate: AnyShapeStyle(Color.secondary.opacity(isEnabled ? 0.6 : 0.35))
        default: isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.35))
        }
    }

    private var accessibilityLabel: String {
        switch action {
        case .send: "Send"
        case .stop: "Stop generating"
        case .dictate: "Dictate"
        case .stopDictating: "Stop dictating"
        }
    }

    private func perform() {
        switch action {
        case .send:
            dictation.stop()
            onSend()
        case .stop:
            onStop()
        case .dictate:
            let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                await dictation.start { transcript in
                    text = prefix.isEmpty ? transcript : prefix + " " + transcript
                }
            }
        case .stopDictating:
            dictation.stop()
        }
    }
}
