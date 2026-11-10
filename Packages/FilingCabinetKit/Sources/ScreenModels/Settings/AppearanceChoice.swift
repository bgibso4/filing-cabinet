import Foundation

/// Settings › Appearance: follow the phone, or stay light or dark whatever the phone does.
public enum AppearanceChoice: String, CaseIterable {
    case system
    case light
    case dark

    /// What was stored; a value this build doesn't know (or none) follows the phone.
    init(stored: String?) {
        self = stored.flatMap(Self.init(rawValue:)) ?? .system
    }

    package var title: String {
        switch self {
        case .system: return String(localized: "System", bundle: #bundle)
        case .light: return String(localized: "Light", bundle: #bundle)
        case .dark: return String(localized: "Dark", bundle: #bundle)
        }
    }
}
