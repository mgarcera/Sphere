import SwiftUI

/// Named colors live in Assets.xcassets so they stay editable outside code.
/// Hex values come from the palette table in the product brief.
enum Theme {
    static let background   = Color("Background")
    static let ink          = Color("Ink")
    static let muted        = Color("Muted")
    static let mutedLight   = Color("MutedLight")
    static let mutedLighter = Color("MutedLighter")
    static let hairline     = Color("Hairline")
    static let hairlineSoft = Color("HairlineSoft")
    static let taskActive   = Color("TaskActive")
    static let taskInactive = Color("TaskInactive")

    /// The wheel is chrome in light and the black iPod in dark.
    enum Wheel {
        static let faceTop      = Color("WheelFaceTop")
        static let faceBottom   = Color("WheelFaceBottom")
        static let buttonTop    = Color("WheelButtonTop")
        static let buttonBottom = Color("WheelButtonBottom")
        static let edge         = Color("WheelEdge")
        static let label        = Color("WheelLabel")
    }
}

extension Font {
    /// Display/title face. `.serif` resolves to New York on iOS.
    static func display(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// Light, dark, or follow the device. Every colour is an asset-catalog pair,
/// so overriding the scheme is all this has to do.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
