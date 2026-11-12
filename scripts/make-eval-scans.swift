#!/usr/bin/env swift  // Draws the made-up test set for the suggestion evaluation (Plan 5): synthetic scans plus cases.json.
//
//   swift scripts/make-eval-scans.swift <out-dir>
//
// Writes <out-dir>/cases.json and <out-dir>/scans/*.jpg. Deterministic: every random choice is seeded from the
// case id, so re-running reproduces the files. Scans marked `reuse` are copied from design/prototype/scans.
// Everything drawn is made up: names, numbers, addresses, states. System fonts only.

// A dev script whose case table is data: the app's style rules for layout literals, short drawing names,
// force unwraps on CoreGraphics calls and print() don't fit it. Scoped to this file, re-enabled at the end.
// swiftlint:disable multiline_arguments multiline_parameters identifier_name force_unwrapping file_length function_parameter_count large_tuple legacy_multiple no_print - dev script, case table is data

import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// MARK: - Table types

typealias RGB = (CGFloat, CGFloat, CGFloat)

enum Style { case receipt, card, biz, form, note, stub }

/// One degradation for a `low` case. Exactly one per scan.
enum Low {
    case blur(CGFloat)  // Gaussian, pixels
    case rotate(CGFloat)  // degrees
    case contrast  // 0.6
    case shadow  // soft gradient across the page
    case jpeg  // quality 0.3

    var name: String {
        switch self {
        case .blur: "blur"
        case .rotate: "rotation"
        case .contrast: "contrast 0.6"
        case .shadow: "shadow"
        case .jpeg: "jpeg 0.3"
        }
    }
}

struct Doc {
    var style: Style
    var head: [String] = []
    /// receipt: [name, price] or [text]; form: [text], [label, value] or [l1, v1, l2, v2]; card: [label, value]; note: [line]
    var rows: [[String]] = []
    var foot: [String] = []
    var tint = 0
    var width: CGFloat?
    var height: CGFloat?
}

struct Entry {
    var id: String
    var collection: String
    var titles: [String]
    var searches: [String]
    var files: [String]
    var doc: Doc?
    var low: Low?
    var collections: [String]?
}

let builtIn = ["wallet", "receipts", "notes", "documents", "throwaways"]
let taxesList = builtIn + ["taxes"]

let tints: [RGB] = [
    (0.16, 0.34, 0.62), (0.13, 0.50, 0.38), (0.45, 0.25, 0.58), (0.72, 0.30, 0.20),
    (0.20, 0.20, 0.24), (0.80, 0.55, 0.10), (0.10, 0.45, 0.55), (0.62, 0.18, 0.30),
]

// MARK: - Fonts, text, randomness

func font(_ names: [String], _ size: CGFloat) -> CTFont {
    for name in names {
        let candidate = CTFontCreateWithName(name as CFString, size, nil)
        if CTFontCopyPostScriptName(candidate) as String == name { return candidate }
    }
    return CTFontCreateWithName("Helvetica" as CFString, size, nil)
}

let mono = ["Menlo-Regular", "Courier"]
let monoBold = ["Menlo-Bold", "Courier-Bold"]
let sans = ["Helvetica"]
let sansBold = ["Helvetica-Bold"]
let serif = ["Georgia"]
let serifBold = ["Georgia-Bold"]
let hand = ["Noteworthy-Light", "BradleyHandITCTT-Bold", "MarkerFelt-Thin"]

enum Align { case left, center, right }

/// Draws one line. The context is top-left origin; `y` is the baseline.
func text(
    _ ctx: CGContext, _ string: String, x: CGFloat, y: CGFloat, _ face: [String], _ size: CGFloat,
    color: RGB = (0.12, 0.12, 0.14), align: Align = .left, tracking: CGFloat = 0
) {
    if string.isEmpty { return }
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font(face, size),
        kCTForegroundColorAttributeName: CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1),
        kCTKernAttributeName: tracking,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attrs as [NSAttributedString.Key: Any]) as CFAttributedString)
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let left: CGFloat =
        switch align {
        case .left: x
        case .center: x - width / 2
        case .right: x - width
        }
    ctx.textPosition = CGPoint(x: left, y: y)
    CTLineDraw(line, ctx)
}

func fill(_ ctx: CGContext, _ color: RGB, alpha: CGFloat = 1) {
    ctx.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha))
}

func stroke(_ ctx: CGContext, _ color: RGB, width: CGFloat = 1, dash: [CGFloat] = []) {
    ctx.setStrokeColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1))
    ctx.setLineWidth(width)
    ctx.setLineDash(phase: 0, lengths: dash)
}

func hline(_ ctx: CGContext, _ x1: CGFloat, _ x2: CGFloat, _ y: CGFloat) {
    ctx.move(to: CGPoint(x: x1, y: y))
    ctx.addLine(to: CGPoint(x: x2, y: y))
    ctx.strokePath()
}

/// SplitMix64, seeded from the case id with a stable hash (Swift's own Hasher is randomised per run).
struct Seeded {
    var state: UInt64
    init(_ id: String) {
        state = id.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    mutating func next() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((z ^ (z >> 31)) % 10_000) / 10_000
    }
}

let paper: RGB = (0.985, 0.985, 0.97)
let ink: RGB = (0.12, 0.12, 0.14)
let grey: RGB = (0.45, 0.45, 0.48)

// MARK: - Layout per style (returns the y where content ended)

@discardableResult
func layout(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat, id: String) -> CGFloat {
    switch doc.style {
    case .receipt: layoutReceipt(ctx, doc, w)
    case .card: layoutCard(ctx, doc, w, h)
    case .biz: layoutBiz(ctx, doc, w, h)
    case .form: layoutForm(ctx, doc, w, h)
    case .note: layoutNote(ctx, doc, w, h, id: id)
    case .stub: layoutStub(ctx, doc, w, h)
    }
}

func layoutReceipt(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat) -> CGFloat {
    var y: CGFloat = 40
    for (i, line) in doc.head.enumerated() {
        if i == 0 {
            text(ctx, line, x: w / 2, y: y, monoBold, 19, align: .center)
            y += 24
        } else {
            text(ctx, line, x: w / 2, y: y, mono, 11, color: grey, align: .center)
            y += 17
        }
    }
    y += 6
    stroke(ctx, grey, dash: [4, 3])
    hline(ctx, 24, w - 24, y)
    y += 24
    for row in doc.rows {
        let isTotal = row[0].hasPrefix("TOTAL")
        let face = isTotal ? monoBold : mono
        text(ctx, row[0], x: 26, y: y, face, 12.5)
        if row.count > 1 { text(ctx, row[1], x: w - 26, y: y, face, 12.5, align: .right) }
        y += isTotal ? 24 : 19
    }
    y += 4
    stroke(ctx, grey, dash: [4, 3])
    hline(ctx, 24, w - 24, y)
    y += 24
    for line in doc.foot {
        text(ctx, line, x: w / 2, y: y, mono, 11, color: grey, align: .center)
        y += 17
    }
    return y + 20
}

