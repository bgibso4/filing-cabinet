import Core
import CoreGraphics
import Foundation
import Synchronization
import TestSupport
import Testing

@testable import Understanding

/// Builds the concrete reader for a kind with a hook that runs right before Vision does.
private func reader(_ kind: ReaderKind, onPerform: @escaping @Sendable () -> Void = {}) -> any TextReader {
    switch kind {
    case .text: TextRecognitionReader(onPerform: onPerform)
    case .documents: DocumentRecognitionReader(onPerform: onPerform)
    }
}

// Vision's first call loads its models cold (tens of seconds on a Mac); warm reads take well under a second.
@Suite(.timeLimit(.minutes(2)))
struct ReaderTests {
    @Test(arguments: ReaderKind.allCases)
    func readsTheBigLineOfASyntheticReceipt(kind: ReaderKind) async throws {
        let text = try await reader(kind).read(SyntheticPages.receipt())

        let line = try #require(text.lines.first { $0.text.uppercased().contains("CITY PHARMACY") })
        #expect(line.box.minY < 0.3)
    }

    @Test(arguments: ReaderKind.allCases)
    func blankPageReadsNoLines(kind: ReaderKind) async throws {
        let text = try await reader(kind).read(SyntheticPages.blank())

        #expect(text.lines.isEmpty)
    }

    @MainActor
    @Test(arguments: ReaderKind.allCases)
    func readingRunsOffTheMainThread(kind: ReaderKind) async throws {
        let ranOnMain = Mutex<[Bool]>([])

        _ = try await reader(kind) { ranOnMain.withLock { $0.append(Thread.isMainThread) } }
            .read(SyntheticPages.receipt())

        #expect(ranOnMain.withLock { $0 } == [false])
    }

    @Test(arguments: ReaderKind.allCases)
    func makeReaderGivesTheMatchingReader(kind: ReaderKind) {
        let made = kind.makeReader()
        switch kind {
        case .text: #expect(made is TextRecognitionReader)
        case .documents: #expect(made is DocumentRecognitionReader)
        }
    }
}
