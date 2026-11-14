import AppIntents

/// The app's Shortcuts actions and Siri phrases (Plan 6 §7, 11-07). Siri phrases can't carry free text, so Find a scan
/// asks for it.
struct FilingCabinetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan with \(.applicationName)",
                "Scan a document in \(.applicationName)",
            ],
            shortTitle: "Scan a document",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: FindScanIntent(),
            phrases: ["Find a scan in \(.applicationName)"],
            shortTitle: "Find a scan",
            systemImageName: "magnifyingglass"
        )
    }
}