func layoutCard(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat) -> CGFloat {
    let tint = tints[doc.tint % tints.count]
    ctx.addPath(
        CGPath(
            roundedRect: CGRect(x: 8, y: 8, width: w - 16, height: h - 16), cornerWidth: 26, cornerHeight: 26,
            transform: nil))
    ctx.clip()
    fill(ctx, (0.96, 0.96, 0.98))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    fill(ctx, tint)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: 104))
    text(ctx, doc.head.first ?? "", x: 38, y: 58, sansBold, 30, color: (1, 1, 1))
    if doc.head.count > 1 { text(ctx, doc.head[1], x: 38, y: 84, sans, 14, color: (1, 1, 1)) }
    for (i, row) in doc.rows.enumerated() {
        let x: CGFloat = i % 2 == 0 ? 38 : w / 2 + 10
        let y: CGFloat = 148 + CGFloat(i / 2) * 68
        text(ctx, row[0].uppercased(), x: x, y: y, sans, 11, color: grey, tracking: 1)
        text(ctx, row.count > 1 ? row[1] : "", x: x, y: y + 28, monoBold, 21)
    }
    for (i, line) in doc.foot.enumerated() {
        text(ctx, line, x: 38, y: h - 34 + CGFloat(i) * 15, sans, 11, color: grey)
    }
    return h
}

func layoutBiz(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat) -> CGFloat {
    let tint = tints[doc.tint % tints.count]
    stroke(ctx, (0.8, 0.8, 0.8))
    ctx.stroke(CGRect(x: 10, y: 10, width: w - 20, height: h - 20))
    fill(ctx, tint)
    ctx.fill(CGRect(x: 10, y: 10, width: 14, height: h - 20))
    text(ctx, doc.head.first ?? "", x: 54, y: 120, serifBold, 34)
    if doc.head.count > 1 { text(ctx, doc.head[1], x: 54, y: 152, serif, 17, color: grey) }
    if doc.head.count > 2 { text(ctx, doc.head[2], x: w - 40, y: 70, sansBold, 16, color: tint, align: .right) }
    for (i, row) in doc.rows.enumerated() {
        text(ctx, row[0], x: 54, y: h - 100 + CGFloat(i) * 24, sans, 15)
    }
    return h
}

func layoutForm(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat) -> CGFloat {
    let tint = tints[doc.tint % tints.count]
    var y: CGFloat = 54
    text(ctx, doc.head.first ?? "", x: 44, y: y, sansBold, 21, color: tint)
    y += 20
    for line in doc.head.dropFirst() {
        text(ctx, line, x: 44, y: y, sans, 11, color: grey)
        y += 15
    }
    y += 6
    stroke(ctx, tint, width: 1.5)
    hline(ctx, 44, w - 44, y)
    y += 30
    for row in doc.rows {
        switch row.count {
        case 1:
            if row[0].isEmpty {
                y += 14
            } else if row[0].hasPrefix("#") {
                text(ctx, String(row[0].dropFirst()), x: 44, y: y, serifBold, 15)
                y += 24
            } else {
                text(ctx, row[0], x: 44, y: y, serif, 14)
                y += 22
            }
        case 2:
            text(ctx, row[0], x: 44, y: y, sans, 13)
            text(ctx, row[1], x: w - 44, y: y, mono, 13, align: .right)
            stroke(ctx, (0.85, 0.85, 0.85))
            hline(ctx, 44, w - 44, y + 7)
            y += 26
        default:
            let boxW = (w - 88 - 14) / 2
            for (k, x) in [CGFloat(44), 44 + boxW + 14].enumerated() {
                stroke(ctx, (0.55, 0.55, 0.6))
                ctx.stroke(CGRect(x: x, y: y - 14, width: boxW, height: 44))
                text(ctx, row[k * 2].uppercased(), x: x + 6, y: y - 3, sans, 8, color: grey, tracking: 0.6)
                text(ctx, row[k * 2 + 1], x: x + 8, y: y + 21, mono, 14)
            }
            y += 60
        }
    }
    var fy = max(y + 24, h - 40 - CGFloat(doc.foot.count) * 14)
    for line in doc.foot {
        text(ctx, line, x: 44, y: fy, sans, 9.5, color: grey)
        fy += 14
    }
    return fy + 30
}

func layoutNote(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat, id: String) -> CGFloat {
    var rng = Seeded(id)
    fill(ctx, (0.99, 0.97, 0.88))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    stroke(ctx, (0.68, 0.78, 0.90))
    var y: CGFloat = 110
    while y < h - 20 {
        hline(ctx, 0, w, y)
        y += 36
    }
    stroke(ctx, (0.85, 0.45, 0.45))
    ctx.move(to: CGPoint(x: 72, y: 0))
    ctx.addLine(to: CGPoint(x: 72, y: h))
    ctx.strokePath()
    let inkBlue: RGB = (0.12, 0.18, 0.45)
    text(ctx, doc.head.first ?? "", x: 92, y: 76, hand, 34, color: inkBlue)
    stroke(ctx, inkBlue, width: 1.5)
    hline(ctx, 92, 92 + CGFloat((doc.head.first ?? "").count) * 15, 86)
    var end: CGFloat = 110
    for (i, row) in doc.rows.enumerated() {
        let base = 110 + CGFloat(i) * 36 - 9
        text(ctx, row[0], x: 92 + rng.next() * 3, y: base + rng.next() * 3 - 1.5, hand, 24, color: inkBlue)
        end = base + 36
    }
    return end
}

func layoutStub(_ ctx: CGContext, _ doc: Doc, _ w: CGFloat, _ h: CGFloat) -> CGFloat {
    let tint = tints[doc.tint % tints.count]
    fill(ctx, (0.97, 0.94, 0.86))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    stroke(ctx, tint, width: 3, dash: [10, 6])
    ctx.stroke(CGRect(x: 14, y: 14, width: w - 28, height: h - 28))
    // Menlo Bold is 0.6 em wide; shrink long numbers to fit inside the dashed border.
    let number = doc.head.count > 1 ? doc.head[1] : ""
    let big = min(120, h * 0.36, (w - 80) / (CGFloat(max(number.count, 1)) * 0.62))
    text(
        ctx, doc.head.first ?? "", x: w / 2, y: h * 0.2, sansBold, min(24, h * 0.1), color: tint, align: .center,
        tracking: 3)
    text(
        ctx, number, x: w / 2, y: h * 0.2 + big + 14, monoBold, big, color: ink,
        align: .center)
    var y = h * 0.2 + big + 44
    for line in doc.foot {
        text(ctx, line, x: w / 2, y: y, mono, 13, color: grey, align: .center)
        y += 19
    }
    return h
}

// MARK: - Render and degrade

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.setShouldAntialias(true)
    return ctx
}

func render(_ doc: Doc, id: String) -> CGImage {
    let w: CGFloat
    var h: CGFloat
    switch doc.style {
    case .receipt: (w, h) = (doc.width ?? 360, 3000)
    case .card, .biz: (w, h) = (doc.width ?? 660, doc.height ?? (doc.style == .biz ? 380 : 416))
    case .form, .note: (w, h) = (doc.width ?? 620, doc.height ?? 802)
    case .stub: (w, h) = (doc.width ?? 360, doc.height ?? 340)
    }
    if doc.style == .receipt || doc.style == .form {
        // Measure on a scratch canvas so the page is as tall as its content.
        let measured = layout(makeContext(Int(w), Int(h)), doc, w, h, id: id)
        h = doc.style == .receipt ? measured : max(h, measured)
    }
    let ctx = makeContext(Int(w), Int(h))
    fill(ctx, paper)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    layout(ctx, doc, w, h, id: id)
    return ctx.makeImage()!
}

let ciContext = CIContext()

