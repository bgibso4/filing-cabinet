import Foundation
import Testing

/// The title check and the case files, on canned cases.
struct EvaluationCaseTests {
    private static func item(titles: [String]) -> EvaluationCase {
        EvaluationCase(
            id: "a",
            files: ["a.jpg"],
            collection: "documents",
            titles: titles,
            searches: [],
            quality: "clean",
            collections: nil
        )
    }

    @Test func rightOnlyWhenWholeTitleMatches() {
        let item = Self.item(titles: ["InBody Report"])

        #expect(!item.isRightTitle("InBody Report · Body Composition Analysis"))
        #expect(item.isRightTitle("inbody  report"))
        #expect(!item.isRightTitle(nil))
    }

    @Test func punctuationIsIgnored() {
        #expect(Self.item(titles: ["Driver's License"]).isRightTitle("Drivers License"))
        #expect(Self.item(titles: ["W-2"]).isRightTitle("W2"))
    }

    @Test func noTitlesIsUnjudged() {
        #expect(!Self.item(titles: []).isJudged)
        #expect(Self.item(titles: ["X"]).isJudged)
    }

    @Test func loadsACasesFileFromAnyFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "eval-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }  // best effort: it is a temporary folder
        let json =
            #"[{"id":"mine","files":["m.jpg"]},{"id":"judged","files":["j.jpg"],"titles":["T"],"collection":"notes"}]"#
        try json.write(to: folder.appending(path: "cases.json"), atomically: true, encoding: .utf8)

        let cases = try EvaluationCase.loadAll(from: folder)

        #expect(cases.map(\.id) == ["mine", "judged"])
        #expect(cases.map(\.isJudged) == [false, true])
    }
}
