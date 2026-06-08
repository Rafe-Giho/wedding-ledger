import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let assetDirectory = root.appendingPathComponent("assets/app-icon", isDirectory: true)
let iconsetDirectory = assetDirectory.appendingPathComponent("WeddingLedger.iconset", isDirectory: true)
let icnsURL = assetDirectory.appendingPathComponent("WeddingLedger.icns")
let previewURL = assetDirectory.appendingPathComponent("WeddingLedger-1024.png")

try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawLine(from start: CGPoint, to end: CGPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

func drawIcon(size: CGFloat, to url: URL) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let padding = size * 0.055
    let backgroundRect = rect.insetBy(dx: padding, dy: padding)
    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: size * 0.21,
        yRadius: size * 0.21
    )
    NSGradient(colors: [
        color(24, 21, 18),
        color(47, 39, 31),
        color(16, 15, 14)
    ])?.draw(in: backgroundPath, angle: -36)

    color(224, 184, 116, 0.34).setStroke()
    backgroundPath.lineWidth = max(2, size * 0.012)
    backgroundPath.stroke()

    let glowPath = NSBezierPath(ovalIn: NSRect(x: size * 0.16, y: size * 0.61, width: size * 0.42, height: size * 0.25))
    color(235, 194, 128, 0.16).setFill()
    glowPath.fill()

    let bookRect = NSRect(x: size * 0.245, y: size * 0.235, width: size * 0.51, height: size * 0.56)
    let bookPath = NSBezierPath(roundedRect: bookRect, xRadius: size * 0.055, yRadius: size * 0.055)
    color(247, 237, 213).setFill()
    bookPath.fill()
    color(178, 126, 54).setStroke()
    bookPath.lineWidth = max(2, size * 0.014)
    bookPath.stroke()

    let spineX = bookRect.minX + bookRect.width * 0.18
    drawLine(
        from: CGPoint(x: spineX, y: bookRect.minY + size * 0.04),
        to: CGPoint(x: spineX, y: bookRect.maxY - size * 0.04),
        width: max(2, size * 0.012),
        color: color(184, 133, 65, 0.62)
    )

    let envelopeRect = NSRect(x: bookRect.minX + size * 0.15, y: bookRect.minY + size * 0.14, width: size * 0.25, height: size * 0.15)
    let envelopePath = NSBezierPath(roundedRect: envelopeRect, xRadius: size * 0.018, yRadius: size * 0.018)
    color(255, 250, 236).setFill()
    envelopePath.fill()
    color(178, 126, 54).setStroke()
    envelopePath.lineWidth = max(1.5, size * 0.009)
    envelopePath.stroke()
    drawLine(from: CGPoint(x: envelopeRect.minX, y: envelopeRect.maxY), to: CGPoint(x: envelopeRect.midX, y: envelopeRect.midY), width: max(1, size * 0.006), color: color(178, 126, 54, 0.72))
    drawLine(from: CGPoint(x: envelopeRect.maxX, y: envelopeRect.maxY), to: CGPoint(x: envelopeRect.midX, y: envelopeRect.midY), width: max(1, size * 0.006), color: color(178, 126, 54, 0.72))

    let wonText = "₩"
    let wonAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.205, weight: .heavy),
        .foregroundColor: color(88, 63, 35)
    ]
    let wonSize = wonText.size(withAttributes: wonAttributes)
    wonText.draw(
        at: CGPoint(x: bookRect.midX - wonSize.width * 0.35, y: bookRect.midY - wonSize.height * 0.39),
        withAttributes: wonAttributes
    )

    let ribbon = NSBezierPath()
    ribbon.move(to: CGPoint(x: bookRect.maxX - size * 0.13, y: bookRect.maxY - size * 0.01))
    ribbon.line(to: CGPoint(x: bookRect.maxX - size * 0.055, y: bookRect.maxY - size * 0.01))
    ribbon.line(to: CGPoint(x: bookRect.maxX - size * 0.055, y: bookRect.minY + size * 0.12))
    ribbon.line(to: CGPoint(x: bookRect.maxX - size * 0.092, y: bookRect.minY + size * 0.075))
    ribbon.line(to: CGPoint(x: bookRect.maxX - size * 0.13, y: bookRect.minY + size * 0.12))
    ribbon.close()
    color(196, 135, 54).setFill()
    ribbon.fill()

    let sparkleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.083, weight: .bold),
        .foregroundColor: color(235, 194, 128)
    ]
    "✦".draw(at: CGPoint(x: size * 0.285, y: size * 0.705), withAttributes: sparkleAttributes)

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG 데이터를 생성하지 못했습니다."])
    }
    try data.write(to: url)
}

let iconSpecs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in iconSpecs {
    try drawIcon(size: size, to: iconsetDirectory.appendingPathComponent(filename))
}
try drawIcon(size: 1024, to: previewURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil 실행에 실패했습니다."])
}

print(icnsURL.path)
