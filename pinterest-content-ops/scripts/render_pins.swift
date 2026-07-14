#!/usr/bin/env swift

import AppKit
import Foundation
import Darwin

struct Brand: Decodable {
    let name: String
    let mark: String?
    let accent: String?
    let ink: String?
    let cta: String?
}

struct PinVisual: Decodable {
    let id: String
    let background: String
    let product: String
    let badge: String
    let headline: String
    let subline: String
    let label: String
    let meta_strong: String
    let meta_text: String
    let proof: String
    let headline_size: Double?
    let dark: Bool?
    let accent: String?
    let ink: String?
}

struct VisualConfig: Decodable {
    let brand: Brand
    let pins: [PinVisual]
}

struct RenderResult: Encodable {
    let ok: Bool
    let pins: Int
    let output_dir: String
    let contact_sheet: String
}

enum RenderError: Error, CustomStringConvertible {
    case usage
    case missingImage(String)
    case invalidColor(String)
    case jpeg(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: render_pins.swift --config visuals.json --out pins [--contact-sheet contact-sheet.jpg]"
        case .missingImage(let path):
            return "image not found or unreadable: \(path)"
        case .invalidColor(let value):
            return "invalid hex color: \(value)"
        case .jpeg(let path):
            return "could not write JPEG: \(path)"
        }
    }
}

let canvasWidth = 1000
let canvasHeight = 1500

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func parseHex(_ value: String) throws -> NSColor {
    let cleaned = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard cleaned.count == 6, let number = Int(cleaned, radix: 16) else {
        throw RenderError.invalidColor(value)
    }
    return NSColor(
        calibratedRed: CGFloat((number >> 16) & 0xff) / 255,
        green: CGFloat((number >> 8) & 0xff) / 255,
        blue: CGFloat(number & 0xff) / 255,
        alpha: 1
    )
}

func resolve(_ path: String, relativeTo base: URL) -> String {
    if path.hasPrefix("/") { return URL(fileURLWithPath: path).standardizedFileURL.path }
    return base.appendingPathComponent(path).standardizedFileURL.path
}

func loadImage(_ path: String) throws -> NSImage {
    guard let result = NSImage(contentsOfFile: path) else { throw RenderError.missingImage(path) }
    return result
}

