import SwiftUI

struct Fixture: View {
    @State private var x = false
    @State private var d = Date()
    var body: some View {
        Color.clear.alert("Couldn’t save this scan", isPresented: $x) {}
    }
}
