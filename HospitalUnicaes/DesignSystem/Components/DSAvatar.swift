import SwiftUI

/// Avatar de iniciales (handoff §5.1): círculo `primary/100` con texto `primary/800` en negrita.
struct DSAvatar: View {
    private let name: String
    private let size: CGFloat

    /// - Parameter size: 32, 36, 40 (por defecto) o 56.
    init(name: String, size: CGFloat = 40) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundStyle(DSColor.avatarForeground)
            .frame(width: size, height: size)
            .background(DSColor.avatarBackground, in: Circle())
            .accessibilityHidden(true)
    }

    /// "Luis Martínez" → "LM"; ignora títulos como "Dr." o "Dra.".
    private var initials: String {
        let titles: Set<String> = ["dr.", "dra.", "lic.", "ing."]
        let words = name
            .split(separator: " ")
            .filter { !titles.contains($0.lowercased()) }
        return words.prefix(2).compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }
}

#Preview("Avatar") {
    HStack(spacing: DSSpacing.medium) {
        DSAvatar(name: "Luis Martínez", size: 32)
        DSAvatar(name: "Dra. Ana Rivas", size: 36)
        DSAvatar(name: "Rosa Guzmán")
        DSAvatar(name: "Carlos Molina", size: 56)
    }
    .padding()
    .background(DSColor.background)
}
