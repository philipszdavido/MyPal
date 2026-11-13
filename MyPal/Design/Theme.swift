import SwiftUI

enum Theme {
    /// Keeps chat comfortable on iPad / landscape.
    static let contentMaxWidth: CGFloat = 760
}

/// The colors a pal can be given. Stored on `Pal.colorName` by `rawValue`.
enum PalColor: String, CaseIterable, Identifiable {
    /// Light colors (yellow, mint) are left out: white text on them is hard to read.
    case red, orange, green, teal, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    /// Pals without a chosen color get a stable one derived from their name.
    static func resolve(_ name: String?, fallbackFor palName: String) -> PalColor {
        if let name, let color = PalColor(rawValue: name) { return color }
        var hash: UInt32 = 5381
        for scalar in palName.unicodeScalars {
            hash = (hash &* 33) &+ scalar.value
        }
        return allCases[Int(hash % UInt32(allCases.count))]
    }
}

extension Pal {
    var palColor: PalColor { PalColor.resolve(colorName, fallbackFor: name ?? "") }
    var tint: Color { palColor.color }
}

struct PalAvatar: View {
    let name: String
    var emoji: String?
    var color: Color
    var size: CGFloat = 44

    init(pal: Pal, size: CGFloat = 44) {
        self.init(name: pal.name ?? "", emoji: pal.emoji, color: pal.tint, size: size)
    }

    init(name: String, emoji: String?, color: Color, size: CGFloat = 44) {
        self.name = name
        self.emoji = emoji
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle().fill(color.gradient)
            if let emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: size * 0.5))
            } else {
                Text(Self.initials(name))
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }
}
