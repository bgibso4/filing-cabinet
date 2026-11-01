#if canImport(UIKit)
    import Core
    import Foundation
    import Testing
    import UIKit

    @testable import Screens

    // The generated assets live in Screens' bundle; `.module` in this file would name the test bundle.
    private let screensBundle = Tokens.bundle

    /// Reads `color.tokens[].name` from design/tokens.json, five directories above this file.
    private func tokenNames() throws -> [String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "design/tokens.json"))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let color = try #require(json["color"] as? [String: Any])
        let tokens = try #require(color["tokens"] as? [[String: Any]])
        return tokens.compactMap { $0["name"] as? String }
    }

    @Test func everyColourTokenResolves() throws {
        let names = try tokenNames()
        #expect(!names.isEmpty)
        for name in names {
            #expect(UIColor(named: name, in: screensBundle, compatibleWith: nil) != nil, "\(name)")
        }
    }

    @Test(arguments: BuiltInCollection.allCases)
    func everyCollectionHasASymbol(_ collection: BuiltInCollection) {
        #expect(UIImage(named: "symbol-\(collection.rawValue)", in: screensBundle, with: nil) != nil)
    }
#endif
