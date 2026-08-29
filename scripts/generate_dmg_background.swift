import Cocoa

let width: CGFloat = 600
let height: CGFloat = 380

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Could not obtain graphics context")
}

// 1. Crisp Edge-to-Edge Minimalist Background (#FFFFFF to #F8F9FA)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(white: 1.0, alpha: 1.0).cgColor,
    NSColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0).cgColor
] as CFArray
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
context.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])

// 2. Headline: "Gõ Nhanh Hơn. Mượt Mà Hơn." (Modern Bold Sans-serif with Emerald & Blue Accents)
let titleFont = NSFont.systemFont(ofSize: 26, weight: .bold)

let part1Attrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
]
let part2Attrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.0, green: 0.62, blue: 0.38, alpha: 1.0) // Emerald Green
]
let part3Attrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
]
let part4Attrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Royal Blue
]

let title = NSMutableAttributedString()
title.append(NSAttributedString(string: "Gõ ", attributes: part1Attrs))
title.append(NSAttributedString(string: "Nhanh Hơn. ", attributes: part2Attrs))
title.append(NSAttributedString(string: "Mượt Mà ", attributes: part3Attrs))
title.append(NSAttributedString(string: "Hơn.", attributes: part4Attrs))

let titleSize = title.size()
let titleOrigin = NSPoint(x: (width - titleSize.width) / 2.0, y: height - 70)
title.draw(at: titleOrigin)

// 3. Subtitle: Clean Apple-style explanation
let subtitleParagraphStyle = NSMutableParagraphStyle()
subtitleParagraphStyle.alignment = .center

let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1.0),
    .paragraphStyle: subtitleParagraphStyle
]
let subtitleText = "Bộ gõ tiếng Việt thế hệ mới, mượt mà và an toàn cho macOS." as NSString
let subtitleSize = subtitleText.size(withAttributes: subtitleAttrs)
subtitleText.draw(
    in: CGRect(x: (width - subtitleSize.width) / 2.0, y: height - 100, width: subtitleSize.width, height: subtitleSize.height),
    withAttributes: subtitleAttrs
)

// 4. Clean Chevron Arrows (› › ›) exactly centered between the two icons
// In Cocoa coordinates (bottom-left = 0,0), icon Y=215 in Finder corresponds to Y = 380 - 215 = 165
let chevronY: CGFloat = 165
let chevrons = [
    CGPoint(x: 282, y: chevronY),
    CGPoint(x: 298, y: chevronY),
    CGPoint(x: 314, y: chevronY)
]

for (index, point) in chevrons.enumerated() {
    let alpha: CGFloat = 0.22 + CGFloat(index) * 0.28 // 0.22, 0.50, 0.78
    let path = CGMutablePath()
    let size: CGFloat = 8
    path.move(to: CGPoint(x: point.x - size, y: point.y + size))
    path.addLine(to: CGPoint(x: point.x, y: point.y))
    path.addLine(to: CGPoint(x: point.x - size, y: point.y - size))

    context.addPath(path)
    context.setStrokeColor(NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: alpha).cgColor)
    context.setLineWidth(3.0)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
}

image.unlockFocus()

// Output 2x Retina PNG (1200 x 760)
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData) else {
    fatalError("Failed to convert image to bitmap representation")
}

let retinaRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width * 2),
    pixelsHigh: Int(height * 2),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
retinaRep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
if let nsCtx = NSGraphicsContext(bitmapImageRep: retinaRep) {
    NSGraphicsContext.current = nsCtx
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
}
NSGraphicsContext.restoreGraphicsState()

if let pngData = retinaRep.representation(using: .png, properties: [:]) {
    try? FileManager.default.createDirectory(atPath: "dist/.background", withIntermediateDirectories: true)
    let url = URL(fileURLWithPath: "dist/.background/background.png")
    try? pngData.write(to: url)
    print("DMG background generated successfully: dist/.background/background.png")
}
