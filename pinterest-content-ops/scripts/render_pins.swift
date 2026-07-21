#!/usr/bin/env swift

import AppKit
import Foundation
import Darwin

struct Brand: Decodable {
    let name: String
    let mark: String?
    let accent: String?
    let ink: String?
    let light: String?
    let secondary: String?
    let highlight: String?
    let domain: String?
    let cta: String?
}

struct PinVisual: Decodable {
    let id: String
    let template: String?
    let background: String?
    let product: String
    let badge: String
    let headline: String
    let subline: String
    let label: String
    let meta_strong: String
    let meta_text: String
    let proof: String
    let stat_value: String?
    let stat_label: String?
    let card_kicker: String?
    let headline_size: Double?
    let dark: Bool?
    let accent: String?
    let ink: String?
    let light: String?
    let secondary: String?
    let highlight: String?
    let image_focus_x: Double?
    let image_focus_y: Double?
}

struct VisualConfig: Decodable {
    let brand: Brand
    let pins: [PinVisual]
}

struct RenderResult: Encodable {
    let ok: Bool
    let pins: Int
    let templates: [String: Int]
    let output_dir: String
    let contact_sheet: String
}

enum PinTemplate: String {
    case editorial
    case boldPhoto = "bold_photo"
    case recipeCard = "recipe_card"
    case classic
}

enum RenderError: Error, CustomStringConvertible {
    case usage
    case missingImage(String)
    case invalidColor(String)
    case invalidTemplate(String)
    case textOverflow(String)
    case jpeg(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: render_pins.swift --config visuals.json --out pins [--contact-sheet contact-sheet.jpg]"
        case .missingImage(let path):
            return "image not found or unreadable: \(path)"
        case .invalidColor(let value):
            return "invalid hex color: \(value)"
        case .invalidTemplate(let value):
            return "unsupported template '\(value)'; expected editorial, bold_photo, recipe_card, or classic"
        case .textOverflow(let value):
            return "text does not fit above the template minimum; shorten it: \(value)"
        case .jpeg(let path):
            return "could not write JPEG: \(path)"
        }
    }
}

let canvasWidth = 1000
let canvasHeight = 1500
let outerMargin: CGFloat = 70
let componentPadding: CGFloat = 28

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

func font(_ name: String, _ size: CGFloat, fallbackWeight: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
}

func paragraph(alignment: NSTextAlignment, lineSpacing: CGFloat) -> NSMutableParagraphStyle {
    let result = NSMutableParagraphStyle()
    result.alignment = alignment
    result.lineBreakMode = .byWordWrapping
    result.lineSpacing = lineSpacing
    return result
}

func textAttributes(
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment,
    lineSpacing: CGFloat,
    kern: CGFloat
) -> [NSAttributedString.Key: Any] {
    [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment: alignment, lineSpacing: lineSpacing),
        .kern: kern
    ]
}

func drawText(
    _ value: String,
    rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0,
    kern: CGFloat = 0
) {
    NSAttributedString(
        string: value,
        attributes: textAttributes(font: font, color: color, alignment: alignment, lineSpacing: lineSpacing, kern: kern)
    ).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

@discardableResult
func drawFittedText(
    _ value: String,
    rect: NSRect,
    fontName: String,
    preferredSize: CGFloat,
    minimumSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0,
    kern: CGFloat = 0
) throws -> CGFloat {
    var size = preferredSize
    var fits = false
    while size >= minimumSize {
        let candidate = font(fontName, size, fallbackWeight: weight)
        let attributed = NSAttributedString(
            string: value,
            attributes: textAttributes(font: candidate, color: color, alignment: alignment, lineSpacing: lineSpacing, kern: kern)
        )
        let storage = NSTextStorage(attributedString: attributed)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: rect.size)
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let visibleGlyphs = manager.glyphRange(for: container)
        if NSMaxRange(visibleGlyphs) == manager.numberOfGlyphs {
            fits = true
            break
        }
        size -= 1
    }
    guard fits else { throw RenderError.textOverflow(value) }
    drawText(value, rect: rect, font: font(fontName, size, fallbackWeight: weight), color: color, alignment: alignment, lineSpacing: lineSpacing, kern: kern)
    return size
}

func roundedFill(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawLine(from: NSPoint, to: NSPoint, color: NSColor, width: CGFloat = 2) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: from)
    path.line(to: to)
    path.lineWidth = width
    path.stroke()
}

