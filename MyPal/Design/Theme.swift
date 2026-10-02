import SwiftUI

enum Theme {
    /// Keeps chat comfortable on iPad / landscape.
    static let contentMaxWidth: CGFloat = 760
}

struct PalAvatar: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let hue = Self.hue(for: name)
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.55, brightness: 0.95),
                        Color(hue: hue, saturation: 0.75, brightness: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            Text(Self.initials(name))
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Stable across launches (unlike `String.hashValue`).
    private static func hue(for name: String) -> Double {
        var hash: UInt32 = 5381
        for scalar in name.unicodeScalars {
            hash = (hash &* 33) &+ scalar.value
        }
        return Double(hash % 360) / 360
    }

    private static func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }
}
