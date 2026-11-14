import Core
import CoreGraphics
import Foundation
import ImageIO
import Library
import Synchronization
import TestSupport
import Testing

private func longEdge(_ image: CGImage) -> Int { max(image.width, image.height) }

@Test func cachedJpegIsReadWithoutTheOriginal() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem())
        .write([SyntheticPages.receipt()], for: id)
    try FileManager.default.removeItem(at: location.originals(for: id))
    let loader = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())

    let image = try #require(await loader.thumbnail(for: id, page: 0))

    #expect(longEdge(image) <= 400)
}

@Test func missingThumbnailIsRebuiltAtThumbnailSize() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let big = SyntheticPages.page(lines: [("BIG", 200)], size: CGSize(width: 3000, height: 4000))
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write([big], for: id)
    let cacheFile = location.thumbnails(for: id).appending(path: "page-1.jpg")
    try FileManager.default.removeItem(at: location.thumbnails(for: id))
    let loader = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())

    let image = try #require(await loader.thumbnail(for: id, page: 0))

    #expect(longEdge(image) <= 400)
    #expect(FileManager.default.fileExists(atPath: cacheFile.path(percentEncoded: false)))
    let rewritten = try #require(CGImageSourceCreateWithURL(cacheFile as CFURL, nil))
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(rewritten, 0, nil) as? [CFString: Any])
    #expect((properties[kCGImagePropertyPixelHeight] as? Int ?? .max) <= 400)
}

@Test func missingOriginalReturnsNil() async {
    let loader = ThumbnailLoader(location: temporaryLocation(), fileSystem: LocalFileSystem())
    #expect(await loader.thumbnail(for: ScanID(), page: 0) == nil)
}

@Test func memoryCacheAnswersSynchronouslyAfterALoad() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem())
        .write([SyntheticPages.receipt()], for: id)
    let loader: any ThumbnailProviding = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())
    #expect(loader.cachedThumbnail(for: id, page: 0) == nil)

    _ = await loader.thumbnail(for: id, page: 0)

    #expect(loader.cachedThumbnail(for: id, page: 0) != nil)
}

@Test func pageLoaderDecodesFullSizeAndKeepsThreeRecentPages() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let pages = (0..<4).map { _ in SyntheticPages.page(lines: [], size: CGSize(width: 1000, height: 1400)) }
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write(pages, for: id)
    let loader: any PageImageProviding = PageImageLoader(location: location, fileSystem: LocalFileSystem())

    for index in 0..<4 { #expect(await loader.page(for: id, index: index)?.height == 1400) }

    #expect(loader.cachedPage(for: id, index: 0) == nil)
    #expect(loader.cachedPage(for: id, index: 3) != nil)
    #expect(await loader.page(for: id, index: 9) == nil)
}

@Test func fakesServePreloadedImagesAndRecordRequests() async {
    let id = ScanID()
    let image = SyntheticPages.blank()
    let fakeThumbnails = FakeThumbnails(images: [id: [0: image]])
    let fakePages = FakePageImages(images: [id: [1: image]])
    let thumbnails: any ThumbnailProviding = fakeThumbnails
    let pages: any PageImageProviding = fakePages

    #expect(thumbnails.cachedThumbnail(for: id, page: 0) != nil)
    #expect(await thumbnails.thumbnail(for: id, page: 5) == nil)
    #expect(pages.cachedPage(for: id, index: 1) != nil)
    #expect(await pages.page(for: id, index: 0) == nil)

    #expect(fakeThumbnails.requests.map(\.kind) == [.cached, .loaded])
    #expect(fakeThumbnails.requests.map(\.page) == [0, 5])
    #expect(fakeThumbnails.loadedRequests.map(\.page) == [5])
    #expect(fakeThumbnails.loadedIDs == [id])
    #expect(fakePages.requests.map(\.kind) == [.cached, .loaded])
    #expect(fakePages.requests.map(\.page) == [1, 0])
    #expect(fakePages.loadedRequests.map(\.page) == [0])
    #expect(fakePages.loadedIDs == [id])
}

@Test func leastRecentlyUsedPageIsEvictedAndReadsPromote() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let pages = (0..<4).map { _ in SyntheticPages.page(lines: [], size: CGSize(width: 200, height: 300)) }
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write(pages, for: id)
    let loader: any PageImageProviding = PageImageLoader(location: location, fileSystem: LocalFileSystem())

    for index in 0...2 { _ = await loader.page(for: id, index: index) }
    _ = loader.cachedPage(for: id, index: 0)
    _ = await loader.page(for: id, index: 3)

    #expect(loader.cachedPage(for: id, index: 1) == nil)
    #expect(loader.cachedPage(for: id, index: 0) != nil)
}

