import SwiftUI
import UIKit

extension View {
    /// Shown by Save to Photos once the person has turned Photos access off (M11): iOS won't ask again, so it points to
    /// Settings, as the camera's sheet does.
    func photosAccessOffAlert(isPresented: Binding<Bool>, openURL: OpenURLAction) -> some View {
        alert(Text("Photos access is off", bundle: #bundle), isPresented: isPresented) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("Open Settings", bundle: #bundle)
            }
            Button(role: .cancel) {
            } label: {
                Text("Cancel", bundle: #bundle)
            }
        } message: {
            Text(
                "Filing Cabinet needs to add to Photos to save scans there. Tap Open Settings, then Photos, and choose Add Photos Only.",
                bundle: #bundle)
        }
    }
}
