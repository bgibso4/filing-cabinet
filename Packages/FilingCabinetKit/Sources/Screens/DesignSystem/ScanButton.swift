import SwiftUI

/// The Scan pill: graphite in light, near-white in dark, always labelled "Scan".
struct ScanButton: View {
    private let identifier: String
    private let action: () -> Void

    init(identifier: String, action: @escaping () -> Void) {
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        FilledPillButton(identifier: identifier, action: action) {
            HStack(spacing: Tokens.Spacing.s2) {
                Image(systemName: "text.viewfinder")
                Text("Scan", bundle: #bundle)
            }
        }
    }
}

#Preview("Light") {
    ScanButton(identifier: "preview") {}.padding()
}

#Preview("Dark") {
    ScanButton(identifier: "preview") {}.padding().background(Tokens.Color.bgGrouped).preferredColorScheme(.dark)
}
