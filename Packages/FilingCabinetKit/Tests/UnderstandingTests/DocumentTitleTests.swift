import TestSupport
import Testing

@testable import Understanding

@Suite(.timeLimit(.minutes(2)))
struct DocumentTitleTests {
    @Test func blankPageHasNoTitle() async {
        #expect(await DocumentRecognitionReader().documentTitle(SyntheticPages.blank()) == nil)
    }

    @Test func receiptTitleIsTheBigLine() async {
        let title = await DocumentRecognitionReader().documentTitle(SyntheticPages.receipt())

        #expect(title?.uppercased().contains("CITY PHARMACY") == true, "title was \(String(describing: title))")
    }
}
