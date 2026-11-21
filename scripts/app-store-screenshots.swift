// The App Store screenshots (#115), from the snapshot tests' own reference images. Everything shown is made up.
//
//   swift scripts/app-store-screenshots.swift frame <output folder>   six captioned 6.9-inch screenshots and a contact sheet
//   swift scripts/app-store-screenshots.swift receipt <file.jpg>      the made-up restaurant receipt shot 1 reviews
//   swift scripts/app-store-screenshots.swift header <file.png>       the product page header: made-up scans, fanned out
//
// `frame` reads SnapshotTests/__Snapshots__, so re-record the snapshots first when a screen has changed.

// A dev script that draws with AppKit and CoreGraphics: their calls return optionals that can't fail here, and
// swift-format wraps their long argument lists in a way these rules reject. Scoped to this file.
// swiftlint:disable multiline_arguments force_unwrapping - dev script drawing with CoreGraphics

import AppKit
import CoreImage

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let arguments = CommandLine.arguments
guard arguments.count == 3, ["frame", "receipt", "header"].contains(arguments[1]) else {
    FileHandle.standardError.write(
        Data("usage: app-store-screenshots.swift frame <folder> | receipt <file.jpg> | header <file.png>\n".utf8))
    exit(2)
}
let target = URL(fileURLWithPath: arguments[2])

func colour(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

/// An opaque sRGB bitmap: App Store Connect refuses screenshots with an alpha channel.
func bitmap(_ size: CGSize, draw: (CGContext) -> Void) -> CGImage {
    guard
        let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("no bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(context)
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL, as type: String, quality: CGFloat = 1) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(
        destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(url.path)") }
}

func load(_ url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("missing \(url.path)")
    }
    return image
}

// MARK: The receipt

/// One printed row of the receipt, and how far below the row before it sits.
struct ReceiptRow {
    enum Kind {
        case centred(String)
        case pair(String, String)
        case rule
    }

    let drop: CGFloat
    let kind: Kind
    var size: CGFloat = 44
    var bold = false
    var faint = false
}

let receiptRows = [
    ReceiptRow(drop: 0, kind: .centred("TRATTORIA LUNA"), size: 76, bold: true),
    ReceiptRow(drop: 80, kind: .centred("14 Sample Lane · Anytown"), size: 34, faint: true),
    ReceiptRow(drop: 70, kind: .rule),
    ReceiptRow(drop: 90, kind: .pair("10/09/2026", "19:41"), faint: true),
    ReceiptRow(drop: 64, kind: .pair("Table 12", "Server: Jo"), faint: true),
    ReceiptRow(drop: 50, kind: .rule),
    ReceiptRow(drop: 100, kind: .pair("Bruschetta", "9.00")),
    ReceiptRow(drop: 74, kind: .pair("Linguine vongole", "22.00")),
    ReceiptRow(drop: 74, kind: .pair("Gnocchi", "18.50")),
    ReceiptRow(drop: 74, kind: .pair("House red x2", "16.00")),
    ReceiptRow(drop: 74, kind: .pair("Tiramisu", "8.50")),
    ReceiptRow(drop: 50, kind: .rule),
    ReceiptRow(drop: 90, kind: .pair("Subtotal", "74.00")),
    ReceiptRow(drop: 74, kind: .pair("Tip 20%", "14.80")),
    ReceiptRow(drop: 96, kind: .pair("TOTAL", "88.80"), size: 56, bold: true),
    ReceiptRow(drop: 84, kind: .pair("Card ending 4821", "88.80"), faint: true),
    ReceiptRow(drop: 60, kind: .rule),
    ReceiptRow(drop: 110, kind: .centred("Grazie · see you soon"), size: 40),
]

let receiptSize = CGSize(width: 1080, height: 1900)
let receiptMargin: CGFloat = 120
let receiptTop: CGFloat = 1650
/// Where the paper was folded, between two item rows.
let receiptFold: CGFloat = 1109

func draw(_ row: ReceiptRow, at baseline: CGFloat, in context: CGContext) {
    let faint = colour(0x77777d)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: row.bold ? "Menlo-Bold" : "Menlo-Regular", size: row.size)!,
        .foregroundColor: row.faint ? faint : colour(0x26262a),
    ]
    let right = receiptSize.width - receiptMargin
    switch row.kind {
    case .centred(let string):
        let text = NSAttributedString(string: string, attributes: attributes.merging([.kern: 2]) { $1 })
        text.draw(at: CGPoint(x: (receiptSize.width - text.size().width) / 2, y: baseline))
    case .pair(let leading, let trailing):
        NSAttributedString(string: leading, attributes: attributes).draw(at: CGPoint(x: receiptMargin, y: baseline))
        let text = NSAttributedString(string: trailing, attributes: attributes)
        text.draw(at: CGPoint(x: right - text.size().width, y: baseline))
    case .rule:
        context.setStrokeColor(faint.cgColor)
        context.setLineWidth(3)
        context.setLineDash(phase: 0, lengths: [14, 10])
        context.move(to: CGPoint(x: receiptMargin, y: baseline))
        context.addLine(to: CGPoint(x: right, y: baseline))
        context.strokePath()
    }
}

