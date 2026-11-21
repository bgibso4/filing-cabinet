import Core
import Foundation
import Screens
import Testing
import UIKit
import UserNotifications

@testable import FilingCabinet

/// The app's own launch, in the app's process: M20's safety net removes the PDFs a share left in the temporary folder,
/// and a tapped note is heard and answered on the main thread.
@MainActor
struct AppLaunchTests {
    @Test func launchRemovesExportedPDFs() async throws {
        let left = FileManager.default.temporaryDirectory.appending(path: "Export/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: left, withIntermediateDirectories: true)
        try Data([1]).write(to: left.appending(path: "Left.pdf"))
        // `-UITest` turns animations off for the process; the snapshot tests that follow keep theirs.
        let animations = UIView.areAnimationsEnabled
        defer { UIView.setAnimationsEnabled(animations) }
        let environment = try AppEnvironment.make(
            arguments: ["-UITest", "-Notifications", "authorized"], analytics: LogAnalytics())

        await environment.launch()

        #expect(!FileManager.default.fileExists(atPath: left.path(percentEncoded: false)))
    }

    /// Build 21 crashed on any tapped note: the answer to iOS came from a background thread, where UIKit's own work
    /// after it asserts. This calls the listener the app set at launch the way iOS does, on the main thread.
    @Test func aTappedNoteIsAnsweredOnTheMainThread() async throws {
        let listener = try #require(UNUserNotificationCenter.current().delegate)
        let tap = try #require(TappedNote.response(noteID: "reminder-1"))

        let answeredOnMain = await withCheckedContinuation { continuation in
            listener.userNotificationCenter?(.current(), didReceive: tap) {
                continuation.resume(returning: Thread.isMainThread)
            }
        }

        #expect(answeredOnMain)
    }

    /// The whole path of a tap, from iOS's call to the request the root acts on. The id is one build 21 scheduled.
    @Test(.timeLimit(.minutes(1)))
    func aTappedCleanupNoteAsksForTrash() async throws {
        let requests = ExternalRequests()
        let listener: any UNUserNotificationCenterDelegate = CleanupNoteTaps(requests: requests)
        let tap = try #require(TappedNote.response(noteID: "cleanup-2026-10-12"))

        listener.userNotificationCenter?(.current(), didReceive: tap) {}
        while requests.pending == nil { await Task.yield() }

        #expect(requests.pending == .trash)
    }
}

/// A tapped note as iOS hands it over. iOS gives these types no initialiser, so they are decoded from the values they
/// hold.
private enum TappedNote {
    static func response(noteID: String) -> UNNotificationResponse? {
        let request = UNNotificationRequest(identifier: noteID, content: UNNotificationContent(), trigger: nil)
        guard let notification = UNNotification(coder: ValuesCoder(["request": request, "date": Date.now])) else {
            return nil
        }
        return UNNotificationResponse(
            coder: ValuesCoder([
                "notification": notification, "actionIdentifier": UNNotificationDefaultActionIdentifier,
            ])
        )
    }
}

/// A coder that answers each key with the value it was given.
nonisolated private final class ValuesCoder: NSCoder {
    private let values: [String: Any]

    init(_ values: [String: Any]) {
        self.values = values
    }

    override var allowsKeyedCoding: Bool { true }
    override var requiresSecureCoding: Bool { false }
    override func containsValue(forKey key: String) -> Bool { values[key] != nil }
    override func decodeObject(forKey key: String) -> Any? { values[key] }
    override func decodeBool(forKey key: String) -> Bool { false }
    override func decodeInteger(forKey key: String) -> Int { 0 }
    override func decodeInt64(forKey key: String) -> Int64 { 0 }
}