func degrade(_ image: CGImage, _ low: Low) -> CGImage {
    let w = image.width
    let h = image.height
    switch low {
    case .blur(let radius):
        let input = CIImage(cgImage: image).clampedToExtent()
        let blurred = input.applyingGaussianBlur(sigma: radius).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        return ciContext.createCGImage(blurred, from: blurred.extent)!
    case .contrast:
        let flat = CIImage(cgImage: image).applyingFilter(
            "CIColorControls", parameters: [kCIInputContrastKey: 0.6, kCIInputBrightnessKey: 0.04])
        return ciContext.createCGImage(flat, from: flat.extent)!
    case .rotate(let degrees):
        let ctx = makeContext(w, h)
        fill(ctx, (0.80, 0.80, 0.78))  // the table the page lies on
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
        ctx.rotate(by: degrees * .pi / 180)
        ctx.scaleBy(x: 0.92, y: 0.92)
        // makeContext flips y, so draw the image back the right way up.
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: -CGFloat(w) / 2, y: -CGFloat(h) / 2, width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()!
    case .shadow:
        let ctx = makeContext(w, h)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: -CGFloat(h))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [CGColor(gray: 0, alpha: 0.55), CGColor(gray: 0, alpha: 0.0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(
            gradient, start: .zero, end: CGPoint(x: CGFloat(w) * 0.6, y: CGFloat(h) * 0.5), options: [])
        return ctx.makeImage()!
    case .jpeg:
        return image
    }
}

func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
}

// MARK: - The table

var entries: [Entry] = []

/// A scan drawn by this script.
func gen(
    _ id: String, _ collection: String, _ doc: Doc, titles: [String], searches: [String], low: Low? = nil,
    collections: [String]? = nil
) {
    entries.append(
        Entry(
            id: id, collection: collection, titles: titles, searches: searches, files: ["\(id).jpg"], doc: doc,
            low: low, collections: collections))
}

/// A scan copied from design/prototype/scans (one case may span several pages).
func reuse(
    _ id: String, _ collection: String, _ files: [String], titles: [String], searches: [String],
    collections: [String]? = nil
) {
    entries.append(
        Entry(
            id: id, collection: collection, titles: titles, searches: searches, files: files, doc: nil, low: nil,
            collections: collections))
}

func receipt(
    _ head: [String], _ rows: [[String]], total: String, foot: [String] = ["Thank you", "Please come again"],
    tint: Int = 0
) -> Doc {
    Doc(style: .receipt, head: head, rows: rows + [["TOTAL", total], ["Card ****0000"]], foot: foot, tint: tint)
}

// -- Wallet (9 reused, 7 drawn, 4 low)
reuse(
    "wallet-license-sample-state", "wallet", ["scan-license.jpg"],
    titles: ["Driver License", "Sample State Driver License", "Driver's License"], searches: ["driving", "ID", "DMV"])
reuse(
    "wallet-temp-license", "wallet", ["scan-templicense.jpg"],
    titles: ["Temporary Driver License", "Temp Driver License", "Temporary License"],
    searches: ["DMV", "identity", "motorist"])
reuse(
    "wallet-passport", "wallet", ["scan-passport.jpg"],
    titles: ["Passport", "Sampleland Passport"], searches: ["travel", "ID", "international"])
reuse(
    "wallet-work-id", "wallet", ["scan-workid.jpg"],
    titles: ["Work ID", "Northwind Labs ID", "Staff ID Badge"], searches: ["employer", "badge", "office"])
reuse(
    "wallet-coworking-badge", "wallet", ["scan-badge-tall.jpg"],
    titles: ["Riverside Coworking Badge", "Coworking Membership", "Riverside Coworking"],
    searches: ["office", "membership", "workspace"])
reuse(
    "wallet-gym-card", "wallet", ["scan-gym.jpg"],
    titles: ["Ironworks Fitness Card", "Gym Membership", "Ironworks Fitness Club"],
    searches: ["workout", "exercise", "membership"])
reuse(
    "wallet-health-insurance", "wallet", ["scan-insurance.jpg"],
    titles: ["Northfield Mutual Insurance Card", "Health Insurance Card", "Health Insurance"],
    searches: ["medical", "doctor", "coverage"])
reuse(
    "wallet-library-card", "wallet", ["scan-library.jpg"],
    titles: ["Anytown Public Library Card", "Library Card"], searches: ["books", "borrow", "reading"])
reuse(
    "wallet-vaccination-card", "wallet", ["scan-vaccine.jpg"],
    titles: ["Immunization Record", "Vaccination Card", "Vaccine Record"], searches: ["shots", "immunity", "medical"])
gen(
    "wallet-license-northern-plains", "wallet",
    Doc(
        style: .card,
        head: ["Northern Plains", "DRIVER LICENSE"],
        rows: [
            ["Name", "MORGAN, ALEX"], ["DL no.", "N000 0000 0000"], ["Class", "C"], ["Expires", "00/00/0000"],
            ["Address", "100 SAMPLE ST"], ["DOB", "00/00/0000"],
        ],
        foot: ["Sample card, not valid"], tint: 1),
    titles: ["Northern Plains Driver License", "Driver License", "Driver's License"],
    searches: ["driving", "ID", "DMV"])
gen(
    "wallet-license-eastlake", "wallet",
    Doc(
        style: .card,
        head: ["Eastlake", "OPERATOR LICENSE"],
        rows: [
            ["Name", "MORGAN, ALEX J"], ["Lic. no.", "E00 000 000"], ["Class", "D"], ["Expires", "00/00/0000"],
            ["Address", "100 SAMPLE RD"], ["DOB", "00/00/0000"],
        ],
        foot: ["Sample card, not valid"], tint: 2),
    titles: ["Eastlake Driver License", "Operator License", "Driver License"], searches: ["driving", "ID", "DMV"],
    low: .rotate(6))
gen(
    "wallet-license-westmoor", "wallet",
    Doc(
        style: .card,
        head: ["Westmoor State", "IDENTIFICATION CARD"],
        rows: [
            ["Name", "MORGAN, ALEX"], ["ID no.", "W0000000"], ["Issued", "00/00/0000"], ["Expires", "00/00/0000"],
        ],
        foot: ["Sample card, not valid"], tint: 3),
    titles: ["Westmoor State ID", "State ID Card", "Identification Card"], searches: ["DMV", "identity", "photo"])
gen(
    "wallet-business-card-chen", "wallet",
    Doc(
        style: .biz,
        head: ["Priya Nair", "Landscape Architect", "STUDIO FERN"],
        rows: [["priya@studiofern.example"], ["000 000 0000"], ["12 Sample Lane, Anytown"]], tint: 1),
    titles: ["Priya Nair Business Card", "Studio Fern Business Card", "Priya Nair, Studio Fern"],
    searches: ["contact", "designer", "garden"])
gen(
    "wallet-business-card-ortiz", "wallet",
    Doc(
        style: .biz,
        head: ["Marcus Bell", "Electrician", "BELL & SONS"],
        rows: [["marcus@bellsons.example"], ["000 000 0000"], ["Licensed and insured"]], tint: 3),
    titles: ["Marcus Bell Business Card", "Bell & Sons Business Card", "Marcus Bell, Electrician"],
    searches: ["contact", "repair", "wiring"], low: .blur(2.0))
gen(
    "wallet-transit-card", "wallet",
    Doc(
        style: .card,
        head: ["Metro Go", "TRANSIT CARD"],
        rows: [
            ["Card no.", "0000 0000 0000"], ["Balance", "$00.00"], ["Fare", "Adult"], ["Valid", "Anytown Metro"],
        ],
        foot: ["Sample card, not valid"], tint: 6),
    titles: ["Metro Go Transit Card", "Transit Card", "Metro Card"], searches: ["subway", "bus", "commute"])
gen(
    "wallet-student-id", "wallet",
    Doc(
        style: .card,
        head: ["Lakeview University", "STUDENT ID"],
        rows: [["Name", "Alex Morgan"], ["ID", "00000000"], ["Program", "Biology"], ["Valid thru", "05/2027"]],
        foot: ["Sample card, not valid"], tint: 7),
    titles: ["Lakeview University Student ID", "Student ID", "Lakeview Student ID"],
    searches: ["campus", "college", "school"], low: .shadow)