func drawAspectFill(_ image: NSImage, in rect: NSRect, focusX: CGFloat = 0.5, focusY: CGFloat = 0.5) {
    let source = image.size
    let scale = max(rect.width / source.width, rect.height / source.height)
    let size = NSSize(width: source.width * scale, height: source.height * scale)
    let overflowX = max(0, size.width - rect.width)
    let overflowY = max(0, size.height - rect.height)
    let target = NSRect(
        x: rect.minX - overflowX * min(1, max(0, focusX)),
        y: rect.minY - overflowY * min(1, max(0, focusY)),
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

func drawClippedPhoto(_ image: NSImage, in rect: NSRect, radius: CGFloat, focusX: CGFloat, focusY: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    drawAspectFill(image, in: rect, focusX: focusX, focusY: focusY)
    NSGraphicsContext.restoreGraphicsState()
}

func drawPill(
    _ value: String,
    rect: NSRect,
    background: NSColor,
    foreground: NSColor,
    alignment: NSTextAlignment = .center,
    preferredSize: CGFloat = 21
) throws {
    roundedFill(rect, radius: rect.height / 2, color: background)
    let textRect = rect.insetBy(dx: componentPadding, dy: 11)
    try drawFittedText(value, rect: textRect, fontName: "AvenirNext-DemiBold", preferredSize: preferredSize, minimumSize: 15, weight: .bold, color: foreground, alignment: alignment, kern: 0.5)
}

func drawBrandLockup(brand: Brand, x: CGFloat, y: CGFloat, color: NSColor, compact: Bool = false) {
    let diameter: CGFloat = compact ? 38 : 44
    let mark = (brand.mark?.isEmpty == false ? brand.mark! : String(brand.name.prefix(1))).uppercased()
    color.setStroke()
    let circle = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: diameter, height: diameter))
    circle.lineWidth = 2.5
    circle.stroke()
    drawText(mark, rect: NSRect(x: x, y: y + 5, width: diameter, height: diameter - 8), font: font("Georgia-Bold", compact ? 22 : 25, fallbackWeight: .bold), color: color, alignment: .center)
    drawText(brand.name.uppercased(), rect: NSRect(x: x + diameter + 16, y: y + 5, width: 430, height: 34), font: font("AvenirNext-DemiBold", compact ? 22 : 25, fallbackWeight: .bold), color: color, kern: 1.1)
}

func writeJPEG(_ image: NSImage, to path: String, quality: CGFloat = 0.94) throws {
    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff),
          let data = representation.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
        throw RenderError.jpeg(path)
    }
    try data.write(to: URL(fileURLWithPath: path))
}

func templateFor(_ pin: PinVisual) throws -> PinTemplate {
    let raw = pin.template ?? "classic"
    guard let template = PinTemplate(rawValue: raw) else { throw RenderError.invalidTemplate(raw) }
    return template
}

func palette(_ pin: PinVisual, brand: Brand) throws -> (accent: NSColor, ink: NSColor, light: NSColor, secondary: NSColor, highlight: NSColor) {
    let accent = try parseHex(pin.accent ?? brand.accent ?? "#7253A6")
    let ink = try parseHex(pin.ink ?? brand.ink ?? "#312942")
    let light = try parseHex(pin.light ?? brand.light ?? "#FFF9F0")
    let secondary = try parseHex(pin.secondary ?? brand.secondary ?? "#E9DFF7")
    let highlight = try parseHex(pin.highlight ?? brand.highlight ?? "#E2A660")
    return (accent, ink, light, secondary, highlight)
}

func imageFocus(_ pin: PinVisual) -> (x: CGFloat, y: CGFloat) {
    (CGFloat(pin.image_focus_x ?? 0.5), CGFloat(pin.image_focus_y ?? 0.5))
}

