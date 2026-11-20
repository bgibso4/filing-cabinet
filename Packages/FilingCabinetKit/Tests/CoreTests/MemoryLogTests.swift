import Foundation
import Testing

@testable import Core

private let megabyte: UInt64 = 1_048_576
/// 2026-11-19 09:14:02 UTC.
private let moment = Date(timeIntervalSince1970: 1_795_079_642)

private func temporaryFolder() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "MemoryLogTests-\(UUID().uuidString)")
}

@Test func aLineHasTheTimeStagePagesAndNumbers() {
    let reading = MemoryReading(now: 512 * megabyte, peak: 540 * megabyte, left: 2420 * megabyte)
    let line = MemoryLog.line(.cameraFinished, pages: 20, reading: reading, at: moment)
    #expect(line == "2026-11-19T09:14:02Z  camera finished  pages 20  now 512 MB  peak 540 MB  left 2420 MB")
}

@Test func aLineWithoutPagesOrLeftLeavesThemOut() {
    let reading = MemoryReading(now: 41 * megabyte, peak: 44 * megabyte, left: nil)
    let line = MemoryLog.line(.appOpened, pages: nil, reading: reading, at: moment)
    #expect(line == "2026-11-19T09:14:02Z  app opened  now 41 MB  peak 44 MB")
}

@Test func megabytesAreRoundedToTheNearest() {
    let reading = MemoryReading(now: 1_572_864, peak: 524_287, left: nil)
    let line = MemoryLog.line(.saved, pages: nil, reading: reading, at: moment)
    #expect(line == "2026-11-19T09:14:02Z  saved  now 2 MB  peak 0 MB")
}

@Test func aLineWithNoReadingSaysUnavailable() {
    let line = MemoryLog.line(.saved, pages: 3, reading: nil, at: moment)
    #expect(line == "2026-11-19T09:14:02Z  saved  pages 3  unavailable")
}

@Test func everyStageHasItsName() {
    #expect(
        [MemoryStage.appOpened, .cameraFinished, .reviewReady, .saved, .viewerClosed, .background].map(\.rawValue)
            == ["app opened", "camera finished", "review ready", "saved", "viewer closed", "app in background"])
}

@Test func appendingTwiceKeepsBothLines() throws {
    let file = temporaryFolder().appending(path: MemoryLog.fileName)
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }  // Best effort: a temp folder.
    try MemoryLog.append("first", to: file)
    try MemoryLog.append("second", to: file)
    #expect(try String(contentsOf: file, encoding: .utf8) == "first\nsecond\n")
}

@Test func appendingCreatesTheFolder() throws {
    let folder = temporaryFolder().appending(path: "deeper")
    // Best effort: a temp folder.
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    #expect(!FileManager.default.fileExists(atPath: folder.path))
    try MemoryLog.append("only", to: folder.appending(path: MemoryLog.fileName))
    #expect(try String(contentsOf: folder.appending(path: MemoryLog.fileName), encoding: .utf8) == "only\n")
}

@Test func appendingToAnUnwritablePlaceThrows() throws {
    let folder = temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }  // Best effort: a temp folder.
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    #expect(throws: (any Error).self) { try MemoryLog.append("line", to: folder) }
}

@Test func linesAppendedAtOnceStayWhole() async throws {
    let file = temporaryFolder().appending(path: MemoryLog.fileName)
    defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }  // Best effort: a temp folder.
    let lines = (0..<50).map { "line \($0) " + String(repeating: "x", count: 200) }
    try await withThrowingTaskGroup(of: Void.self) { group in
        for line in lines {
            group.addTask { try MemoryLog.append(line, to: file) }
        }
        try await group.waitForAll()
    }
    let written = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").map(String.init)
    #expect(written.count == 50)
    #expect(Set(written) == Set(lines))
}
