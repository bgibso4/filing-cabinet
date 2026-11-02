// Reads design/tokens.json and writes everything the app derives from it:
//   Packages/FilingCabinetKit/Sources/Screens/DesignSystem/Generated/Tokens.swift
//   Packages/FilingCabinetKit/Sources/Screens/Resources/Tokens.xcassets  (colours, collection symbols)
//   App/Assets.xcassets/bg-grouped.colorset  (the launch screen reads this one from the app bundle)
// Output is deterministic: running it twice leaves no diff. Run it with `make generate`.

import Foundation

struct ColorToken {
    let name: String
    let light: String
    let dark: String
}

struct TypeStyle {
    let name: String
    let size: Int
    let weight: Int
    let serif: Bool
    let tracking: Double?
}

enum GeneratorError: Error {
    case malformed(String)
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let screens = root.appending(path: "Packages/FilingCabinetKit/Sources/Screens")
let tokensAssets = screens.appending(path: "Resources/Tokens.xcassets")
let appAssets = root.appending(path: "App/Assets.xcassets")
let launchColor = "bg-grouped"

// MARK: Reading

func dictionary(_ value: Any?, _ what: String) throws -> [String: Any] {
    guard let result = value as? [String: Any] else { throw GeneratorError.malformed(what) }
    return result
}

func list(_ value: Any?, _ what: String) throws -> [[String: Any]] {
    guard let result = value as? [[String: Any]] else { throw GeneratorError.malformed(what) }
    return result
}

func string(_ value: Any?, _ what: String) throws -> String {
    guard let result = value as? String else { throw GeneratorError.malformed(what) }
    return result
}

func points(_ value: Any?, _ what: String) throws -> Int {
    guard let text = value as? String, let number = Int(text.replacingOccurrences(of: "px", with: "")) else {
        throw GeneratorError.malformed(what)
    }
    return number
}

func camelCased(_ name: String) -> String {
    let parts = name.split(separator: "-").map(String.init)
    return (parts.first ?? "") + parts.dropFirst().map(\.capitalized).joined()
}

let source = try dictionary(
    JSONSerialization.jsonObject(with: Data(contentsOf: root.appending(path: "design/tokens.json"))),
    "tokens.json")

let colors = try list(dictionary(source["color"], "color")["tokens"], "color.tokens").map { entry in
    let value = try dictionary(entry["value"], "color value")
    return ColorToken(
        name: try string(entry["name"], "color name"),
        light: try string(value["light"], "light"),
        dark: try string(value["dark"], "dark"))
}.sorted { $0.name < $1.name }

let spacing = try list(dictionary(source["spacing"], "spacing")["tokens"], "spacing.tokens").map {
    (name: try string($0["name"], "spacing name"), value: try points($0["value"], "spacing value"))
}

let radii = try list(dictionary(source["radius"], "radius")["tokens"], "radius.tokens").map {
    (name: try string($0["name"], "radius name"), value: try points($0["value"], "radius value"))
}

func tracking(_ value: Any?) throws -> Double? {
    guard let value else { return nil }
    guard let text = value as? String, let number = Double(text.replacingOccurrences(of: "px", with: "")) else {
        throw GeneratorError.malformed("letterSpacing")
    }
    return number
}

/// Keys of a type style the generator honours (or knowingly leaves to the system: line height follows the text style).
let knownStyleKeys: Set<String> = [
    "name", "fontSize", "lineHeight", "fontWeight", "letterSpacing", "sample", "usage",
]

let styles = try list(dictionary(source["type"], "type")["groups"], "type.groups").flatMap { group in
    let serif = try string(group["family"], "family") == "serif"
    return try list(group["styles"], "styles").map {
        let unknown = Set($0.keys).subtracting(knownStyleKeys)
        guard unknown.isEmpty else { throw GeneratorError.malformed("unsupported type style keys \(unknown.sorted())") }
        return TypeStyle(
            name: try string($0["name"], "style name"),
            size: try points($0["fontSize"], "fontSize"),
            weight: $0["fontWeight"] as? Int ?? 400,
            serif: serif,
            tracking: try tracking($0["letterSpacing"]))
    }
}

let symbols = try dictionary(
    dictionary(source["icons"], "icons")["collection-symbols"], "collection-symbols"
).filter { $0.key != "note" }.map { (name: $0.key, path: try string($0.value, $0.key)) }
    .sorted { $0.name < $1.name }

// MARK: Writing

func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}

func json(_ object: Any) throws -> String {
    let data = try JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    guard let text = String(data: data, encoding: .utf8) else { throw GeneratorError.malformed("utf8") }
    return text + "\n"
}

let catalogInfo: [String: Any] = ["author": "xcode", "version": 1]

func components(_ hex: String) -> [String: String] {
    let digits = hex.dropFirst()
    func channel(_ offset: Int) -> String {
        let start = digits.index(digits.startIndex, offsetBy: offset)
        return "0x" + digits[start..<digits.index(start, offsetBy: 2)].uppercased()
    }
    return ["alpha": "1.000", "blue": channel(4), "green": channel(2), "red": channel(0)]
}

func colorSet(_ token: ColorToken) throws -> String {
    func entry(_ hex: String, dark: Bool) -> [String: Any] {
        var result: [String: Any] = [
            "color": ["color-space": "srgb", "components": components(hex)],
            "idiom": "universal",
        ]
        if dark { result["appearances"] = [["appearance": "luminosity", "value": "dark"]] }
        return result
    }
    return try json(["colors": [entry(token.light, dark: false), entry(token.dark, dark: true)], "info": catalogInfo])
}

