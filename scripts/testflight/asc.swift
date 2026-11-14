// App Store Connect for the TestFlight workflow. Reads ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the .p8 file).
// Errors print the API's error title and detail; the key and the token are never printed.
import CryptoKit
import Foundation

let usage = """
    usage: swift scripts/testflight/asc.swift <command>

      send-to-friends --build <n> --whats-new <text> [--dry-run]
          Waits until build <n> has processed (every 30 s, up to 45 min), sets its What to Test, adds it to the
          external beta group "Friends" and submits it for beta review when TestFlight asks for one. --dry-run does
          the reads (the groups, Test Information, the build and its state) and says what it would change.
      count-certificates [--type <certificateType>]
          Prints how many certificates the team has (of that type, e.g. DEVELOPMENT). Read-only.
    """
let bundleID = "com.cadre.filingcabinet"
let friendsGroup = "Friends"
let pollInterval: Duration = .seconds(30)
let processingTimeout: Duration = .seconds(45 * 60)

struct Failure: Error {
    let message: String
}

/// A line to standard output (scripts don't log; the workflow reads this).
func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - The API

typealias JSON = [String: Any]

/// One resource of a JSON:API document.
struct Resource {
    let id: String
    let attributes: JSON

    init(_ json: JSON) throws {
        guard let id = json["id"] as? String else { throw Failure(message: "a resource without an id") }
        self.id = id
        attributes = json["attributes"] as? JSON ?? [:]
    }

    func string(_ key: String) -> String? { attributes[key] as? String }
}

struct Client {
    let keyID: String
    let issuerID: String
    let key: P256.Signing.PrivateKey

    /// An ES256 token for the App Store Connect API, good for 15 minutes; a new one for each request.
    func token() throws -> String {
        let header: JSON = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        let payload: JSON = [
            "iss": issuerID, "exp": Int(Date().timeIntervalSince1970) + 15 * 60, "aud": "appstoreconnect-v1",
        ]
        let input = try [header, payload]
            .map { try base64URL(JSONSerialization.data(withJSONObject: $0)) }
            .joined(separator: ".")
        let signature = try key.signature(for: Data(input.utf8)).rawRepresentation
        return input + "." + base64URL(signature)
    }

    func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    @discardableResult
    func send(_ method: String, _ path: String, query: [String: String] = [:], body: JSON? = nil) async throws -> JSON {
        guard var components = URLComponents(string: "https://api.appstoreconnect.apple.com" + path) else {
            throw Failure(message: "bad path \(path)")
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw Failure(message: "bad query for \(path)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // A 204 has no body.
        let json = data.isEmpty ? [:] : (try JSONSerialization.jsonObject(with: data) as? JSON ?? [:])
        guard (200..<300).contains(status) else {
            let error = (json["errors"] as? [JSON])?.first
            let title = error?["title"] as? String ?? "HTTP \(status)"
            let detail = (error?["detail"] as? String).map { ": \($0)" } ?? ""
            throw Failure(message: "App Store Connect, \(method) \(path) (HTTP \(status)): \(title)\(detail)")
        }
        return json
    }

    func list(_ path: String, query: [String: String] = [:]) async throws -> [Resource] {
        let json = try await send("GET", path, query: query)
        return try (json["data"] as? [JSON] ?? []).map(Resource.init)
    }

    /// A to-one relationship's resource, or nil when there is none.
    func one(_ path: String) async throws -> Resource? {
        let json = try await send("GET", path)
        return try (json["data"] as? JSON).map(Resource.init)
    }
}

func makeClient() -> Client {
    let environment = ProcessInfo.processInfo.environment
    let names = ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"]
    let missing = names.filter { (environment[$0] ?? "").isEmpty }
    guard missing.isEmpty, let keyID = environment["ASC_KEY_ID"], let issuerID = environment["ASC_ISSUER_ID"],
        let keyPath = environment["ASC_KEY_PATH"]
    else { fail("not set: \(missing.joined(separator: " "))") }
    // try?: the reasons below are enough, and the key's own errors could quote it, so they are never shown.
    guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8) else { fail("can't read ASC_KEY_PATH") }
    // try?: as above, never show the key's parse error.
    guard let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        fail("ASC_KEY_PATH isn't an App Store Connect .p8 key")
    }
    return Client(keyID: keyID, issuerID: issuerID, key: key)
}

// MARK: - Commands

func appID(_ client: Client) async throws -> Resource {
    let apps = try await client.list("/v1/apps", query: ["filter[bundleId]": bundleID])
    guard let app = apps.first(where: { $0.string("bundleId") == bundleID }) else {
        throw Failure(message: "no app with bundle ID \(bundleID) in App Store Connect")
    }
    return app
}

/// Waits until the build has processed, and returns it.
func processedBuild(_ number: String, app: String, client: Client) async throws -> Resource {
    let clock = ContinuousClock()
    let deadline = clock.now + processingTimeout
    var last = ""
    while true {
        let builds = try await client.list("/v1/builds", query: ["filter[app]": app, "filter[version]": number])
        let state = builds.first?.string("processingState") ?? "not in App Store Connect yet"
        if state != last {
            say("Build \(number): \(state)")
            last = state
        }
        if let build = builds.first, state == "VALID" { return build }
        if state == "FAILED" || state == "INVALID" { throw Failure(message: "build \(number) is \(state)") }
        guard clock.now < deadline else { throw Failure(message: "build \(number) didn't process within 45 min") }
        try await Task.sleep(for: pollInterval)
    }
}

