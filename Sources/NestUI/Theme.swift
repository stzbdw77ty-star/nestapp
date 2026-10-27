import SwiftUI

enum NestTheme {
    static let accent = Color("NestAccent", bundle: .module)
    static let canvas = Color("NestCanvas", bundle: .module)
    static let surface = Color("NestSurface", bundle: .module)
    static func colour(_ name: String) -> Color {
        switch name {
        case "mint": Color(red: 0.39, green: 0.72, blue: 0.58)
        case "peach": Color(red: 0.96, green: 0.58, blue: 0.43)
        case "lilac": Color(red: 0.65, green: 0.53, blue: 0.85)
        case "blue": Color(red: 0.43, green: 0.64, blue: 0.85)
        case "pink": Color(red: 0.86, green: 0.48, blue: 0.65)
        default: Color(red: 0.91, green: 0.72, blue: 0.32)
        }
    }
}

struct NestCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NestTheme.surface, in: .rect(cornerRadius: 26))
    }
}

extension View {
    func nestCard() -> some View { modifier(NestCard()) }
}

struct CategoryIcon: View {
    let symbol: String
    let colour: String
    var body: some View {
        Image(systemName: symbol).font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(NestTheme.colour(colour).opacity(0.24), in: .rect(cornerRadius: 15))
            .accessibilityHidden(true)
    }
}

struct NestPage: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
            .background(NestTheme.canvas)
    }
}
extension View {
    func nestPage() -> some View { modifier(NestPage()) }
}