func symbolSVG(_ path: String) -> String {
    """
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      <path d="\(path)" stroke="black" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    </svg>

    """
}

func symbolSet(_ name: String) throws -> String {
    try json([
        "images": [["filename": "\(name).svg", "idiom": "universal"]],
        "info": catalogInfo,
        "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"],
    ])
}

func writeCatalog() throws {
    try? FileManager.default.removeItem(at: tokensAssets)  // Regenerated from scratch so removed tokens leave no stale sets.
    try write(json(["info": catalogInfo]), to: tokensAssets.appending(path: "Contents.json"))
    for token in colors {
        try write(
            colorSet(token), to: tokensAssets.appending(path: "\(token.name).colorset/Contents.json"))
    }
    for symbol in symbols {
        let set = tokensAssets.appending(path: "symbol-\(symbol.name).imageset")
        try write(symbolSet("symbol-\(symbol.name)"), to: set.appending(path: "Contents.json"))
        try write(symbolSVG(symbol.path), to: set.appending(path: "symbol-\(symbol.name).svg"))
    }
    guard let launch = colors.first(where: { $0.name == launchColor }) else {
        throw GeneratorError.malformed("missing \(launchColor)")
    }
    try write(colorSet(launch), to: appAssets.appending(path: "\(launchColor).colorset/Contents.json"))
}

let textStyles = [
    "large-title": "largeTitle", "title-1": "title", "title-2": "title2", "headline": "headline",
    "body": "body", "subheadline": "subheadline", "footnote": "footnote", "caption": "caption",
]

/// Each Apple text style's size at the default Dynamic Type setting. A token size that differs cannot be honoured
/// by a text style, so the generator fails rather than silently ignoring the change.
let defaultSizes = [
    "largeTitle": 34, "title": 28, "title2": 22, "headline": 17, "body": 17, "subheadline": 15, "footnote": 13,
    "caption": 12,
]

func weightName(_ weight: Int) throws -> String {
    switch weight {
    case 400: "regular"
    case 600: "semibold"
    case 700: "bold"
    default: throw GeneratorError.malformed("font weight \(weight)")
    }
}

func colorSection() -> String {
    var out = "    enum Color {\n"
    for token in colors {
        out += "        static let \(camelCased(token.name)) = SwiftUI.Color(\"\(token.name)\", bundle: .module)\n"
    }
    out += """

            /// The round badge behind a collection's white symbol.
            static func badge(_ collection: BuiltInCollection) -> SwiftUI.Color {
                SwiftUI.Color("badge-\\(collection.rawValue)", bundle: .module)
            }
        }

    """
    return out
}

func spacingAndRadiusSection() -> String {
    var out = "    enum Spacing {\n"
    for token in spacing where token.name.hasPrefix("space-") {
        out += "        static let s\(token.name.dropFirst(6)): CGFloat = \(token.value)\n"
    }
    for token in spacing where !token.name.hasPrefix("space-") {
        out += "        static let \(camelCased(token.name)): CGFloat = \(token.value)\n"
    }
    out += "    }\n\n    enum Radius {\n"
    for token in radii {
        let name = camelCased(token.name.replacingOccurrences(of: "radius-", with: ""))
        out += "        static let \(name): CGFloat = \(token.value)\n"
    }
    return out + "    }\n"
}

func typographySection() throws -> String {
    var out = """
        /// Text styles scale with Dynamic Type; each matches the design size at the default setting.
        enum Typography {

    """
    for style in styles {
        guard let textStyle = textStyles[style.name] else { throw GeneratorError.malformed(style.name) }
        guard defaultSizes[textStyle] == style.size else {
            throw GeneratorError.malformed("\(style.name) is \(style.size) pt but .\(textStyle) is \(defaultSizes[textStyle] ?? 0) pt")
        }
        let design = style.serif ? ".serif" : ".default"
        let digits = style.serif ? "" : ".monospacedDigit()"
        let weight = try weightName(style.weight)
        out += "        /// \(style.size) pt\n"
        out += "        static let \(camelCased(style.name)) = Font.system(.\(textStyle), design: \(design), weight: .\(weight))\(digits)\n"
    }
    for style in styles {
        if let tracking = style.tracking {
            out += "\n        /// Letter spacing in points for `\(camelCased(style.name))`.\n"
            out += "        static let \(camelCased(style.name))Tracking: CGFloat = \(tracking)\n"
        }
    }
    return out + "    }\n"
}

func tokensSwift() throws -> String {
    let header = """
        // GENERATED — run make generate. Source: design/tokens.json. Do not edit.

        import Core
        import SwiftUI

        enum Tokens {
            /// The Screens resource bundle, for tests that look assets up by name.
            package static let bundle = Bundle.module


        """
    let symbol = """

            /// The template symbol for a collection, drawn white on its badge.
            static func symbol(_ collection: BuiltInCollection) -> Image {
                Image("symbol-\\(collection.rawValue)", bundle: .module).renderingMode(.template)
            }
        }

        """
    return header + colorSection() + "\n" + spacingAndRadiusSection() + "\n" + (try typographySection()) + symbol
}

try writeCatalog()
try write(tokensSwift(), to: screens.appending(path: "DesignSystem/Generated/Tokens.swift"))