func renderEditorial(_ pin: PinVisual, brand: Brand, base: URL, product: NSImage) throws -> NSImage {
    let colors = try palette(pin, brand: brand)
    let focus = imageFocus(pin)
    let result = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
    result.lockFocusFlipped(true)

    colors.light.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()
    if let background = pin.background {
        drawAspectFill(try loadImage(resolve(background, relativeTo: base)), in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    } else {
        colors.secondary.withAlphaComponent(0.58).setFill()
        NSBezierPath(ovalIn: NSRect(x: 745, y: -115, width: 380, height: 380)).fill()
        colors.highlight.withAlphaComponent(0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: -145, y: 1215, width: 390, height: 390)).fill()
    }

    drawBrandLockup(brand: brand, x: 72, y: 60, color: colors.ink)
    drawText(pin.badge.uppercased(), rect: NSRect(x: 72, y: 145, width: 720, height: 32), font: font("AvenirNext-DemiBold", 22, fallbackWeight: .bold), color: colors.accent, kern: 1.5)
    try drawFittedText(pin.headline, rect: NSRect(x: 68, y: 193, width: 860, height: 182), fontName: "Georgia-Bold", preferredSize: CGFloat(pin.headline_size ?? 69), minimumSize: 51, weight: .bold, color: colors.ink, lineSpacing: -3)
    try drawFittedText(pin.subline, rect: NSRect(x: 72, y: 383, width: 856, height: 52), fontName: "AvenirNext-Medium", preferredSize: 28, minimumSize: 21, weight: .medium, color: colors.ink.withAlphaComponent(0.78))

    let frame = NSRect(x: 72, y: 470, width: 856, height: 700)
    roundedFill(frame, radius: 52, color: .white)
    drawClippedPhoto(product, in: frame.insetBy(dx: 12, dy: 12), radius: 41, focusX: focus.x, focusY: focus.y)
    try drawPill(pin.label.uppercased(), rect: NSRect(x: 660, y: 1090, width: 230, height: 58), background: colors.light.withAlphaComponent(0.95), foreground: colors.ink)

    drawLine(from: NSPoint(x: 72, y: 1228), to: NSPoint(x: 928, y: 1228), color: colors.accent.withAlphaComponent(0.22))
    try drawFittedText(pin.proof, rect: NSRect(x: 72, y: 1260, width: 856, height: 40), fontName: "AvenirNext-DemiBold", preferredSize: 24, minimumSize: 18, weight: .bold, color: colors.ink, alignment: .center)
    roundedFill(NSRect(x: 72, y: 1342, width: 856, height: 88), radius: 28, color: colors.accent)
    drawText((brand.cta ?? "Discover more").uppercased(), rect: NSRect(x: 112, y: 1366, width: 660, height: 42), font: font("AvenirNext-DemiBold", 26, fallbackWeight: .bold), color: .white, kern: 1.3)
    drawText("→", rect: NSRect(x: 828, y: 1359, width: 60, height: 50), font: font("AvenirNext-DemiBold", 34, fallbackWeight: .bold), color: .white, alignment: .right)

    result.unlockFocus()
    return result
}

func renderBoldPhoto(_ pin: PinVisual, brand: Brand, product: NSImage) throws -> NSImage {
    let colors = try palette(pin, brand: brand)
    let focus = imageFocus(pin)
    let result = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
    result.lockFocusFlipped(true)
    drawAspectFill(product, in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight), focusX: focus.x, focusY: focus.y)

    NSGradient(colors: [colors.ink.withAlphaComponent(0.98), colors.ink.withAlphaComponent(0.82), colors.ink.withAlphaComponent(0.08)])!.draw(in: NSRect(x: 0, y: 0, width: 1000, height: 700), angle: 90)
    NSGradient(colors: [colors.ink.withAlphaComponent(0.02), colors.ink.withAlphaComponent(0.94)])!.draw(in: NSRect(x: 0, y: 930, width: 1000, height: 570), angle: 90)

    drawBrandLockup(brand: brand, x: 70, y: 58, color: .white)
    let badgeWidth = min(CGFloat(520), max(CGFloat(250), pin.badge.size(withAttributes: [.font: font("AvenirNext-DemiBold", 21, fallbackWeight: .bold)]).width + 2 * componentPadding))
    try drawPill(pin.badge.uppercased(), rect: NSRect(x: 70, y: 148, width: badgeWidth, height: 58), background: colors.highlight, foreground: colors.ink)
    try drawFittedText(pin.headline, rect: NSRect(x: 64, y: 225, width: 865, height: 265), fontName: "AvenirNext-Heavy", preferredSize: CGFloat(pin.headline_size ?? 91), minimumSize: 60, weight: .heavy, color: .white, lineSpacing: -7, kern: -1.2)
    try drawFittedText(pin.subline, rect: NSRect(x: 70, y: 490, width: 820, height: 62), fontName: "AvenirNext-DemiBold", preferredSize: 39, minimumSize: 27, weight: .bold, color: colors.secondary)

    try drawPill(pin.meta_strong.uppercased(), rect: NSRect(x: 70, y: 1260, width: 295, height: 66), background: colors.light, foreground: colors.ink)
    try drawPill(pin.label.uppercased(), rect: NSRect(x: 385, y: 1260, width: 245, height: 66), background: colors.light, foreground: colors.ink)
    roundedFill(NSRect(x: 70, y: 1350, width: 860, height: 88), radius: 44, color: colors.accent)
    drawText((brand.cta ?? "Discover more").uppercased(), rect: NSRect(x: 110, y: 1375, width: 660, height: 40), font: font("AvenirNext-DemiBold", 27, fallbackWeight: .bold), color: .white, kern: 1.5)
    drawText("→", rect: NSRect(x: 820, y: 1368, width: 64, height: 48), font: font("AvenirNext-DemiBold", 36, fallbackWeight: .bold), color: .white, alignment: .right)

    result.unlockFocus()
    return result
}