gen(
    "wallet-auto-insurance", "wallet",
    Doc(
        style: .card,
        head: ["Granite State Auto", "PROOF OF INSURANCE"],
        rows: [
            ["Insured", "Alex J Morgan"], ["Policy", "GSA 0000 0000"], ["Vehicle", "Northwind Compass"],
            ["Effective", "01/01/2026"], ["Expires", "06/30/2026"], ["Agent", "000 000 0000"],
        ],
        foot: ["Sample card, not valid"], tint: 4),
    titles: ["Granite State Auto Insurance Card", "Auto Insurance Card", "Proof of Insurance"],
    searches: ["coverage", "driver", "liability"], low: .contrast)

// -- Receipts (8 reused, 8 drawn, 3 low)
reuse(
    "receipts-corner-market", "receipts", ["scan-r-corner.jpg"],
    titles: ["Corner Market Receipt", "Corner Market", "Corner Market Groceries"],
    searches: ["groceries", "food", "supermarket"])
reuse(
    "receipts-bluebird-cafe", "receipts", ["scan-r-bluebird.jpg"],
    titles: ["Bluebird Cafe Receipt", "Bluebird Café", "Bluebird Cafe"], searches: ["coffee", "breakfast", "lunch"])
reuse(
    "receipts-harbor-gas", "receipts", ["scan-r-gas.jpg"],
    titles: ["Harbor Gas Receipt", "Harbor Gas", "Gas Station Receipt"], searches: ["fuel", "gasoline", "petrol"])
reuse(
    "receipts-city-pharmacy", "receipts", ["scan-r-pharmacy.jpg"],
    titles: ["City Pharmacy Receipt", "City Pharmacy"], searches: ["medicine", "drugstore", "prescription"])
reuse(
    "receipts-northside-hardware", "receipts", ["scan-r-hardware.jpg"],
    titles: ["Northside Hardware Receipt", "Northside Hardware"], searches: ["tools", "repair", "DIY"])
reuse(
    "receipts-page-and-spine", "receipts", ["scan-r-books.jpg"],
    titles: ["Page & Spine Booksellers Receipt", "Page & Spine Receipt", "Page & Spine Booksellers"],
    searches: ["reading", "novel", "bookstore"])
reuse(
    "receipts-pizzeria-sole", "receipts", ["scan-r-pizza.jpg"],
    titles: ["Pizzeria Sole Receipt", "Pizzeria Sole", "Pizzeria Sole Dinner"],
    searches: ["restaurant", "dinner", "pizza"])
reuse(
    "receipts-tallow-electric", "receipts", ["scan-receipt.jpg"],
    titles: ["Tallow Electric Receipt", "Tallow Electric Laptop Purchase", "Laptop Receipt"],
    searches: ["computer", "electronics", "purchase"])
gen(
    "receipts-greenway-grocery", "receipts",
    receipt(
        ["GREENWAY GROCERY", "88 Sample Ave, Anytown", "000 000 0000", "11/02/2026  17:48"],
        [
            ["Oat milk 1L", "3.49"], ["Spinach 250g", "2.99"], ["Pasta 500g", "1.79"], ["Chicken thighs", "8.40"],
            ["Yogurt 4pk", "4.25"], ["Bananas 1.1kg", "1.32"], ["Sparkling water", "1.89"], ["SUBTOTAL", "24.13"],
        ],
        total: "24.13"),
    titles: ["Greenway Grocery Receipt", "Greenway Grocery"], searches: ["groceries", "food", "supermarket"],
    low: .blur(1.5))
gen(
    "receipts-daily-grind", "receipts",
    receipt(
        ["THE DAILY GRIND", "Coffee Roasters", "31 Sample St", "11/05/2026  08:12"],
        [["Flat white", "4.50"], ["Almond croissant", "3.75"], ["Cold brew", "4.25"]], total: "12.50"),
    titles: ["The Daily Grind Receipt", "The Daily Grind Coffee", "Daily Grind Receipt"],
    searches: ["espresso", "breakfast", "cafe"])
gen(
    "receipts-lakeside-fuel", "receipts",
    receipt(
        ["LAKESIDE FUEL #12", "PUMP 07 PREMIUM", "11.204 GAL @ 3.899", "10/28/2026  06:55"],
        [["Fuel", "43.69"], ["Car wash", "8.00"]], total: "51.69"),
    titles: ["Lakeside Fuel Receipt", "Lakeside Fuel", "Gas Station Receipt"], searches: ["gas", "gasoline", "vehicle"],
    low: .rotate(5))
gen(
    "receipts-trattoria-luna", "receipts",
    receipt(
        ["TRATTORIA LUNA", "TABLE 12 / SERVER: JO", "10/30/2026  19:41"],
        [
            ["Bruschetta", "9.00"], ["Linguine vongole", "22.00"], ["Gnocchi", "18.50"], ["House red x2", "16.00"],
            ["Tiramisu", "8.50"], ["Tip 20%", "14.80"],
        ], total: "88.80"),
    titles: ["Trattoria Luna Receipt", "Trattoria Luna Dinner", "Trattoria Luna"],
    searches: ["restaurant", "dinner", "Italian"])
gen(
    "receipts-online-order", "receipts",
    Doc(
        style: .form,
        head: ["Order confirmation", "Parcelhouse online store", "order #PH-000-0000000"],
        rows: [
            ["Order date", "November 3, 2026"], ["Ship to", "Alex Morgan, 100 Sample Street, Anytown"], [""],
            ["#Items"], ["Desk lamp, brass", "$42.00"], ["USB-C hub 7-port", "$29.99"],
            ["Cable organiser set", "$9.50"], [""], ["Shipping", "$0.00"], ["Tax", "$6.68"], ["Order total", "$88.17"],
            [""], ["Paid with card ending 0000. Estimated delivery Nov 9."],
        ],
        foot: ["Sample order, not a real purchase"], tint: 0),
    titles: ["Parcelhouse Order Confirmation", "Parcelhouse Online Order", "Online Order Receipt"],
    searches: ["shopping", "amazon", "package"], low: .jpeg)
gen(
    "receipts-parking-garage", "receipts",
    receipt(
        ["CITY CENTER GARAGE", "LEVEL 2 / BAY 214", "ENTRY 09:03  EXIT 14:37", "11/04/2026"],
        [["Parking 5h 34m", "18.00"], ["Event rate", "-4.00"]], total: "14.00",
        foot: ["Paid by card", "Lost ticket fee $40"]),
    titles: ["City Center Garage Receipt", "Parking Garage Receipt", "Parking Receipt"],
    searches: ["downtown", "vehicle", "hourly"])
gen(
    "receipts-bakery", "receipts",
    receipt(
        ["FLOUR & CROWN BAKERY", "7 Sample Row, Anytown", "11/07/2026  09:20"],
        [["Sourdough loaf", "7.50"], ["Pain au chocolat x2", "7.00"], ["Baguette", "3.25"]], total: "17.75"),
    titles: ["Flour & Crown Bakery Receipt", "Flour & Crown Bakery", "Bakery Receipt"],
    searches: ["bread", "pastry", "breakfast"])
gen(
    "receipts-tax-prep-fee", "receipts",
    receipt(
        ["BRIGHTPATH TAX SERVICE", "Anytown office", "02/12/2026", "Invoice 000412"],
        [["Federal return", "120.00"], ["State return", "45.00"], ["E-file fee", "0.00"]], total: "165.00",
        foot: ["Paid in full", "Keep for your records"], tint: 5),
    titles: ["BrightPath Tax Service Receipt", "Tax Preparation Receipt", "Tax Prep Fee Receipt"],
    searches: ["taxes", "accountant", "filing"])
