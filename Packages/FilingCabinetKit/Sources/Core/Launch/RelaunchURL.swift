import Foundation

/// How a UI test starts its next test in the running app instead of launching it again: the app opens this URL
/// and rebuilds its environment from the launch flags it carries. On CI a launch costs about 10 s; this, about 1 s.
/// The app acts on it only in a Debug build that was itself launched with `-UITest`.
public enum RelaunchURL {
    /// Registered in the app's Info.plist.
    public static let scheme = "filingcabinet-uitest"
    private static let host = "relaunch"
    private static let argumentName = "arg"

    /// The URL that relaunches the app with `arguments`, the same launch flags `XCUIApplication` would pass.
    public static func make(arguments: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = arguments.map { URLQueryItem(name: argumentName, value: $0) }
        return components.url
    }

    /// The launch flags in a relaunch URL, or nil when `url` is not one.
    public static func arguments(from url: URL) -> [String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == scheme, components.host == host
        else { return nil }
        return (components.queryItems ?? []).filter { $0.name == argumentName }.compactMap(\.value)
    }
}
