import ScreenModels
import Screens
import SwiftUI

@main
struct FilingCabinetApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(model: HomeModel(), onScan: {})
        }
    }
}
