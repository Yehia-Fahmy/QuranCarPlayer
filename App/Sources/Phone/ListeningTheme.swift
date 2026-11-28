import SwiftUI

enum ListeningTheme: String, CaseIterable {
    static let preferenceKey = "listeningTheme"

    static let systemPreference = "system"

    case folio, studio, nocturne, grove, copper

    static func resolve(_ preference: String, appearance: ColorScheme) -> Self {
        Self(rawValue: preference) ?? (appearance == .dark ? .nocturne : .folio)
    }

    var colorScheme: ColorScheme {
        switch self {
        case .folio, .studio, .grove: .light
        case .nocturne, .copper: .dark
        }
    }

    var accent: Color {
        switch self {
        case .grove: Color(red: 0.11, green: 0.34, blue: 0.22)
        case .copper: Color(red: 0.99, green: 0.69, blue: 0.45)
        case .folio: Color(red: 0.51, green: 0.23, blue: 0.12)
        case .studio: Color(red: 0.32, green: 0.24, blue: 0.67)
        case .nocturne: Color(red: 0.66, green: 0.84, blue: 0.95)
        }
    }

    var background: Color {
        switch self {
        case .grove: Color(red: 0.81, green: 0.88, blue: 0.81)
        case .copper: Color(red: 0.10, green: 0.09, blue: 0.085)
        case .folio: Color(red: 0.96, green: 0.94, blue: 0.89)
        case .studio: Color(red: 0.94, green: 0.93, blue: 0.98)
        case .nocturne: Color(red: 0.06, green: 0.09, blue: 0.14)
        }
    }

    var surface: Color {
        switch self {
        case .grove: Color(red: 0.95, green: 0.97, blue: 0.92)
        case .copper: Color(red: 0.21, green: 0.17, blue: 0.15)
        case .folio: Color(red: 1, green: 0.985, blue: 0.95)
        case .studio: .white
        case .nocturne: Color(red: 0.10, green: 0.15, blue: 0.21)
        }
    }
}

extension EnvironmentValues {
    @Entry var listeningTheme: ListeningTheme = .folio
}

extension View {
    func listeningListBackground(_ theme: ListeningTheme) -> some View {
        scrollContentBackground(.hidden)
            .background(theme.background)
    }
}