@Test func thumbnailMemoryCacheIsBoundedAt200() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let pages = (0..<201).map { _ in SyntheticPages.page(lines: [], size: CGSize(width: 20, height: 30)) }
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write(pages, for: id)
    let loader: any ThumbnailProviding = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())

    for index in 0..<201 { _ = await loader.thumbnail(for: id, page: index) }

    #expect(loader.cachedThumbnail(for: id, page: 0) == nil)
    #expect(loader.cachedThumbnail(for: id, page: 1) != nil)
    #expect(loader.cachedThumbnail(for: id, page: 200) != nil)
}

@Test func cancelledPageLoadDecodesNothing() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem())
        .write([SyntheticPages.receipt()], for: id)
    let loader = PageImageLoader(location: location, fileSystem: LocalFileSystem())

    // Cancelled before it calls the loader, so the loader sees a cancelled task.
    let load = Task {
        while !Task.isCancelled { await Task.yield() }
        return await loader.page(for: id, index: 0)
    }
    load.cancel()

    #expect(await load.value == nil)
    #expect(loader.cachedPage(for: id, index: 0) == nil)
}

/// A local file system that counts the existence checks of each file: a loader checks a file once per decode.
private final class CountingFileSystem: FileSystem {
    private let local = LocalFileSystem()
    private let checks = Mutex<[URL: Int]>([:])

    func checks(of url: URL) -> Int { checks.withLock { $0[url, default: 0] } }

    func createDirectory(at url: URL) throws { try local.createDirectory(at: url) }
    func write(_ data: Data, to url: URL) throws { try local.write(data, to: url) }
    func removeItem(at url: URL) throws { try local.removeItem(at: url) }
    func contentsOfDirectory(at url: URL) throws -> [URL] { try local.contentsOfDirectory(at: url) }

    func fileExists(at url: URL) -> Bool {
        checks.withLock { $0[url, default: 0] += 1 }
        return local.fileExists(at: url)
    }
}

/// Regression: concurrent loads of the same page used to decode it once per caller, blocking that many cooperative
/// threads, which deadlocked the viewer on CI's few-core virtual Mac. Now each page is decoded once.
@Test func concurrentPageLoadsDecodeEachPageOnce() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let pages = (0..<2).map { _ in SyntheticPages.page(lines: [], size: CGSize(width: 1000, height: 1400)) }
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write(pages, for: id)
    let files = CountingFileSystem()
    let loader = PageImageLoader(location: location, fileSystem: files)

    let heights = await withTaskGroup(of: Int?.self) { group in
        for _ in 0..<6 {
            for index in 0..<2 { group.addTask { await loader.page(for: id, index: index)?.height } }
        }
        return await group.reduce(into: [Int?]()) { $0.append($1) }
    }

    #expect(heights.count == 12)
    #expect(heights.allSatisfy { $0 == 1400 })
    for page in 1...2 {
        #expect(files.checks(of: location.originals(for: id).appending(path: "page-\(page).heic")) == 1)
    }
}

@Test func concurrentThumbnailLoadsDecodeEachPageOnce() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    let pages = (0..<2).map { _ in SyntheticPages.page(lines: [], size: CGSize(width: 200, height: 300)) }
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem()).write(pages, for: id)
    let files = CountingFileSystem()
    let loader = ThumbnailLoader(location: location, fileSystem: files)

    let loaded = await withTaskGroup(of: Bool.self) { group in
        for _ in 0..<6 {
            for index in 0..<2 { group.addTask { await loader.thumbnail(for: id, page: index) != nil } }
        }
        return await group.reduce(into: [Bool]()) { $0.append($1) }
    }

    #expect(loaded.count == 12)
    #expect(loaded.allSatisfy { $0 })
    for page in 1...2 {
        #expect(files.checks(of: location.thumbnails(for: id).appending(path: "page-\(page).jpg")) == 1)
    }
}

@Test func firstPageJPEGIsTheCachedFileAsStored() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem())
        .write([SyntheticPages.receipt(), SyntheticPages.receipt()], for: id)
    let stored = try Data(contentsOf: location.thumbnails(for: id).appending(path: "page-1.jpg"))
    let loader = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())

    #expect(await loader.firstPageJPEG(for: id) == stored)
}

@Test func firstPageJPEGIsNilWhenNotCached() async throws {
    let location = temporaryLocation()
    let id = ScanID()
    _ = try await PageFileStore(location: location, fileSystem: LocalFileSystem())
        .write([SyntheticPages.receipt()], for: id)
    try FileManager.default.removeItem(at: location.thumbnails(for: id))
    let loader = ThumbnailLoader(location: location, fileSystem: LocalFileSystem())

    // Never rebuilt from the original: Spotlight only takes what is cached.
    #expect(await loader.firstPageJPEG(for: id) == nil)
}
