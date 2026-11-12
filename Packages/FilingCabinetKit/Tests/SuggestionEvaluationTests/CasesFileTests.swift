import Core
import Foundation
import Testing

/// The made-up test set (`scripts/make-eval-scans.swift`) that Plan 5's evaluation runs on.
struct CasesFileTests {
    struct Case: Decodable {
        let id: String
        let files: [String]
        let collection: String
        let titles: [String]
        let searches: [String]
        let quality: String
        let collections: [String]?
    }

    private static let fixtures =
        Bundle.module.url(forResource: "Fixtures", withExtension: nil) ?? URL(filePath: "/missing")

    private static func load() throws -> [Case] {
        try JSONDecoder().decode([Case].self, from: Data(contentsOf: fixtures.appendingPathComponent("cases.json")))
    }

    @Test func everyCollectionHasFifteen() throws {
        let cases = try Self.load()
        for collection in BuiltInCollection.allCases {
            let mine = cases.filter { $0.collection == collection.rawValue }
            #expect(mine.count >= 15, "\(collection.rawValue) has \(mine.count) cases")
            #expect(
                mine.filter { $0.quality == "low" }.count >= 2, "\(collection.rawValue) has too few low-quality cases")
        }
    }

    @Test func everyCaseIsWellFormed() throws {
        let cases = try Self.load()
        #expect(Set(cases.map(\.id)).count == cases.count, "case ids are unique")
        for item in cases {
            #expect(!item.titles.isEmpty, "\(item.id) has no acceptable title")
            #expect(item.searches.count >= 2, "\(item.id) has fewer than two searches")
            #expect(["clean", "low"].contains(item.quality), "\(item.id) has quality \(item.quality)")
            for file in item.files {
                let path = Self.fixtures.appendingPathComponent("scans/\(file)").path
                #expect(FileManager.default.fileExists(atPath: path), "\(item.id): missing \(file)")
            }
        }
    }

    @Test func customCasesNameTheirCollection() throws {
        let custom = try Self.load().filter { $0.collections != nil }
        #expect(custom.count >= 5)
        for item in custom {
            #expect(item.collections?.contains(item.collection) == true, "\(item.id) is filed outside its own list")
        }
    }
}
