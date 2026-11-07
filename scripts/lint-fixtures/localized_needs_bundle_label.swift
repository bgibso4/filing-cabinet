import SwiftUI

struct Fixture: View {
    @State private var x = false
    @State private var d = Date()
    var body: some View {
        Label("Wallet", systemImage: "creditcard")
    }
}