gen(
    "receipts-charity-donation", "receipts",
    Doc(
        style: .form,
        head: ["Donation receipt", "Riverbend Food Bank", "A registered charity (sample)"],
        rows: [
            ["Donor", "Alex Morgan"], ["Date", "December 18, 2026"], ["Amount", "$250.00"], [""],
            [
                "Thank you for your gift. No goods or services were provided in exchange for this contribution. Please keep this receipt for your tax records."
            ],
        ],
        foot: ["Sample receipt, not real"], tint: 1),
    titles: ["Riverbend Food Bank Donation Receipt", "Charity Donation Receipt", "Food Bank Donation"],
    searches: ["giving", "deduction", "nonprofit"])
gen(
    "receipts-garden-center", "receipts",
    receipt(
        ["FERN & FIELD GARDEN CENTER", "3 Sample Hwy", "10/22/2026  11:15"],
        [["Potting soil 20L", "11.99"], ["Basil plant", "3.99"], ["Terracotta pot", "8.49"], ["Trowel", "12.00"]],
        total: "36.47"),
    titles: ["Fern & Field Garden Center Receipt", "Garden Center Receipt", "Fern & Field Receipt"],
    searches: ["plants", "gardening", "dirt"], low: .contrast)

// -- Notes (2 reused, 14 drawn, 4 low)
reuse(
    "notes-bio-class", "notes", ["scan-note-bio.jpg"],
    titles: ["Bio 210 Glycolysis", "Glycolysis Notes", "Bio 210 Notes"], searches: ["biology", "class", "lecture"])
reuse(
    "notes-landlord-call", "notes", ["scan-note-call.jpg"],
    titles: ["Call with Landlord", "Landlord Call Notes", "Landlord Call"],
    searches: ["apartment", "maintenance", "lease"])
gen(
    "notes-history-class", "notes",
    Doc(
        style: .note,
        head: ["Hist 101 - Oct 14"],
        rows: [
            ["The Industrial Revolution"], ["- began in Britain, c. 1760"], ["- coal + iron + canals"],
            ["- textile mills first"], ["- urban growth, new classes"], [""], ["Causes (know for exam):"],
            ["  1. agricultural surplus"], ["  2. capital and trade"], ["  3. steam power"], [""],
            ["essay due Fri, 1200 words"],
        ]),
    titles: ["Hist 101 Industrial Revolution", "Industrial Revolution Notes", "History 101 Notes"],
    searches: ["history", "lecture", "college"])
gen(
    "notes-math-class", "notes",
    Doc(
        style: .note,
        head: ["Calc II - Nov 2"],
        rows: [
            ["Integration by parts"], ["  int u dv = uv - int v du"], ["pick u: LIATE rule"], [""],
            ["ex: int x e^x dx"], ["  u = x   dv = e^x dx"], ["  = x e^x - e^x + C"], [""], ["HW 7 due Thurs"],
        ]),
    titles: ["Calc II Integration by Parts", "Calculus Notes", "Calc II Notes"],
    searches: ["math", "calculus", "class"], low: .blur(2.0))
gen(
    "notes-chem-class", "notes",
    Doc(
        style: .note,
        head: ["Chem 120 - Nov 9"],
        rows: [
            ["Le Chatelier's principle"], ["- system shifts to oppose change"], ["- add reactant -> shifts right"],
            ["- raise temp: favours endothermic"], [""], ["lab report: titration, due Mon"],
        ]),
    titles: ["Chem 120 Le Chatelier's Principle", "Chemistry Notes", "Chem 120 Notes"],
    searches: ["chemistry", "class", "science"])
gen(
    "notes-todo-weekend", "notes",
    Doc(
        style: .note,
        head: ["To do - weekend"],
        rows: [
            ["[ ] call the dentist"], ["[ ] return library books"], ["[x] pay water bill"], ["[ ] fix bike tyre"],
            ["[ ] laundry"], ["[ ] email Sam re: dinner"], ["[ ] renew parking permit"],
        ]),
    titles: ["Weekend To Do", "To Do List", "To Do - Weekend"], searches: ["tasks", "chores", "errands"])
gen(
    "notes-todo-moving", "notes",
    Doc(
        style: .note,
        head: ["Moving checklist"],
        rows: [
            ["- book movers (Nov 20)"], ["- change address: bank, DMV"], ["- forward mail"], ["- cancel internet"],
            ["- pack kitchen"], ["- take photos of meter readings"], ["- return keys to landlord"],
        ]),
    titles: ["Moving Checklist", "Moving To Do List", "Moving To Do"], searches: ["relocation", "tasks", "apartment"],
    low: .shadow)
gen(
    "notes-recipe-card", "notes",
    Doc(
        style: .note,
        head: ["Nana's lentil soup"],
        rows: [
            ["1 cup brown lentils"], ["1 onion, 2 carrots, 2 celery"], ["3 cloves garlic"], ["1 tin tomatoes"],
            ["6 cups stock, bay leaf"], [""], ["Sweat veg 10 min, add the rest,"], ["simmer 40 min. Lemon at the end."],
            ["Serves 6"],
        ]),
    titles: ["Nana's Lentil Soup", "Lentil Soup Recipe", "Lentil Soup"], searches: ["recipe", "cooking", "dinner"])
gen(
    "notes-meeting-kickoff", "notes",
    Doc(
        style: .note,
        head: ["Kickoff mtg - Nov 4"],
        rows: [
            ["attendees: Dana, Priya, Leo, me"], ["goal: ship v2 by Jan 15"], ["- scope: search + sharing only"],
            ["- design review Nov 12"], ["- Leo owns API changes"], ["- risk: vendor SDK delay"], [""],
            ["next: draft timeline (me), Fri"],
        ]),
    titles: ["Kickoff Meeting Notes", "Kickoff Meeting - Nov 4", "Project Kickoff Notes"],
    searches: ["work", "project", "agenda"])
gen(
    "notes-meeting-1on1", "notes",
    Doc(
        style: .note,
        head: ["1:1 with Dana"],
        rows: [
            ["- feedback on the roadmap doc"], ["- wants more data on churn"], ["- promo cycle opens in Feb"],
            ["- take Dec 24-31 off"], ["follow up: share survey results"],
        ]),
    titles: ["1:1 with Dana", "One on One with Dana", "Meeting Notes with Dana"],
    searches: ["work", "manager", "meeting"], low: .rotate(4))
gen(
    "notes-call-plumber", "notes",
    Doc(
        style: .note,
        head: ["Call - plumber"],
        rows: [
            ["Marcus, Bell & Sons"], ["leak under kitchen sink"], ["quote: $180 + parts"], ["can come Tues 9-11"],
            ["bring: shut-off valve key"],
        ]),
    titles: ["Plumber Call Notes", "Call with Plumber", "Plumber Call"], searches: ["repair", "plumbing", "contractor"])
gen(
    "notes-call-bank", "notes",
    Doc(
        style: .note,
        head: ["Call w/ bank"],
        rows: [
            ["ref #: 0000-00"], ["spoke to: Rosa"], ["disputed charge $64.20"], ["credit in 3-5 days"],
            ["new card arrives next week"],
        ]),
    titles: ["Call with Bank", "Bank Call Notes", "Bank Dispute Call"], searches: ["money", "fraud", "chargeback"],
    low: .contrast)
