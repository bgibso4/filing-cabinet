import Foundation
import Testing

/// The review page's HTML, on canned entries.
struct ReviewPageTests {
    private static func entry(_ id: String, isPrivate: Bool = false, title: String? = "Alpha") -> ReviewPage.Entry {
        ReviewPage.Entry(
            item: EvaluationCase(
                id: id,
                files: ["\(id).jpg"],
                collection: isPrivate ? "" : "receipts",
                titles: [],
                searches: [],
                quality: "clean",
                collections: nil
            ),
            isPrivate: isPrivate,
            image: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            collectionID: "notes",
            title: title
        )
    }

    /// What Ben sees: the page without the JSON block that holds the titles for the script.
    private static func visible(_ html: String) -> String {
        guard let start = html.range(of: "<script type=\"application/json\""),
            let end = html.range(of: "</script>", range: start.upperBound..<html.endIndex)
        else { return html }
        return String(html[..<start.lowerBound] + html[end.upperBound...])
    }

    @Test func everyCaseAppears() {
        let html = ReviewPage.html(for: [Self.entry("one"), Self.entry("two"), Self.entry("three")])

        #expect(html.components(separatedBy: "<section class=\"case\"").count - 1 == 3)
        for id in ["one", "two", "three"] { #expect(html.contains("data-id=\"\(id)\"")) }
        #expect(html.contains("data:image/jpeg;base64,/9j/2Q=="))
        #expect(html.contains("Download answers"))
    }

    @Test func eachCaseShowsItsTitleToJudge() {
        let html = Self.visible(ReviewPage.html(for: [Self.entry("one", title: "Bayview Dental · Insurance Card")]))

        #expect(html.contains("<span class=\"text\">Bayview Dental · Insurance Card</span>"))
        #expect(html.components(separatedBy: "data-verdict=\"yes\"").count - 1 == 1)
    }

    @Test func privateCasesGetACollectionPicker() {
        let html = ReviewPage.html(for: [Self.entry("made-up"), Self.entry("mine", isPrivate: true)])

        #expect(html.components(separatedBy: "<select class=\"collection\">").count - 1 == 1)
        for id in ["wallet", "receipts", "notes", "documents", "throwaways"] {
            #expect(html.contains("<option value=\"\(id)\">"))
        }
    }

    @Test func noNetworkURLs() {
        #expect(!ReviewPage.html(for: [Self.entry("one"), Self.entry("two", isPrivate: true)]).contains("http"))
    }

    @Test func titlesAreEscaped() {
        let html = ReviewPage.html(for: [Self.entry("one", title: "A <b>&\" </script>")])

        #expect(Self.visible(html).contains("A &lt;b&gt;&amp;&quot; &lt;/script&gt;"))
        #expect(html.components(separatedBy: "</script>").count - 1 == 2)
    }

    @Test func aMissingTitleCannotBeJudged() {
        let html = ReviewPage.html(for: [Self.entry("one", title: nil)])

        #expect(html.contains("no suggestion"))
        #expect(!Self.visible(html).contains("data-verdict=\"yes\""))
    }

    @Test func theStorageKeyBelongsToTheRun() {
        let run = [Self.entry("one", title: "Alpha")]
        let other = [Self.entry("one", title: "Beta")]

        #expect(ReviewPage.storageKey(for: run) == ReviewPage.storageKey(for: run))
        #expect(ReviewPage.storageKey(for: run) != ReviewPage.storageKey(for: other))
        #expect(ReviewPage.html(for: run).contains("'\(ReviewPage.storageKey(for: run))'"))
    }
}
