import Core
import ScreenModels
import SwiftUI
import UIKit

/// Opens a mail draft with `openURL`. When no mail app takes it, an alert gives the address to copy.
struct MailComposer: ViewModifier {
    @Binding var url: URL?
    let address: String

    @Environment(\.openURL) private var openURL
    @State private var showsNoMail = false

    func body(content: Content) -> some View {
        content
            .onChange(of: url) { _, newValue in
                guard let newValue else { return }
                url = nil
                openURL(newValue) { accepted in
                    if !accepted { showsNoMail = true }
                }
            }
            .alert(Text("No mail app", bundle: #bundle), isPresented: $showsNoMail) {
                Button(String(localized: "Copy", bundle: #bundle)) { UIPasteboard.general.string = address }
                    .accessibilityIdentifier(AccessibilityID.Feedback.copy)
                Button(String(localized: "OK", bundle: #bundle), role: .cancel) {}
            } message: {
                Text(FeedbackMail.noMailMessage(address: address))
                    .accessibilityIdentifier(AccessibilityID.Feedback.noMailAlert)
            }
    }
}

extension View {
    /// Setting `url` opens it as a mail draft, and clears it.
    func mailComposer(url: Binding<URL?>, address: String = FeedbackAddress.value) -> some View {
        modifier(MailComposer(url: url, address: address))
    }
}
