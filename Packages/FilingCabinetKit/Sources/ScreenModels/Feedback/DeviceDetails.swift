import Foundation

/// What a feedback email says about this phone: the app and system versions and the device model. Never anything
/// from the library. Public for the failure screen's model, which the app makes (#40).
public struct DeviceDetails: Equatable, Sendable {
    let version: String
    let build: String
    /// "iOS 27.2".
    let system: String
    /// The hardware identifier, e.g. "iPhone17,3".
    let model: String

    public static func current(bundle: Bundle = .main) -> Self {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        var uts = utsname()
        uname(&uts)
        let machine = withUnsafeBytes(of: &uts.machine) { raw in
            String(bytes: raw.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
        // The fallbacks apply only where the bundle has no Info.plist version keys (a test host or a macOS test run).
        return Self(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            system: "iOS \(system.majorVersion).\(system.minorVersion)",
            model: machine)
    }

    package var detailsLine: String {
        "Filing Cabinet \(version) (\(build)) · \(system) · \(model)"
    }
}
