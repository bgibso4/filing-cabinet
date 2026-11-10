// GENERATED — run make generate. Source: design/tokens.json. Do not edit.

import Core
import SwiftUI

enum Tokens {
    /// The Screens resource bundle, for tests that look assets up by name.
    package static let bundle = Bundle.module

    enum Color {
        static let badgeDocuments = SwiftUI.Color("badge-documents", bundle: .module)
        static let badgeNeutral = SwiftUI.Color("badge-neutral", bundle: .module)
        static let badgeNotes = SwiftUI.Color("badge-notes", bundle: .module)
        static let badgeReceipts = SwiftUI.Color("badge-receipts", bundle: .module)
        static let badgeThrowaways = SwiftUI.Color("badge-throwaways", bundle: .module)
        static let badgeWallet = SwiftUI.Color("badge-wallet", bundle: .module)
        static let bgFill = SwiftUI.Color("bg-fill", bundle: .module)
        static let bgGrouped = SwiftUI.Color("bg-grouped", bundle: .module)
        static let bgSurface = SwiftUI.Color("bg-surface", bundle: .module)
        static let bgWell = SwiftUI.Color("bg-well", bundle: .module)
        static let chevron = SwiftUI.Color("chevron", bundle: .module)
        static let collDocuments = SwiftUI.Color("coll-documents", bundle: .module)
        static let collNotes = SwiftUI.Color("coll-notes", bundle: .module)
        static let collReceipts = SwiftUI.Color("coll-receipts", bundle: .module)
        static let collThrowaways = SwiftUI.Color("coll-throwaways", bundle: .module)
        static let collWallet = SwiftUI.Color("coll-wallet", bundle: .module)
        static let destructive = SwiftUI.Color("destructive", bundle: .module)
        static let expirySoon = SwiftUI.Color("expiry-soon", bundle: .module)
        static let markGround = SwiftUI.Color("mark-ground", bundle: .module)
        static let scanGround = SwiftUI.Color("scan-ground", bundle: .module)
        static let separator = SwiftUI.Color("separator", bundle: .module)
        static let switchKnobOff = SwiftUI.Color("switch-knob-off", bundle: .module)
        static let switchTrackOff = SwiftUI.Color("switch-track-off", bundle: .module)
        static let textPrimary = SwiftUI.Color("text-primary", bundle: .module)
        static let textSecondary = SwiftUI.Color("text-secondary", bundle: .module)
        static let textTertiary = SwiftUI.Color("text-tertiary", bundle: .module)
        static let tint = SwiftUI.Color("tint", bundle: .module)

        /// The round badge behind a collection's white symbol.
        static func badge(_ collection: BuiltInCollection) -> SwiftUI.Color {
            SwiftUI.Color("badge-\(collection.rawValue)", bundle: .module)
        }
    }

    enum Spacing {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        static let tapMin: CGFloat = 44
    }

    enum Radius {
        static let surface: CGFloat = 14
        static let nested: CGFloat = 6
        static let pill: CGFloat = 999
    }

    /// Text styles scale with Dynamic Type; each matches the design size at the default setting.
    enum Typography {
        /// 34 pt
        static let largeTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
        /// 28 pt
        static let title1 = Font.system(.title, design: .serif, weight: .bold)
        /// 22 pt
        static let title2 = Font.system(.title2, design: .serif, weight: .bold)
        /// 17 pt
        static let headline = Font.system(.headline, design: .default, weight: .semibold).monospacedDigit()
        /// 17 pt
        static let body = Font.system(.body, design: .default, weight: .regular).monospacedDigit()
        /// 15 pt
        static let subheadline = Font.system(.subheadline, design: .default, weight: .regular).monospacedDigit()
        /// 13 pt
        static let footnote = Font.system(.footnote, design: .default, weight: .regular).monospacedDigit()
        /// 12 pt
        static let caption = Font.system(.caption, design: .default, weight: .regular).monospacedDigit()

        /// Letter spacing in points for `largeTitle`.
        static let largeTitleTracking: CGFloat = -0.4
    }

    /// The template symbol for a collection, drawn white on its badge.
    static func symbol(_ collection: BuiltInCollection) -> Image {
        Image("symbol-\(collection.rawValue)", bundle: .module).renderingMode(.template)
    }
}