func renderRecipeCard(_ pin: PinVisual, brand: Brand, product: NSImage) throws -> NSImage {
    let colors = try palette(pin, brand: brand)
    let focus = imageFocus(pin)
    let result = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
    result.lockFocusFlipped(true)
    colors.secondary.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()
    colors.accent.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvasWidth, height: 550)).fill()

    colors.ink.withAlphaComponent(0.18).setFill()
    NSBezierPath(ovalIn: NSRect(x: 720, y: -135, width: 430, height: 430)).fill()
    colors.light.withAlphaComponent(0.16).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 775, y: -80, width: 290, height: 290))
    ring.lineWidth = 3
    ring.stroke()

    drawBrandLockup(brand: brand, x: 70, y: 58, color: .white, compact: true)
    drawText(pin.badge.uppercased(), rect: NSRect(x: 70, y: 142, width: 650, height: 32), font: font("AvenirNext-DemiBold", 22, fallbackWeight: .bold), color: colors.light, kern: 1.6)
    try drawFittedText(pin.headline, rect: NSRect(x: 65, y: 195, width: 850, height: 180), fontName: "Georgia-Bold", preferredSize: CGFloat(pin.headline_size ?? 67), minimumSize: 50, weight: .bold, color: .white, lineSpacing: -3)
    try drawFittedText(pin.subline.uppercased(), rect: NSRect(x: 70, y: 405, width: 760, height: 46), fontName: "AvenirNext-Heavy", preferredSize: 31, minimumSize: 22, weight: .heavy, color: colors.highlight, kern: 1.1)

    let photo = NSRect(x: 70, y: 500, width: 860, height: 595)
    roundedFill(photo, radius: 44, color: colors.light)
    drawClippedPhoto(product, in: photo.insetBy(dx: 12, dy: 12), radius: 34, focusX: focus.x, focusY: focus.y)

    roundedFill(NSRect(x: 70, y: 1140, width: 860, height: 218), radius: 36, color: colors.light)
    drawText((pin.card_kicker ?? "DETAILS").uppercased(), rect: NSRect(x: 108, y: 1176, width: 360, height: 30), font: font("AvenirNext-DemiBold", 20, fallbackWeight: .bold), color: colors.accent, kern: 1.4)
    try drawFittedText(pin.meta_strong, rect: NSRect(x: 108, y: 1218, width: 625, height: 44), fontName: "Georgia-Bold", preferredSize: 34, minimumSize: 25, weight: .bold, color: colors.ink)
    try drawFittedText(pin.proof, rect: NSRect(x: 108, y: 1274, width: 655, height: 34), fontName: "AvenirNext-Medium", preferredSize: 23, minimumSize: 17, weight: .medium, color: colors.ink.withAlphaComponent(0.78))

    let statValue = pin.stat_value ?? pin.meta_text
    let statLabel = pin.stat_label ?? pin.label
    roundedFill(NSRect(x: 788, y: 1180, width: 102, height: 126), radius: 28, color: colors.accent)
    try drawFittedText(statValue, rect: NSRect(x: 798, y: 1198, width: 82, height: 52), fontName: "AvenirNext-Heavy", preferredSize: 43, minimumSize: 27, weight: .heavy, color: .white, alignment: .center)
    try drawFittedText(statLabel.uppercased(), rect: NSRect(x: 798, y: 1253, width: 82, height: 34), fontName: "AvenirNext-DemiBold", preferredSize: 18, minimumSize: 13, weight: .bold, color: .white, alignment: .center, kern: 1)

    drawText((brand.domain ?? brand.name).uppercased(), rect: NSRect(x: 70, y: 1402, width: 410, height: 35), font: font("AvenirNext-DemiBold", 22, fallbackWeight: .bold), color: colors.ink, kern: 1.4)
    drawText((brand.cta ?? "Discover more").uppercased() + "  →", rect: NSRect(x: 500, y: 1398, width: 430, height: 38), font: font("AvenirNext-DemiBold", 24, fallbackWeight: .bold), color: colors.accent, alignment: .right, kern: 0.7)

    result.unlockFocus()
    return result
}

