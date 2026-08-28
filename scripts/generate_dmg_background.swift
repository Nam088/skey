import Cocoa

let width: CGFloat = 600
let height: CGFloat = 380

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width * 2), // Retina 2x
    pixelsHigh: Int(height * 2),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext
context.scaleBy(x: 2, y: 2)

// Background Dark Gradient
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradientColors = [
    NSColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0).cgColor,
    NSColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0).cgColor
] as CFArray

let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])

// Inner Border
let innerRect = CGRect(x: 10, y: 10, width: width - 20, height: height - 20)
let path = CGPath(roundedRect: innerRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
context.addPath(path)
context.setStrokeColor(NSColor(white: 1.0, alpha: 0.08).cgColor)
context.setLineWidth(1.5)
context.strokePath()

// Title & Instruction
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.white
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(white: 1.0, alpha: 0.6)
]

let titleString = "Cai dat SKey cho macOS" as NSString
let subtitleString = "Keo bieu tuong SKey vao thu muc Applications de hoan tat cai dat" as NSString

let titleSize = titleString.size(withAttributes: titleAttrs)
let subtitleSize = subtitleString.size(withAttributes: subtitleAttrs)

titleString.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: height - 55), withAttributes: titleAttrs)
subtitleString.draw(at: NSPoint(x: (width - subtitleSize.width) / 2, y: height - 80), withAttributes: subtitleAttrs)

// Center Direction Arrow
let arrowY: CGFloat = 190
let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 260, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 340, y: arrowY))

// Arrow head
arrowPath.addLine(to: CGPoint(x: 325, y: arrowY + 12))
arrowPath.move(to: CGPoint(x: 340, y: arrowY))
arrowPath.addLine(to: CGPoint(x: 325, y: arrowY - 12))

context.addPath(arrowPath)
context.setStrokeColor(NSColor(red: 10/255.0, green: 132/255.0, blue: 255/255.0, alpha: 0.6).cgColor)
context.setLineWidth(3.0)
context.setLineCap(.round)
context.setLineJoin(.round)
context.strokePath()

NSGraphicsContext.restoreGraphicsState()

if let pngData = rep.representation(using: .png, properties: [:]) {
    try? FileManager.default.createDirectory(atPath: "dist/.background", withIntermediateDirectories: true)
    let url = URL(fileURLWithPath: "dist/.background/background.png")
    try? pngData.write(to: url)
    print("DMG background generated successfully: dist/.background/background.png")
}