/// A restaurant receipt as a phone's document camera would give it: flat, a little grey, with a fold and paper grain.
func receipt() -> CGImage {
    let drawn = bitmap(receiptSize) { context in
        // Paper: lighter in the middle, as a page lit from above the phone is.
        let shades = [colour(0xdcdcd8).cgColor, colour(0xcacac6).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: nil, colors: shades, locations: [0, 1])!
        context.drawRadialGradient(
            gradient, startCenter: CGPoint(x: 540, y: 1150), startRadius: 0, endCenter: CGPoint(x: 540, y: 950),
            endRadius: 1500, options: [.drawsAfterEndLocation])
        var baseline = receiptTop
        for row in receiptRows {
            baseline -= row.drop
            draw(row, at: baseline, in: context)
        }
        // The fold: a soft dark line with a light one under it.
        for (offset, shade, alpha) in [(0.0, NSColor.black, 0.10), (-5.0, NSColor.white, 0.35)] {
            context.setStrokeColor(shade.withAlphaComponent(alpha).cgColor)
            context.setLineDash(phase: 0, lengths: [])
            context.setLineWidth(5)
            context.move(to: CGPoint(x: 0, y: receiptFold + offset))
            context.addLine(to: CGPoint(x: receiptSize.width, y: receiptFold + offset))
            context.strokePath()
        }
    }
    // Paper grain: a little noise, so the page doesn't read as a flat fill.
    let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
        .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 0.25])
        .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.06)])
    let page = CIImage(cgImage: drawn)
    let grained = noise.cropped(to: page.extent).composited(over: page)
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6]).cropped(to: page.extent)
    return CIContext().createCGImage(grained, from: page.extent)!
}

// MARK: The framed screenshots

struct Shot {
    let name: String
    /// Under SnapshotTests/__Snapshots__.
    let reference: String
    let caption: String
    let background: UInt32
    /// The whole screen fits on the canvas, for a screen whose point is at its bottom edge; the others run off it.
    var fits = false
}

/// The story (set B): the first three are what search results show. Colours are the collections' own (design/tokens.json).
let shots = [
    Shot(
        name: "1-files-itself", reference: "ReviewSnapshotTests/review_card_app_store.light.png",
        caption: "Scan it.\nIt files itself.", background: 0xc0533a, fits: true),
    Shot(
        name: "2-cleans-itself", reference: "GridSnapshotTests/grid_throwaways.light.png",
        caption: "Clutter clears\nitself out.", background: 0xb98a1f),
    Shot(
        name: "3-private", reference: "SettingsSnapshotTests/settings_lock_on.light.png",
        caption: "Private by design.\nNo account.", background: 0x1c1c1e),
    Shot(
        name: "4-home", reference: "HomeSnapshotTests/home_favorites.light.png",
        caption: "Everything\nin its place.", background: 0x3f6fa3),
    Shot(
        name: "5-search", reference: "SearchSnapshotTests/search_results.light.png", caption: "Find it by\nany word.",
        background: 0x7a5aa8),
    Shot(
        name: "6-keep", reference: "DetailsSnapshotTests/details_lease.light.png",
        caption: "Keep what\nmatters forever.", background: 0x4b8160, fits: true),
]

/// The 6.9-inch size.
let canvas = CGSize(width: 1320, height: 2868)
/// The empty status bar band at the top of a snapshot, in its own pixels.
let statusBand: CGFloat = 110
let screenTop: CGFloat = 760
let screenWidth: CGFloat = 1120
let screenRadius: CGFloat = 96
let bottomMargin: CGFloat = 70
let captionSize: CGFloat = 150

