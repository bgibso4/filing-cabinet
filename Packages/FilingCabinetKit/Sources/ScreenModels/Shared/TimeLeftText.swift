import Core
import Foundation

/// "3 months left" and friends. Expired scans never reach it: they are hidden (M5).
enum TimeLeftText {
    static func text(_ left: TimeLeft) -> String {
        switch left {
        case .forever:
            String(localized: "Kept forever", bundle: #bundle)
        case .expired:
            // Hidden everywhere, but a viewer left open across midnight can reach it. Never claim permanence.
            String(localized: "\(0) days left", bundle: #bundle)
        case .days(let days) where days >= 365:
            String(localized: "\(days / 365) years left", bundle: #bundle)
        case .days(let days) where days >= 60:
            String(localized: "\(days / 30) months left", bundle: #bundle)
        case .days(let days):
            String(localized: "\(days) days left", bundle: #bundle)
        }
    }
}