gen(
    "notes-gift-ideas", "notes",
    Doc(
        style: .note,
        head: ["Gift ideas"],
        rows: [
            ["Mum: scarf, tea sampler"], ["Dad: book on bridges"], ["Sam: climbing chalk bag"],
            ["Priya: plant (fern!)"], ["secret santa: under $25"],
        ]),
    titles: ["Gift Ideas", "Gift List", "Holiday Gift Ideas"], searches: ["presents", "holiday", "birthday"])
gen(
    "notes-packing-list", "notes",
    Doc(
        style: .note,
        head: ["Packing - Lisbon"],
        rows: [
            ["passport"], ["charger + adapter"], ["rain jacket"], ["walking shoes"], ["swimsuit"], ["sunscreen"],
            ["book"],
        ]),
    titles: ["Lisbon Packing List", "Packing List", "Packing - Lisbon"], searches: ["travel", "trip", "vacation"])
gen(
    "notes-book-notes", "notes",
    Doc(
        style: .note,
        head: ["Reading: Deep Work"],
        rows: [
            ["ch 1: focus is a skill"], ["ch 2: schedule blocks, 90 min"], ["ch 3: embrace boredom"],
            ["quote p.84: \"clarity about what"], ["matters provides clarity about"], ["what does not\""],
        ]),
    titles: ["Deep Work Reading Notes", "Book Notes", "Reading Notes - Deep Work"],
    searches: ["book", "productivity", "concentration"])

// -- Documents (4 reused cases, 13 drawn, 4 low)
reuse(
    "documents-lease-letter", "documents", ["scan-lease.jpg"],
    titles: ["Lease Renewal Letter", "Harlow Property Management Lease Letter", "Lease Renewal Offer"],
    searches: ["housing", "tenancy", "renting"])
reuse(
    "documents-lease-renewal", "documents", ["scan-lease-p2.jpg", "scan-lease-p3.jpg"],
    titles: ["Lease Renewal Agreement", "Lease Renewal Agreement Unit 4B", "Apartment Lease Renewal"],
    searches: ["housing", "tenancy", "contract"])
reuse(
    "documents-vehicle-registration", "documents", ["scan-registration.jpg"],
    titles: ["Vehicle Registration", "Certificate of Vehicle Registration", "Northwind Compass Registration"],
    searches: ["car", "automobile", "tags"])
gen(
    "documents-w2", "documents",
    Doc(
        style: .form,
        head: [
            "W-2 Wage and Tax Statement 2026", "Copy B, to be filed with employee's return",
            "Sample form, not an official document",
        ],
        rows: [
            ["Employee", "ALEX J MORGAN", "SSN", "000-00-0000"],
            ["Employer", "NORTHWIND LABS INC", "EIN", "00-0000000"],
            ["1 Wages", "$00,000.00", "2 Fed tax withheld", "$0,000.00"],
            ["3 SS wages", "$00,000.00", "4 SS tax withheld", "$0,000.00"],
            ["5 Medicare wages", "$00,000.00", "6 Medicare tax", "$000.00"],
            ["16 State wages", "$00,000.00", "17 State tax", "$000.00"],
        ],
        foot: ["Department of the Treasury - Internal Revenue Service (sample)"], tint: 4),
    titles: ["2026 W-2", "W-2 Wage and Tax Statement 2026", "Northwind Labs W-2"],
    searches: ["taxes", "salary", "paycheck", "earnings"])
gen(
    "documents-1099-nec", "documents",
    Doc(
        style: .form,
        head: [
            "1099-NEC Nonemployee Compensation 2026", "Copy B for recipient", "Sample form, not an official document",
        ],
        rows: [
            ["Payer", "FERNWOOD STUDIOS LLC", "Payer TIN", "00-0000000"],
            ["Recipient", "ALEX J MORGAN", "Recipient TIN", "000-00-0000"],
            ["1 Nonemployee comp", "$0,000.00", "4 Fed tax withheld", "$0.00"],
            ["7 State income", "$0,000.00", "State", "SS"],
        ],
        foot: ["Report this income on your tax return (sample)"], tint: 4),
    titles: ["2026 1099-NEC", "1099-NEC Freelance Income", "Fernwood Studios 1099-NEC"],
    searches: ["taxes", "freelance", "contractor", "earnings"])
gen(
    "documents-1099-int", "documents",
    Doc(
        style: .form,
        head: ["1099-INT Interest Income 2026", "Copy B for recipient", "Sample form, not an official document"],
        rows: [
            ["Payer", "NORTHFIELD SAVINGS BANK", "Payer TIN", "00-0000000"],
            ["Recipient", "ALEX J MORGAN", "Recipient TIN", "000-00-0000"],
            ["1 Interest income", "$000.00", "4 Fed tax withheld", "$0.00"],
        ],
        foot: ["Account 0000, interest paid 2026 (sample)"], tint: 4),
    titles: ["2026 1099-INT", "1099-INT Interest Income", "Northfield Savings 1099-INT"],
    searches: ["taxes", "earnings", "yield"], low: .jpeg)
gen(
    "documents-electric-bill", "documents",
    Doc(
        style: .form,
        head: ["Brightwater Electric", "Statement for October 2026", "Account 000-000-0000"],
        rows: [
            ["Service address", "100 Sample Street, Apt 4B"], ["Billing period", "Sep 28 - Oct 27"], [""], ["#Charges"],
            ["Electricity 412 kWh", "$58.91"], ["Delivery charge", "$21.40"], ["Taxes and fees", "$5.12"],
            ["Amount due", "$85.43"], [""], ["Please pay by November 18, 2026 to avoid a late fee."],
        ],
        foot: ["Sample bill, not a real account"], tint: 5),
    titles: ["Brightwater Electric Bill October 2026", "Electric Bill", "Brightwater Electric Statement"],
    searches: ["utilities", "power", "energy"])
gen(
    "documents-water-bill", "documents",
    Doc(
        style: .form,
        head: ["Anytown Water Works", "Quarterly statement", "Account 000-0000"],
        rows: [
            ["Service address", "100 Sample Street, Apt 4B"], ["Period", "Jul 1 - Sep 30"], ["Usage 14 CCF", "$46.20"],
            ["Sewer", "$31.00"], ["Amount due", "$77.20"], [""], ["Pay online or at any branch by November 10."],
        ],
        foot: ["Sample bill, not a real account"], tint: 6),
    titles: ["Anytown Water Works Bill", "Water Bill", "Water Bill Q3 2026"],
    searches: ["utilities", "household", "wastewater"], low: .blur(2.5))
gen(
    "documents-bank-statement", "documents",
    Doc(
        style: .form,
        head: ["Northfield Savings Bank", "Checking statement, October 2026", "Account ending 0000"],
        rows: [
            ["Opening balance", "$2,410.00"], ["Deposits", "$3,200.00"], ["Withdrawals", "-$2,874.15"],
            ["Closing balance", "$2,735.85"], [""], ["#Recent activity"], ["10/01 Rent", "-$1,450.00"],
            ["10/03 Payroll deposit", "$1,600.00"], ["10/09 Greenway Grocery", "-$62.18"],
            ["10/15 Payroll deposit", "$1,600.00"], ["10/22 Brightwater Electric", "-$85.43"],
        ],
        foot: ["Sample statement, not a real account"], tint: 0),
    titles: ["Northfield Savings Bank Statement October 2026", "Bank Statement October 2026", "Checking Statement"],
    searches: ["money", "ledger", "finances"])
