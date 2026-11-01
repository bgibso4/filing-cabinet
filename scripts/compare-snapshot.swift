// Puts a snapshot reference and its design screen side by side, scaled to the same height.
// Usage: swift scripts/compare-snapshot.swift <design/screens stem> <snapshot png>
// Writes build/compare/<stem>.png (reference on the left, design on the right) and prints the path.
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: compare-snapshot.swift <design stem> <snapshot png>\n".utf8))
    exit(1)
}
let stem = arguments[1]
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func load(_ url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url),
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        FileHandle.standardError.write(Data("error: cannot read \(url.path)\n".utf8))
        exit(1)
    }
    return cgImage
}

let reference = load(URL(fileURLWithPath: arguments[2], relativeTo: root))
let design = load(root.appending(path: "design/screens/\(stem).png"))

let height = max(reference.height, design.height)
let gap = 24
func scaledWidth(_ image: CGImage) -> Int { image.width * height / image.height }
let width = scaledWidth(reference) + gap + scaledWidth(design)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard let colorSpace,
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )
else {
    FileHandle.standardError.write(Data("error: cannot create a drawing context\n".utf8))
    exit(1)
}
context.setFillColor(CGColor(gray: 0.5, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.interpolationQuality = .high
context.draw(reference, in: CGRect(x: 0, y: 0, width: scaledWidth(reference), height: height))
context.draw(design, in: CGRect(x: scaledWidth(reference) + gap, y: 0, width: scaledWidth(design), height: height))

let output = root.appending(path: "build/compare/\(stem).png")
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let result = context.makeImage(),
    let png = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("error: cannot encode the comparison\n".utf8))
    exit(1)
}
try png.write(to: output)
FileHandle.standardOutput.write(Data((output.path + "\n").utf8))
