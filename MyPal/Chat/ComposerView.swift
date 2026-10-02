import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isEnabled: Bool
    let isReplying: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var buttonIsActive: Bool {
        isEnabled && (isReplying || canSend)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(isEnabled ? "Message" : "Unavailable", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .focused(isFocused)
                .disabled(!isEnabled)
                .textInputAutocapitalization(.sentences)
                .padding(.leading, 16)
                .padding(.vertical, 11)

            Button(action: isReplying ? onStop : onSend) {
                Image(systemName: isReplying ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(buttonIsActive ? Color.accentColor : Color.secondary.opacity(0.35)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(!buttonIsActive)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .accessibilityLabel(isReplying ? "Stop generating" : "Send")
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.snappy(duration: 0.15), value: isReplying)
    }
}