gen(
    "documents-bank-statement-low", "documents",
    Doc(
        style: .form,
        head: ["Harbor Credit Union", "Savings statement, September 2026", "Account ending 0000"],
        rows: [
            ["Opening balance", "$8,120.00"], ["Interest earned", "$6.77"], ["Deposits", "$500.00"],
            ["Closing balance", "$8,626.77"], [""], ["Dividend rate 0.95% APY. Member FDIC (sample)."],
        ],
        foot: ["Sample statement, not a real account"], tint: 6),
    titles: ["Harbor Credit Union Statement September 2026", "Savings Statement", "Bank Statement September 2026"],
    searches: ["money", "finances", "reserves"], low: .rotate(7))
gen(
    "documents-warranty", "documents",
    Doc(
        style: .form,
        head: ["Limited Warranty", "Tallow Electric - 3-year care plan", "Certificate 000000"],
        rows: [
            ["Product", "Laptop 14in 16GB"], ["Purchase date", "October 4, 2026"],
            ["Coverage ends", "October 3, 2029"], [""],
            [
                "This plan covers hardware failure and accidental damage. Present this certificate and the original receipt to claim."
            ],
        ],
        foot: ["Sample warranty, not real"], tint: 3),
    titles: ["Tallow Electric Laptop Warranty", "Laptop Warranty", "Limited Warranty Certificate"],
    searches: ["computer", "protection", "guarantee"])
gen(
    "documents-school-form", "documents",
    Doc(
        style: .form,
        head: ["Field Trip Permission Form", "Maple Grove Elementary", "Grade 3, Room 12"],
        rows: [
            ["Student", "Jamie Morgan", "Date of trip", "November 20, 2026"],
            ["Parent name", "Alex Morgan", "Phone", "000 000 0000"], [""],
            ["Destination: Anytown Science Museum. Cost: $12. Please return this form by November 13."], [""],
            ["[ ] I give permission   [ ] I do not give permission"], [""], ["Signature ______________________"],
        ],
        foot: ["Sample form, not real"], tint: 5),
    titles: ["Field Trip Permission Form", "Maple Grove Elementary Permission Slip", "School Permission Form"],
    searches: ["school", "child", "consent"], low: .shadow)
gen(
    "documents-hoa-letter", "documents",
    Doc(
        style: .form,
        head: ["Cedar Court Homeowners Association", "14 Sample Court, Anytown"],
        rows: [
            ["November 1, 2026"], [""], ["Dear resident,"], [""], ["Annual dues of $480 are due January 15."],
            ["The community meeting is on Dec 3 at 7 pm in"], ["the clubhouse. Trash pickup moves to Thursdays"],
            ["starting December 1."], [""], ["Sincerely,"], ["The Board"],
        ],
        foot: ["Sample letter, not real"], tint: 1),
    titles: ["Cedar Court HOA Letter", "HOA Notice", "Homeowners Association Letter"],
    searches: ["neighborhood", "housing", "fees"])
gen(
    "documents-insurance-letter", "documents",
    Doc(
        style: .form,
        head: ["Granite State Auto", "Policy renewal notice"],
        rows: [
            ["October 20, 2026"], [""], ["Dear Alex Morgan,"], [""], ["Your auto policy GSA 0000 0000 renews on"],
            ["January 1, 2027. The new premium is $612 for"], ["six months, up $18 from your current term."], [""],
            ["No action is needed to keep your coverage."],
        ],
        foot: ["Sample letter, not real"], tint: 4),
    titles: ["Granite State Auto Renewal Notice", "Auto Insurance Renewal Letter", "Policy Renewal Notice"],
    searches: ["car", "vehicle", "insurer"], low: .contrast)
gen(
    "documents-medical-bill", "documents",
    Doc(
        style: .form,
        head: ["Anytown Community Health", "Statement of services"],
        rows: [
            ["Patient", "Alex J Morgan", "Visit date", "09/14/2026"], [""], ["Office visit", "$180.00"],
            ["Lab panel", "$95.00"], ["Insurance paid", "-$212.00"], ["Patient balance", "$63.00"], [""],
            ["Pay online by November 30."],
        ],
        foot: ["Sample bill, not real"], tint: 7),
    titles: ["Anytown Community Health Statement", "Medical Bill", "Doctor Visit Bill"],
    searches: ["doctor", "medical", "healthcare"])
gen(
    "documents-property-tax", "documents",
    Doc(
        style: .form,
        head: ["Sample County Assessor", "Property tax notice 2026"],
        rows: [
            ["Owner", "Alex J Morgan", "Parcel", "000-000-000"], [""], ["Assessed value", "$000,000.00"],
            ["Tax rate", "1.12%"], ["Total due", "$0,000.00"], [""],
            ["First half due December 10. Second half due April 10."],
        ],
        foot: ["Sample notice, not real"], tint: 3),
    titles: ["Property Tax Notice 2026", "Sample County Property Tax Notice", "Property Tax Bill"],
    searches: ["taxes", "house", "assessment"])

// -- Throwaways (4 reused, 12 drawn, 4 low)
reuse(
    "throwaways-coat-check", "throwaways", ["scan-throw-coat.jpg"],
    titles: ["Coat Check 142", "Coat Check Ticket", "Coat Check"], searches: ["jacket", "cloakroom", "ticket"])
reuse(
    "throwaways-park-and-go", "throwaways", ["scan-throw-park.jpg"],
    titles: ["Park & Go Garage Ticket", "Parking Garage Ticket", "Park & Go Ticket"],
    searches: ["parking", "car", "stub"])
reuse(
    "throwaways-valet", "throwaways", ["scan-throw-valet.jpg"],
    titles: ["Valet Ticket 087", "Valet Ticket", "Valet 087"], searches: ["parking", "ticket", "vehicle"])
reuse(
    "throwaways-wifi-note", "throwaways", ["scan-wifi.jpg"],
    titles: ["Wifi Password", "Maple Wifi Note", "Wifi - New Place"], searches: ["internet", "password", "modem"])
gen(
    "throwaways-coat-check-2", "throwaways",
    Doc(style: .stub, head: ["COAT CHECK", "058"], foot: ["Not responsible for valuables"], tint: 0, height: 300),
    titles: ["Coat Check 058", "Coat Check Ticket", "Coat Check"], searches: ["jacket", "cloakroom", "ticket"],
    low: .blur(2.0))
gen(
    "throwaways-parking-stub", "throwaways",
    Doc(style: .stub, head: ["LOT B", "B-214"], foot: ["IN 08:41", "KEEP THIS STUB"], tint: 3),
    titles: ["Lot B Parking Stub", "Parking Stub", "Parking Ticket B-214"], searches: ["parking", "car", "vehicle"])
gen(
    "throwaways-parking-stub-2", "throwaways",
    Doc(style: .stub, head: ["RIVERFRONT PARKING", "0731"], foot: ["IN 17:20", "LEVEL 1"], tint: 6),
    titles: ["Riverfront Parking Stub", "Parking Stub", "Parking Ticket 0731"], searches: ["car", "garage", "vehicle"],
    low: .shadow)
gen(
    "throwaways-valet-2", "throwaways",
    Doc(style: .stub, head: ["VALET", "212"], foot: ["The Alder Hotel", "PRESENT TO RETRIEVE CAR"], tint: 7),
    titles: ["Valet Ticket 212", "Alder Hotel Valet Ticket", "Valet Ticket"], searches: ["parking", "vehicle", "lodging"],
    low: .rotate(5))
gen(
    "throwaways-wifi-slip", "throwaways",
    Doc(style: .stub, head: ["GUEST WIFI", "4821"], foot: ["Network: Cafe-Guest", "Code valid 24 hours"], tint: 1),
    titles: ["Guest Wifi Code", "Wifi Slip", "Cafe Guest Wifi"], searches: ["internet", "password", "connection"])
