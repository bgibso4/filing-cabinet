import Foundation

/// The launch flags UI tests and `make run-fake` pass. Parsed only in Debug: a Release build passes
/// `isDebugBuild: false` and every field keeps its default (M9). Unknown flags and missing or invalid values
/// are ignored.
public struct LaunchOptions: Sendable, Equatable {
    /// `-UITest`: in-memory store, a temporary library folder, no animations.
    public private(set) var isUITest = false
    /// `-FakeCamera <1…3>`: the fake camera returns this many synthetic pages.
    public private(set) var fakeCameraPages: Int?
    /// `-CameraDenied`: camera access reports denied.
    public private(set) var cameraDenied = false
    /// `-FixedDate yyyy-MM-dd`: the clock stands still at noon UTC on that day.
    public private(set) var fixedDate: Date?
    /// `-SeedScans <n>`: saves `n` synthetic scans at launch.
    public private(set) var seedScans: Int?
    /// `-SeedTrash <n>`: saves `n` synthetic scans at launch, already moved to Trash on staggered days.
    public private(set) var seedTrash: Int?
    /// `-SeedFavorites <n>`: the first `n` scans `-SeedScans` saves are favourites, in seed order.
    public private(set) var seedFavorites: Int?
    /// `-FailSave`: the next page write fails with a full disk.
    public private(set) var failNextSave = false
    /// `-FakeReader`: every page reads as the synthetic City Pharmacy receipt (M16).
    public private(set) var fakeReader = false
    /// `-ReduceMotion`: the capture layer and Home take their Reduce Motion paths whatever the system setting.
    public private(set) var reduceMotion = false
    /// `-TextReader text|documents`: which Vision reader understands pages (A12, A15).
    public private(set) var reader = ReaderKind.text
    /// `-Notifications authorized|denied|notDetermined`: a fake notification center answers with this authorization.
    public private(set) var notifications: NotificationAuthorization?
    /// `-NotificationsUnanswered`: a fake notification center that never answers what iOS allows, like a stuck
    /// notification service.
    public private(set) var notificationsUnanswered = false
    /// `-Photos authorized|denied`: a fake Photos answers with this access, so no system prompt shows.
    public private(set) var photos: PhotosAuthorization?
    /// `-Suggestions arrives|slow|unavailable`: a scripted suggester for the review (M5).
    public private(set) var suggestions: SuggestionsFlag?
    /// `-FailLibraryOpen`, optionally followed by `once`: opening the library fails on every attempt, or the first.
    public private(set) var failLibraryOpen: FailLibraryOpen?
    /// `-ShowWelcome`: under `-UITest` the welcome shows as on a first launch; otherwise it counts as done (M1).
    public private(set) var showWelcome = false

    private static let fakeCameraRange = 1...3

    public init(arguments: [String], isDebugBuild: Bool) {
        guard isDebugBuild else { return }
        for (index, flag) in arguments.enumerated() {
            // A value is never skipped over: if it is really the next flag, it fails to parse here and is
            // read as a flag on its own turn.
            let value = arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            if !setSwitch(flag, next: value) {
                setValue(of: flag, to: value)
            }
        }
    }

    /// Sets the flag if it needs no value (`next` may qualify it); false when it is not one of those.
    private mutating func setSwitch(_ flag: String, next: String?) -> Bool {
        switch flag {
        case "-FailLibraryOpen": failLibraryOpen = next == "once" ? .once : .always
        case "-UITest": isUITest = true
        case "-CameraDenied": cameraDenied = true
        case "-FailSave": failNextSave = true
        case "-FakeReader": fakeReader = true
        case "-ReduceMotion": reduceMotion = true
        case "-NotificationsUnanswered": notificationsUnanswered = true
        case "-ShowWelcome": showWelcome = true
        default: return false
        }
        return true
    }

    private mutating func setValue(of flag: String, to value: String?) {
        guard let value, !setChoice(of: flag, to: value) else { return }
        switch flag {
        case "-FakeCamera": fakeCameraPages = Int(value).flatMap { Self.fakeCameraRange ~= $0 ? $0 : nil }
        case "-FixedDate": fixedDate = Self.noonUTC(value)
        case "-SeedScans": seedScans = Self.count(value)
        case "-SeedTrash": seedTrash = Self.count(value)
        case "-SeedFavorites": seedFavorites = Self.count(value)
        default: break
        }
    }

    /// Sets the flag if its value names one of a fixed set of choices; false when it is not one of those flags.
    private mutating func setChoice(of flag: String, to value: String) -> Bool {
        switch flag {
        case "-TextReader": reader = ReaderKind(rawValue: value) ?? reader
        case "-Notifications": notifications = NotificationAuthorization(rawValue: value)
        case "-Photos": photos = PhotosAuthorization(rawValue: value)
        case "-Suggestions": suggestions = SuggestionsFlag(rawValue: value)
        default: return false
        }
        return true
    }

    /// A seed count: zero or more.
    private static func count(_ text: String) -> Int? {
        Int(text).flatMap { $0 >= 0 ? $0 : nil }
    }

    /// `yyyy-MM-dd` at 12:00 UTC, or nil when it is not a real day.
    private static func noonUTC(_ text: String) -> Date? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month), (1...31).contains(day),
            let storageDay = CalendarDay(storageValue: year * 10_000 + month * 100 + day)
        else { return nil }
        var utc = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(secondsFromGMT: 0) else { return nil }
        utc.timeZone = zone
        return utc.date(
            from: DateComponents(year: storageDay.year, month: storageDay.month, day: storageDay.day, hour: 12))
    }
}