func drawAspectFill(_ image: NSImage, in rect: NSRect) {
    let source = image.size
    let scale = max(rect.width / source.width, rect.height / source.height)
    let size = NSSize(width: source.width * scale, height: source.height * scale)
    let target = NSRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    image.draw(
        in: target,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}

func font(_ name: String, _ size: CGFloat, fallbackWeight: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
}

func drawText(
    _ text: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    NSAttributedString(
        string: text,
        attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    ).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func roundedFill(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func writeJPEG(_ image: NSImage, to path: String, quality: CGFloat = 0.94) throws {
    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff),
          let data = representation.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
        throw RenderError.jpeg(path)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

func renderPin(_ pin: PinVisual, brand: Brand, base: URL) throws -> NSImage {
    let brandAccent = try parseHex(brand.accent ?? "#8F2635")
    let accent = try parseHex(pin.accent ?? brand.accent ?? "#8F2635")
    let dark = pin.dark ?? false
    let ink = try parseHex(pin.ink ?? (dark ? "#FFFAF1" : brand.ink ?? "#26352E"))
    let background = try loadImage(resolve(pin.background, relativeTo: base))
    let product = try loadImage(resolve(pin.product, relativeTo: base))
    let result = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))

    result.lockFocusFlipped(true)
    drawAspectFill(background, in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

    let markText = (brand.mark?.isEmpty == false ? brand.mark! : String(brand.name.prefix(1))).uppercased()
    let markRect = NSRect(x: 82, y: 58, width: 42, height: 42)
    brandAccent.setStroke()
    let markPath = NSBezierPath(ovalIn: markRect)
    markPath.lineWidth = 3
    markPath.stroke()
    drawText(markText, rect: NSRect(x: 82, y: 63, width: 42, height: 32), font: font("Georgia-Bold", 27, fallbackWeight: .bold), color: accent, alignment: .center)
    drawText(brand.name.uppercased(), rect: NSRect(x: 141, y: 62, width: 460, height: 34), font: font("AvenirNext-DemiBold", 29, fallbackWeight: .bold), color: ink)

    let badgeFont = font("AvenirNext-DemiBold", 22, fallbackWeight: .bold)
    let badgeWidth = min(650, pin.badge.size(withAttributes: [.font: badgeFont]).width + 42)
    let badgeRect = NSRect(x: 82, y: 132, width: badgeWidth, height: 48)
    roundedFill(badgeRect, radius: 24, color: dark ? NSColor.black.withAlphaComponent(0.42) : NSColor.white.withAlphaComponent(0.87))
    accent.setStroke()
    let badgeStroke = NSBezierPath(roundedRect: badgeRect, xRadius: 24, yRadius: 24)
    badgeStroke.lineWidth = 2
    badgeStroke.stroke()
    drawText(pin.badge, rect: NSRect(x: 103, y: 142, width: badgeWidth - 42, height: 29), font: badgeFont, color: ink)

    let headlineSize = CGFloat(pin.headline_size ?? 68)
    drawText(pin.headline, rect: NSRect(x: 82, y: 207, width: 836, height: 152), font: font("Georgia-Bold", headlineSize, fallbackWeight: .bold), color: ink, lineSpacing: -2)
    drawText(pin.subline, rect: NSRect(x: 86, y: 372, width: 824, height: 88), font: font("AvenirNext-DemiBold", 28, fallbackWeight: .semibold), color: ink, lineSpacing: 2)

    let card = NSRect(x: 82, y: 485, width: 836, height: 714)
    roundedFill(card, radius: 44, color: NSColor.white.withAlphaComponent(0.94))
    let photo = card.insetBy(dx: 12, dy: 12)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: photo, xRadius: 33, yRadius: 33).addClip()
    drawAspectFill(product, in: photo)
    NSGraphicsContext.restoreGraphicsState()

    let labelFont = font("AvenirNext-DemiBold", 22, fallbackWeight: .bold)
    let labelWidth = min(575, pin.label.size(withAttributes: [.font: labelFont]).width + 42)
    let labelRect = NSRect(x: card.maxX - labelWidth - 27, y: card.maxY - 68, width: labelWidth, height: 42)
    roundedFill(labelRect, radius: 21, color: NSColor.white.withAlphaComponent(0.93))
    drawText(pin.label, rect: NSRect(x: labelRect.minX + 20, y: labelRect.minY + 9, width: labelWidth - 40, height: 27), font: labelFont, color: try parseHex("#29302C"))

    let ctaRect = NSRect(x: 82, y: 1253, width: 365, height: 72)
    roundedFill(ctaRect, radius: 22, color: accent)
    drawText((brand.cta ?? "Mehr entdecken") + "  →", rect: NSRect(x: 109, y: 1274, width: 322, height: 34), font: font("AvenirNext-DemiBold", 27, fallbackWeight: .bold), color: .white)

    roundedFill(NSRect(x: 570, y: 1247, width: 348, height: 84), radius: 20, color: dark ? NSColor.black.withAlphaComponent(0.48) : NSColor.white.withAlphaComponent(0.78))
    drawText(pin.meta_strong, rect: NSRect(x: 600, y: 1259, width: 318, height: 32), font: font("AvenirNext-DemiBold", 25, fallbackWeight: .bold), color: ink, alignment: .right)
    drawText(pin.meta_text, rect: NSRect(x: 600, y: 1292, width: 318, height: 30), font: font("AvenirNext-DemiBold", 20, fallbackWeight: .semibold), color: ink, alignment: .right)

    roundedFill(NSRect(x: 70, y: 1399, width: 860, height: 43), radius: 18, color: dark ? NSColor.black.withAlphaComponent(0.42) : NSColor.white.withAlphaComponent(0.66))
    drawText(pin.proof, rect: NSRect(x: 82, y: 1408, width: 836, height: 30), font: font("AvenirNext-DemiBold", 19, fallbackWeight: .semibold), color: ink.withAlphaComponent(0.8))

    result.unlockFocus()
    return result
}

func main() throws {
    guard let configArgument = argument("--config"), let outputArgument = argument("--out") else {
        throw RenderError.usage
    }

    let configURL = URL(fileURLWithPath: configArgument).standardizedFileURL
    let base = configURL.deletingLastPathComponent()
    let outputURL = URL(fileURLWithPath: outputArgument).standardizedFileURL
    let contactURL = URL(fileURLWithPath: argument("--contact-sheet") ?? base.appendingPathComponent("contact-sheet.jpg").path).standardizedFileURL
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let config = try JSONDecoder().decode(VisualConfig.self, from: Data(contentsOf: configURL))
    if config.pins.isEmpty { throw RenderError.usage }

    var rendered: [NSImage] = []
    for pin in config.pins {
        let image = try renderPin(pin, brand: config.brand, base: base)
        rendered.append(image)
        try writeJPEG(image, to: outputURL.appendingPathComponent("\(pin.id).jpg").path)
    }

    let columns = min(3, max(1, rendered.count))
    let rows = Int(ceil(Double(rendered.count) / Double(columns)))
    let cardWidth = 600
    let cardHeight = 900
    let margin = 60
    let header = 120
    let rowGap = 50
    let sheetWidth = columns * cardWidth + (columns + 1) * margin
    let sheetHeight = header + rows * cardHeight + (rows + 1) * rowGap
    let sheet = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))
    sheet.lockFocusFlipped(true)
    (try parseHex("#F4EFE7")).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)).fill()
    let headerFontSize: CGFloat = columns == 1 ? 32 : 42
    drawText("\(config.brand.name) · Pinterest-Pins", rect: NSRect(x: margin, y: 32, width: sheetWidth - 2 * margin, height: 54), font: font("Georgia-Bold", headerFontSize, fallbackWeight: .bold), color: try parseHex(config.brand.ink ?? "#26352E"))

    for (index, image) in rendered.enumerated() {
        let column = index % columns
        let row = index / columns
        let rect = NSRect(
            x: margin + column * (cardWidth + margin),
            y: header + row * (cardHeight + rowGap),
            width: cardWidth,
            height: cardHeight
        )
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
    sheet.unlockFocus()
    try writeJPEG(sheet, to: contactURL.path, quality: 0.91)

    let response = RenderResult(ok: true, pins: rendered.count, output_dir: outputURL.path, contact_sheet: contactURL.path)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(data: try encoder.encode(response), encoding: .utf8)!)
}

do {
    try main()
} catch {
    FileHandle.standardError.write(("render_pins: \(error)\n").data(using: .utf8)!)
    exit(1)
}