/// Prints the app's beta groups and what's missing from its Test Information (needed for beta review).
func describeSetup(app: String, client: Client) async throws -> [Resource] {
    let groups = try await client.list("/v1/apps/\(app)/betaGroups", query: ["limit": "200"])
    for group in groups {
        let kind = group.attributes["isInternalGroup"] as? Bool == true ? "internal" : "external"
        let automatic = group.attributes["hasAccessToAllBuilds"] as? Bool == true ? ", automatic distribution" : ""
        say("Beta group: \(group.string("name") ?? "?") (\(kind)\(automatic))")
    }
    func missing(_ resource: Resource?, _ keys: [String]) -> [String] {
        keys.filter { (resource?.string($0) ?? "").isEmpty }
    }
    let localizations = try await client.list("/v1/apps/\(app)/betaAppLocalizations")
    let localization = localizations.first
    let gaps =
        missing(localization, ["description", "feedbackEmail", "privacyPolicyUrl"])
        + missing(
            try await client.one("/v1/apps/\(app)/betaAppReviewDetail"),
            ["contactFirstName", "contactLastName", "contactPhone", "contactEmail"])
    let locales = localizations.compactMap { $0.string("locale") }.joined(separator: ", ")
    say(
        "Test Information (\(locales.isEmpty ? "no localization" : locales)): "
            + (gaps.isEmpty ? "complete" : "missing \(gaps.joined(separator: ", "))"))
    return groups
}

/// A JSON:API pointer to the build, as a relationship.
func buildRelationship(_ build: Resource) -> JSON { ["build": ["data": ["type": "builds", "id": build.id]]] }

/// Sets the build's What to Test in the app's primary language.
func setWhatsNew(_ whatsNew: String, build: Resource, locale: String, client: Client) async throws {
    let existing = try await client.list("/v1/builds/\(build.id)/betaBuildLocalizations")
        .first { $0.string("locale") == locale }
    let attributes: JSON = ["whatsNew": whatsNew]
    if let existing {
        let data: JSON = ["type": "betaBuildLocalizations", "id": existing.id, "attributes": attributes]
        try await client.send("PATCH", "/v1/betaBuildLocalizations/\(existing.id)", body: ["data": data])
    } else {
        let data: JSON = [
            "type": "betaBuildLocalizations",
            "attributes": attributes.merging(["locale": locale]) { old, _ in old },
            "relationships": buildRelationship(build),
        ]
        try await client.send("POST", "/v1/betaBuildLocalizations", body: ["data": data])
    }
}

func sendToFriends(build number: String, whatsNew: String, dryRun: Bool, client: Client) async throws {
    let app = try await appID(client)
    let groups = try await describeSetup(app: app.id, client: client)
    let friends = groups.first {
        $0.string("name") == friendsGroup && $0.attributes["isInternalGroup"] as? Bool != true
    }
    if friends == nil {
        let message = "no external beta group named \(friendsGroup)"
        guard dryRun else { throw Failure(message: message) }
        say("Would stop: \(message)")
    }

    let build = try await processedBuild(number, app: app.id, client: client)
    let locale = app.string("primaryLocale") ?? "en-US"
    if dryRun {
        say("Would set What to Test (\(locale)): \(whatsNew)")
    } else {
        try await setWhatsNew(whatsNew, build: build, locale: locale, client: client)
    }

    if let friends {
        if dryRun {
            say("Would add build \(number) to \(friendsGroup)")
        } else {
            let builds: JSON = ["data": [["type": "builds", "id": build.id]]]
            try await client.send("POST", "/v1/betaGroups/\(friends.id)/relationships/builds", body: builds)
            say("Added build \(number) to \(friendsGroup)")
        }
    }

    let state = try await client.one("/v1/builds/\(build.id)/buildBetaDetail")?.string("externalBuildState") ?? "?"
    say("External state: \(state)")
    guard state == "READY_FOR_BETA_SUBMISSION" else { return }
    if dryRun {
        say("Would submit build \(number) for beta review")
    } else {
        let submission: JSON = ["type": "betaAppReviewSubmissions", "relationships": buildRelationship(build)]
        try await client.send("POST", "/v1/betaAppReviewSubmissions", body: ["data": submission])
        say("Submitted build \(number) for beta review")
    }
}

func countCertificates(type: String?, client: Client) async throws {
    var query = ["limit": "200"]
    query["filter[certificateType]"] = type
    let json = try await client.send("GET", "/v1/certificates", query: query)
    let total = ((json["meta"] as? JSON)?["paging"] as? JSON)?["total"] as? Int
    say(String(total ?? (json["data"] as? [JSON])?.count ?? 0))
}

// MARK: - Main

var arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    say(usage)
    exit(arguments.isEmpty ? 64 : 0)
}
let command = arguments.removeFirst()

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

do {
    switch command {
    case "send-to-friends":
        guard let number = option("--build"), Int(number) != nil, let whatsNew = option("--whats-new"),
            !whatsNew.isEmpty
        else { fail("send-to-friends needs --build <n> and --whats-new <text>\n\(usage)") }
        try await sendToFriends(
            build: number, whatsNew: whatsNew, dryRun: arguments.contains("--dry-run"), client: makeClient())
    case "count-certificates":
        try await countCertificates(type: option("--type"), client: makeClient())
    default:
        fail("unknown command \(command)\n\(usage)")
    }
} catch let failure as Failure {
    fail(failure.message)
} catch {
    fail(error.localizedDescription)
}
