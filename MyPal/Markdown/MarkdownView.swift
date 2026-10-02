import SwiftUI

struct MarkdownView: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)

        case .heading(let level, let text):
            Text(text)
                .font(level == 1 ? .title3.bold() : level == 2 ? .headline : .subheadline.bold())
                .padding(.top, 2)

        case .bullet(let level, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: level == 0 ? "•" : "◦").foregroundStyle(.secondary)
                Text(text)
            }
            .padding(.leading, CGFloat(level) * 16)

        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(number).").monospacedDigit().foregroundStyle(.secondary)
                Text(text)
            }

        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5).fill(.tertiary).frame(width: 3)
                Text(text).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))

        case .rule:
            Divider()
        }
    }
}
