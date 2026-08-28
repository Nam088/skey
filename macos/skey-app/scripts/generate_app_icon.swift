import AppKit
import Foundation

// Script to render Concept B into AppIcon.iconset and build AppIcon.icns
let sizes: [(String, Int)] = [
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

func drawSKeyIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    let scale = size / 512.0
    ctx.scaleBy(x: scale, y: scale)

    // Background squircle (macOS continuous rounded rect)
    let bgRect = CGRect(x: 0, y: 0, width: 512, height: 512)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 116, cornerHeight: 116, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(red: 8/255.0, green: 9/255.0, blue: 12/255.0, alpha: 1.0))
    ctx.fillPath()

    // Flip coordinate system for SVG top-down drawing
    ctx.translateBy(x: 0, y: 512)
    ctx.scaleBy(x: 1.0, y: -1.0)

    // Top block (White)
    let topPath = CGMutablePath()
    topPath.move(to: CGPoint(x: 180, y: 136))
    topPath.addLine(to: CGPoint(x: 332, y: 136))
    topPath.addArc(tangent1End: CGPoint(x: 360, y: 136), tangent2End: CGPoint(x: 360, y: 164), radius: 24)
    topPath.addLine(to: CGPoint(x: 360, y: 212))
    topPath.addArc(tangent1End: CGPoint(x: 360, y: 240), tangent2End: CGPoint(x: 332, y: 240), radius: 24)
    topPath.addLine(to: CGPoint(x: 236, y: 240))
    topPath.addLine(to: CGPoint(x: 164, y: 168))
    topPath.addArc(tangent1End: CGPoint(x: 156, y: 160), tangent2End: CGPoint(x: 180, y: 136), radius: 18)
    topPath.closeSubpath()

    ctx.addPath(topPath)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    ctx.fillPath()

    // Bottom block (Apple Electric Blue)
    let bottomPath = CGMutablePath()
    bottomPath.move(to: CGPoint(x: 332, y: 376))
    bottomPath.addLine(to: CGPoint(x: 180, y: 376))
    bottomPath.addArc(tangent1End: CGPoint(x: 152, y: 376), tangent2End: CGPoint(x: 152, y: 348), radius: 24)
    bottomPath.addLine(to: CGPoint(x: 152, y: 300))
    bottomPath.addArc(tangent1End: CGPoint(x: 152, y: 272), tangent2End: CGPoint(x: 180, y: 272), radius: 24)
    bottomPath.addLine(to: CGPoint(x: 276, y: 272))
    bottomPath.addLine(to: CGPoint(x: 348, y: 344))
    bottomPath.addArc(tangent1End: CGPoint(x: 356, y: 352), tangent2End: CGPoint(x: 332, y: 376), radius: 18)
    bottomPath.closeSubpath()

    ctx.addPath(bottomPath)
    ctx.setFillColor(CGColor(red: 10/255.0, green: 132/255.0, blue: 255/255.0, alpha: 1.0))
    ctx.fillPath()

    img.unlockFocus()
    return img
}

let fm = FileManager.default
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().path
let iconsetDir = "\(scriptDir)/Resources/AppIcon.iconset"
let icnsPath = "\(scriptDir)/Resources/AppIcon.icns"

try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for (name, px) in sizes {
    let img = drawSKeyIcon(size: CGFloat(px))
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let filePath = "\(iconsetDir)/\(name)"
        try png.write(to: URL(fileURLWithPath: filePath))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try task.run()
task.waitUntilExit()

try? fm.removeItem(atPath: iconsetDir)
print("Successfully generated: \(icnsPath)")
