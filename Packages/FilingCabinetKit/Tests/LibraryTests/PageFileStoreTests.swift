import Core
import CoreGraphics
import Foundation
import ImageIO
import Library
import TestSupport
import Testing

/// Writes like the real file system, but fails the given original with ENOSPC.
private struct FailingFileSystem: FileSystem {
    let failingFileName: String
    let real = LocalFileSystem()

    func createDirectory(at url: URL) throws { try real.createDirectory(at: url) }

    func write(_ data: Data, to url: URL) throws {
        if url.lastPathComponent == failingFileName { throw POSIXError(.ENOSPC) }
        try real.write(data, to: url)
    }

    func removeItem(at url: URL) throws { try real.removeItem(at: url) }
    func contentsOfDirectory(at url: URL) throws -> [URL] { try real.contentsOfDirectory(at: url) }
    func fileExists(at url: URL) -> Bool { real.fileExists(at: url) }
}

private func pixelSize(of url: URL) -> (width: Int, height: Int)? {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (width, height)
}

@Test func writesHeicOriginalsAndSmallThumbnails() async throws {
    let location = temporaryLocation()
    let store = PageFileStore(location: location, fileSystem: LocalFileSystem())
    let id = ScanID()
    let pages = [SyntheticPages.receipt(), SyntheticPages.blank(), SyntheticPages.receipt()]

    let names = try await store.write(pages, for: id)

    #expect(names == ["page-1.heic", "page-2.heic", "page-3.heic"])
    for (index, name) in names.enumerated() {
        let original = location.originals(for: id).appending(path: name)
        let decoded = CGImageSourceCreateWithURL(original as CFURL, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, nil)
        }
        #expect(decoded != nil, "\(name) should decode")
        let thumbnail = location.thumbnails(for: id).appending(path: "page-\(index + 1).jpg")
        let size = try #require(pixelSize(of: thumbnail))
        #expect(max(size.width, size.height) <= 400)
    }
    #expect(await store.storedScanIDs() == [id])
}

@Test func heicEncodingIsAvailable() throws {
    let types = try #require(CGImageDestinationCopyTypeIdentifiers() as? [String])
    #expect(types.contains("public.heic"))
}

@Test func failedThirdPageLeavesNoFiles() async {
    let location = temporaryLocation()
    let store = PageFileStore(location: location, fileSystem: FailingFileSystem(failingFileName: "page-3.heic"))
    let id = ScanID()
    let pages = [SyntheticPages.blank(), SyntheticPages.blank(), SyntheticPages.blank()]

    await #expect(throws: LibraryError.diskFull) {
        _ = try await store.write(pages, for: id)
    }

    #expect(!FileManager.default.fileExists(atPath: location.originals(for: id).path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: location.thumbnails(for: id).path(percentEncoded: false)))
}

@Test func removeDeletesBothFolders() async throws {
    let location = temporaryLocation()
    let store = PageFileStore(location: location, fileSystem: LocalFileSystem())
    let id = ScanID()
    _ = try await store.write([SyntheticPages.blank()], for: id)

    await store.remove(id)

    #expect(!FileManager.default.fileExists(atPath: location.originals(for: id).path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: location.thumbnails(for: id).path(percentEncoded: false)))
    #expect(await store.storedScanIDs().isEmpty)
}

@Test func locationPathsFollowTheLayout() {
    let location = LibraryLocation(root: URL(filePath: "/r/"), caches: URL(filePath: "/c/"))
    let id = ScanID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID())

    #expect(location.storeURL.path(percentEncoded: false) == "/r/Library.store")
    #expect(
        location.originals(for: id).path(percentEncoded: false) == "/r/Originals/00000000-0000-0000-0000-000000000001/")
    #expect(
        location.thumbnails(for: id).path(percentEncoded: false)
            == "/c/Thumbnails/00000000-0000-0000-0000-000000000001/")
}

@Test func standardLocationIsApplicationSupportAndCaches() throws {
    let location = try LibraryLocation.standard()

    #expect(location.root.lastPathComponent == "Application Support")
    #expect(location.caches.lastPathComponent == "Caches")
}