func renderClassic(_ pin: PinVisual, brand: Brand, base: URL, product: NSImage) throws -> NSImage {
    guard let backgroundPath = pin.background else { throw RenderError.missingImage("classic template requires background") }
    let colors = try palette(pin, brand: brand)
    let dark = pin.dark ?? false
    let ink = dark ? try parseHex(pin.ink ?? "#FFFAF1") : colors.ink
    let background = try loadImage(resolve(backgroundPath, relativeTo: base))
    let focus = imageFocus(pin)
    let result = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))

    result.lockFocusFlipped(true)
    drawAspectFill(background, in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    drawBrandLockup(brand: brand, x: 82, y: 58, color: ink)

    let badgeFont = font("AvenirNext-DemiBold", 22, fallbackWeight: .bold)
    let badgeWidth = min(CGFloat(650), pin.badge.size(withAttributes: [.font: badgeFont]).width + 2 * componentPadding + 20)
    let badgeRect = NSRect(x: 82, y: 132, width: badgeWidth, height: 48)
    roundedFill(badgeRect, radius: 24, color: dark ? NSColor.black.withAlphaComponent(0.42) : NSColor.white.withAlphaComponent(0.87))
    colors.accent.setStroke()
    let badgeStroke = NSBezierPath(roundedRect: badgeRect, xRadius: 24, yRadius: 24)
    badgeStroke.lineWidth = 2
    badgeStroke.stroke()
    try drawFittedText(pin.badge, rect: badgeRect.insetBy(dx: componentPadding, dy: 9), fontName: "AvenirNext-DemiBold", preferredSize: 22, minimumSize: 17, weight: .bold, color: ink)

    try drawFittedText(pin.headline, rect: NSRect(x: 82, y: 207, width: 836, height: 152), fontName: "Georgia-Bold", preferredSize: CGFloat(pin.headline_size ?? 68), minimumSize: 48, weight: .bold, color: ink, lineSpacing: -2)
    try drawFittedText(pin.subline, rect: NSRect(x: 86, y: 372, width: 824, height: 88), fontName: "AvenirNext-DemiBold", preferredSize: 28, minimumSize: 20, weight: .semibold, color: ink, lineSpacing: 2)

    let card = NSRect(x: 82, y: 485, width: 836, height: 714)
    roundedFill(card, radius: 44, color: NSColor.white.withAlphaComponent(0.94))
    drawClippedPhoto(product, in: card.insetBy(dx: 12, dy: 12), radius: 33, focusX: focus.x, focusY: focus.y)
    let labelWidth = min(CGFloat(575), pin.label.size(withAttributes: [.font: font("AvenirNext-DemiBold", 22, fallbackWeight: .bold)]).width + 2 * componentPadding)
    try drawPill(pin.label, rect: NSRect(x: card.maxX - labelWidth - 27, y: card.maxY - 68, width: labelWidth, height: 42), background: NSColor.white.withAlphaComponent(0.93), foreground: colors.ink, preferredSize: 20)

    roundedFill(NSRect(x: 82, y: 1253, width: 365, height: 72), radius: 22, color: colors.accent)
    drawText((brand.cta ?? "Discover more") + "  →", rect: NSRect(x: 109, y: 1274, width: 310, height: 34), font: font("AvenirNext-DemiBold", 27, fallbackWeight: .bold), color: .white)

    let meta = NSRect(x: 570, y: 1247, width: 348, height: 84)
    roundedFill(meta, radius: 20, color: dark ? NSColor.black.withAlphaComponent(0.48) : NSColor.white.withAlphaComponent(0.78))
    let metaText = meta.insetBy(dx: componentPadding, dy: 10)
    try drawFittedText(pin.meta_strong, rect: NSRect(x: metaText.minX, y: 1259, width: metaText.width, height: 32), fontName: "AvenirNext-DemiBold", preferredSize: 25, minimumSize: 18, weight: .bold, color: ink, alignment: .right)
    try drawFittedText(pin.meta_text, rect: NSRect(x: metaText.minX, y: 1292, width: metaText.width, height: 30), fontName: "AvenirNext-DemiBold", preferredSize: 20, minimumSize: 15, weight: .semibold, color: ink, alignment: .right)

    roundedFill(NSRect(x: 70, y: 1399, width: 860, height: 43), radius: 18, color: dark ? NSColor.black.withAlphaComponent(0.42) : NSColor.white.withAlphaComponent(0.66))
    try drawFittedText(pin.proof, rect: NSRect(x: 92, y: 1408, width: 816, height: 30), fontName: "AvenirNext-DemiBold", preferredSize: 19, minimumSize: 15, weight: .semibold, color: ink.withAlphaComponent(0.8))

    result.unlockFocus()
    return result
}