gen(
    "throwaways-raffle", "throwaways",
    Doc(
        style: .stub, head: ["RAFFLE TICKET", "003917"], foot: ["Drawing at 8 pm", "Must be present to win"], tint: 3,
        height: 300),
    titles: ["Raffle Ticket 003917", "Raffle Ticket", "Raffle 003917"], searches: ["lottery", "prize", "giveaway"])
gen(
    "throwaways-raffle-2", "throwaways",
    Doc(style: .stub, head: ["50/50 RAFFLE", "114502"], foot: ["Maple Grove school fair"], tint: 5, height: 300),
    titles: ["50/50 Raffle Ticket", "Raffle Ticket 114502", "School Fair Raffle Ticket"],
    searches: ["lottery", "prize", "giveaway"], low: .contrast)
gen(
    "throwaways-deli-number", "throwaways",
    Doc(style: .stub, head: ["NOW SERVING", "47"], foot: ["Deli counter"], tint: 3, height: 260),
    titles: ["Deli Number 47", "Deli Ticket", "Deli Counter Number"], searches: ["queue", "grocery", "waiting"])
gen(
    "throwaways-deli-number-2", "throwaways",
    Doc(style: .stub, head: ["TAKE A NUMBER", "09"], foot: ["Bakery counter"], tint: 0, height: 260),
    titles: ["Bakery Number 09", "Take a Number Ticket", "Bakery Counter Number"],
    searches: ["queue", "waiting", "bread"])
gen(
    "throwaways-wristband", "throwaways",
    Doc(
        style: .stub, head: ["GENERAL ADMISSION", "SAT"], foot: ["Lakeside Music Fest 2026"], tint: 2, width: 640,
        height: 190),
    titles: ["Lakeside Music Fest Wristband", "Festival Wristband", "General Admission Wristband"],
    searches: ["concert", "festival", "event"])
gen(
    "throwaways-cinema-stub", "throwaways",
    Doc(style: .stub, head: ["CINEMA 4", "SEAT H12"], foot: ["Sat 7:30 pm", "Admit one"], tint: 7, height: 300),
    titles: ["Cinema Ticket Stub", "Movie Ticket Stub", "Cinema 4 Seat H12"], searches: ["movie", "film", "theater"])
gen(
    "throwaways-bag-check", "throwaways",
    Doc(style: .stub, head: ["BAG CHECK", "T-33"], foot: ["Riverside Museum"], tint: 4, height: 280),
    titles: ["Bag Check T-33", "Museum Bag Check Ticket", "Bag Check Ticket"],
    searches: ["luggage", "ticket", "backpack"])

// -- Custom collection "Taxes" (5 cases, drawn scans reused from above)
func custom(_ id: String, from source: String, titles: [String], searches: [String]) {
    guard let original = entries.first(where: { $0.id == source }) else { fatalError("no case \(source)") }
    entries.append(
        Entry(
            id: id, collection: "taxes", titles: titles, searches: searches, files: original.files, doc: nil, low: nil,
            collections: taxesList))
}
custom(
    "custom-taxes-w2", from: "documents-w2",
    titles: ["2026 W-2", "W-2 Wage and Tax Statement 2026", "Northwind Labs W-2"],
    searches: ["salary", "paycheck", "earnings"])
custom(
    "custom-taxes-1099-nec", from: "documents-1099-nec",
    titles: ["2026 1099-NEC", "1099-NEC Freelance Income", "Fernwood Studios 1099-NEC"],
    searches: ["freelance", "contractor", "earnings"])
custom(
    "custom-taxes-1099-int", from: "documents-1099-int",
    titles: ["2026 1099-INT", "1099-INT Interest Income", "Northfield Savings 1099-INT"],
    searches: ["earnings", "yield", "dividend"])
custom(
    "custom-taxes-tax-prep", from: "receipts-tax-prep-fee",
    titles: ["BrightPath Tax Service Receipt", "Tax Preparation Receipt", "Tax Prep Fee Receipt"],
    searches: ["accountant", "filing", "preparer"])
custom(
    "custom-taxes-donation", from: "receipts-charity-donation",
    titles: ["Riverbend Food Bank Donation Receipt", "Charity Donation Receipt", "Food Bank Donation"],
    searches: ["giving", "deduction", "nonprofit"])

// MARK: - Main

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-eval-scans.swift <out-dir>\n".utf8))
    exit(2)
}
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let scans = out.appendingPathComponent("scans")
let prototype = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("design/prototype/scans")
let fm = FileManager.default
try fm.createDirectory(at: scans, withIntermediateDirectories: true)

var lowCounts: [String: Int] = [:]
for entry in entries {
    if let doc = entry.doc {
        var image = render(doc, id: entry.id)
        var quality: CGFloat = 0.82
        if let low = entry.low {
            image = degrade(image, low)
            if case .jpeg = low { quality = 0.3 }
            lowCounts[entry.collection, default: 0] += 1
            print("low \(entry.collection)/\(entry.id): \(low.name)")
        }
        writeJPEG(image, to: scans.appendingPathComponent(entry.files[0]), quality: quality)
    } else {
        for file in entry.files where entry.collections == nil {
            let target = scans.appendingPathComponent(file)
            try? fm.removeItem(at: target)  // a missing file is fine; this only clears a previous run
            try fm.copyItem(at: prototype.appendingPathComponent(file), to: target)
        }
    }
}

let json: [[String: Any]] = entries.map { entry in
    var item: [String: Any] = [
        "id": entry.id, "files": entry.files, "collection": entry.collection, "titles": entry.titles,
        "searches": entry.searches, "quality": entry.low == nil ? "clean" : "low",
    ]
    if let collections = entry.collections { item["collections"] = collections }
    return item
}
let data = try JSONSerialization.data(
    withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try data.write(to: out.appendingPathComponent("cases.json"))
for file in entries.flatMap(\.files) where !fm.fileExists(atPath: scans.appendingPathComponent(file).path) {
    fatalError("missing scan \(file)")
}
print("\(entries.count) cases")

// MARK: - Hidden words only

/// Folds case and accents so "Café" and "cafe" compare equal.
func folded(_ string: String) -> String {
    string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
}

/// Every string the generator draws for a case; a reused scan has none here (it is checked against its OCR).
func printedText(_ entry: Entry) -> String {
    guard let doc = entry.doc else { return "" }
    return ([doc.head] + doc.rows + [doc.foot]).flatMap { $0 }.joined(separator: " ")
}

/// A search must find a scan by what it IS, never by a word printed on it.
func leaks(_ entry: Entry, in printed: String) -> [String] {
    let words = folded(printed).split { !$0.isLetter && !$0.isNumber }.map(String.init)
    return entry.searches.filter { query in
        let q = folded(query)
        return words.contains { $0.hasPrefix(q) }
    }
}

/// What a reused scan prints, read back from the image.
func ocrText(_ url: URL) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(url: url).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
}

var printedByFile: [String: String] = [:]
for entry in entries {
    for file in entry.files where printedByFile[file] == nil {
        printedByFile[file] =
            entry.doc != nil ? printedText(entry) : try ocrText(scans.appendingPathComponent(file))
    }
}
var leaking = false
for entry in entries {
    let found = leaks(entry, in: entry.files.compactMap { printedByFile[$0] }.joined(separator: " "))
    if !found.isEmpty {
        leaking = true
        print("LEAK \(entry.id): \(found)")
    }
}
if leaking { exit(1) }

// swiftlint:enable multiline_arguments multiline_parameters identifier_name force_unwrapping file_length function_parameter_count large_tuple legacy_multiple no_print