func framed(_ shot: Shot) -> CGImage {
    let reference = load(root.appending(path: "SnapshotTests/__Snapshots__/\(shot.reference)"))
    let screen = reference.cropping(
        to: CGRect(x: 0, y: statusBand, width: CGFloat(reference.width), height: CGFloat(reference.height) - statusBand)
    )!
    let scale =
        shot.fits
        ? (canvas.height - screenTop - bottomMargin) / CGFloat(screen.height) : screenWidth / CGFloat(screen.width)
    let width = CGFloat(screen.width) * scale
    let height = CGFloat(screen.height) * scale
    return bitmap(canvas) { context in
        colour(shot.background).setFill()
        CGRect(origin: .zero, size: canvas).fill()

        // The caption, in New York like the app's titles, centred in the band above the screen. The origin is bottom left.
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 0.95
        let serif = NSFont.systemFont(ofSize: captionSize, weight: .bold).fontDescriptor.withDesign(.serif)!
        let caption = NSAttributedString(
            string: shot.caption,
            attributes: [
                .font: NSFont(descriptor: serif, size: captionSize)!, .foregroundColor: NSColor.white,
                .paragraphStyle: style, .kern: -1.5,
            ])
        let room = CGSize(width: canvas.width - 120, height: 1000)
        let textHeight = caption.boundingRect(with: room, options: [.usesLineFragmentOrigin]).height
        let bandMiddle = canvas.height - (screenTop + 40) / 2
        caption.draw(
            with: CGRect(x: 60, y: bandMiddle - textHeight / 2, width: room.width, height: textHeight),
            options: [.usesLineFragmentOrigin])

        let frame = CGRect(
            x: (canvas.width - width) / 2, y: canvas.height - screenTop - height, width: width, height: height)
        context.addPath(
            CGPath(roundedRect: frame, cornerWidth: screenRadius, cornerHeight: screenRadius, transform: nil))
        context.clip()
        context.interpolationQuality = .high
        context.draw(screen, in: frame)
    }
}

// MARK: The product page header

/// A scan in the header's fan: where its centre sits across the canvas, how tall it is drawn and its tilt.
struct FannedScan {
    /// Under design/prototype/scans, or nil for the receipt this script draws.
    let sample: String?
    let centre: CGFloat
    let height: CGFloat
    let degrees: CGFloat
}

/// Apple's size for the header (21:9), and the middle band every device shows: keep the point of the picture in it.
let headerSize = CGSize(width: 3840, height: 1646)
let headerSafeArea = CGRect(x: 1097, y: 493, width: 1646, height: 661)

/// Back to front. The five in the middle sit inside the safe area; the outer ones only fill wider crops.
let headerFan = [
    FannedScan(sample: "scan-registration", centre: 330, height: 330, degrees: -9),
    FannedScan(sample: "scan-note-bio", centre: 3440, height: 520, degrees: 9),
    FannedScan(sample: "scan-library", centre: 880, height: 330, degrees: 7),
    FannedScan(sample: "scan-throw-valet", centre: 2940, height: 500, degrees: -7),
    FannedScan(sample: "scan-license", centre: 1400, height: 350, degrees: -8),
    FannedScan(sample: "scan-throw-coat", centre: 2440, height: 540, degrees: 8),
    FannedScan(sample: "scan-lease", centre: 1760, height: 600, degrees: -4),
    FannedScan(sample: "scan-insurance", centre: 2250, height: 350, degrees: 5),
    FannedScan(sample: nil, centre: 1960, height: 620, degrees: 2),
]

func header() -> CGImage {
    bitmap(headerSize) { context in
        colour(0xc0533a).setFill()
        context.fill(CGRect(origin: .zero, size: headerSize))
        context.interpolationQuality = .high
        // The safe area's middle, with the origin at the bottom left.
        let middle = headerSize.height - headerSafeArea.midY
        for scan in headerFan {
            let image =
                scan.sample.map { load(root.appending(path: "design/prototype/scans/\($0).jpg")) } ?? receipt()
            let width = scan.height * CGFloat(image.width) / CGFloat(image.height)
            let page = CGRect(x: -width / 2, y: -scan.height / 2, width: width, height: scan.height)
            context.saveGState()
            context.translateBy(x: scan.centre, y: middle)
            context.rotate(by: scan.degrees * .pi / 180)
            context.setShadow(offset: CGSize(width: 0, height: -14), blur: 44, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            context.fill(page)
            context.setShadow(offset: .zero, blur: 0, color: nil)
            context.addPath(CGPath(roundedRect: page, cornerWidth: 14, cornerHeight: 14, transform: nil))
            context.clip()
            context.draw(image, in: page)
            context.restoreGState()
        }
    }
}

if arguments[1] == "receipt" {
    write(receipt(), to: target, as: "public.jpeg", quality: 0.9)
} else if arguments[1] == "header" {
    write(header(), to: target, as: "public.png")
} else {
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    let images = shots.map { shot in
        let image = framed(shot)
        write(image, to: target.appending(path: "\(shot.name).png"), as: "public.png")
        return image
    }
    // The contact sheet: all six side by side, for looking at the set as a whole.
    let thumb = CGSize(width: 330, height: 717)
    let gap: CGFloat = 24
    let sheetSize = CGSize(width: (thumb.width + gap) * CGFloat(images.count) + gap, height: thumb.height + gap * 2)
    let sheet = bitmap(sheetSize) { context in
        NSColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.interpolationQuality = .high
        for (index, image) in images.enumerated() {
            context.draw(
                image, in: CGRect(origin: CGPoint(x: gap + CGFloat(index) * (thumb.width + gap), y: gap), size: thumb))
        }
    }
    write(sheet, to: target.appending(path: "contact-sheet.png"), as: "public.png")
}

// swiftlint:enable multiline_arguments force_unwrapping