func renderPin(_ pin: PinVisual, brand: Brand, base: URL) throws -> (NSImage, PinTemplate) {
    let product = try loadImage(resolve(pin.product, relativeTo: base))
    let template = try templateFor(pin)
    let image: NSImage
    switch template {
    case .editorial:
        image = try renderEditorial(pin, brand: brand, base: base, product: product)
    case .boldPhoto:
        image = try renderBoldPhoto(pin, brand: brand, product: product)
    case .recipeCard:
        image = try renderRecipeCard(pin, brand: brand, product: product)
    case .classic:
        image = try renderClassic(pin, brand: brand, base: base, product: product)
    }
    return (image, template)
}

func templateLabel(_ template: PinTemplate) -> String {
    switch template {
    case .editorial: return "EDITORIAL"
    case .boldPhoto: return "BOLD PHOTO"
    case .recipeCard: return "RECIPE CARD"
    case .classic: return "CLASSIC"
    }
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

    var rendered: [(image: NSImage, template: PinTemplate)] = []
    var templateCounts: [String: Int] = [:]
    for pin in config.pins {
        let result = try renderPin(pin, brand: config.brand, base: base)
        rendered.append(result)
        templateCounts[result.1.rawValue, default: 0] += 1
        try writeJPEG(result.0, to: outputURL.appendingPathComponent("\(pin.id).jpg").path)
    }

    let columns = min(3, max(1, rendered.count))
    let rows = Int(ceil(Double(rendered.count) / Double(columns)))
    let cardWidth = 600
    let cardHeight = 900
    let margin = 60
    let header = 120
    let labelHeight = 48
    let rowGap = 54
    let sheetWidth = columns * cardWidth + (columns + 1) * margin
    let sheetHeight = header + rows * (labelHeight + cardHeight) + (rows + 1) * rowGap
    let sheet = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))
    sheet.lockFocusFlipped(true)
    (try parseHex("#F4EFE7")).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)).fill()
    let headerFontSize: CGFloat = columns == 1 ? 32 : 42
    drawText("\(config.brand.name) · Pinterest Pins", rect: NSRect(x: margin, y: 32, width: sheetWidth - 2 * margin, height: 54), font: font("Georgia-Bold", headerFontSize, fallbackWeight: .bold), color: try parseHex(config.brand.ink ?? "#26352E"))

    for (index, item) in rendered.enumerated() {
        let column = index % columns
        let row = index / columns
        let x = margin + column * (cardWidth + margin)
        let y = header + row * (labelHeight + cardHeight + rowGap)
        drawText(templateLabel(item.template), rect: NSRect(x: x, y: y, width: cardWidth, height: 30), font: font("AvenirNext-DemiBold", 20, fallbackWeight: .bold), color: try parseHex(config.brand.accent ?? "#8F2635"), alignment: .center, kern: 1.2)
        item.image.draw(in: NSRect(x: x, y: y + labelHeight, width: cardWidth, height: cardHeight), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }
    sheet.unlockFocus()
    try writeJPEG(sheet, to: contactURL.path, quality: 0.91)

    let response = RenderResult(ok: true, pins: rendered.count, templates: templateCounts, output_dir: outputURL.path, contact_sheet: contactURL.path)
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
