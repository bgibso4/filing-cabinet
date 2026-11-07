import SwiftUI

/// A separator line one device pixel tall, in the separator colour.
struct Hairline: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Tokens.Color.separator.frame(height: 1 / displayScale)
    }
}
