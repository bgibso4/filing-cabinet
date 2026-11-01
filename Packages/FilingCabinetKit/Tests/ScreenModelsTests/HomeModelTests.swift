import Testing

@testable import ScreenModels

@Test func rowsMatchTheFirstLaunchDesign() {
    let home = HomeModel()
    #expect(home.rows.map(\.name) == ["Wallet", "Receipts", "Notes", "Documents", "Throwaways"])
    #expect(
        home.rows.map(\.subtitle) == [
            "IDs and cards · Kept forever", "Purchase receipts · 3 months", "Handwritten notes · Kept forever",
            "Forms and letters · Kept forever", "Short-lived scraps · 1 week",
        ])
}
