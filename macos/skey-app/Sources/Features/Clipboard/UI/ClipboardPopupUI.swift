import AppKit
import SwiftUI

// MARK: - Clipboard Popup Design System Constants

public enum ClipboardPopupUI {
    public static let verticalSeparatorPadding: CGFloat = 6
    public static let horizontalSeparatorPadding: CGFloat = 6
    public static let verticalPadding: CGFloat = 5
    public static let horizontalPadding: CGFloat = 5
    public static let minimumPreviewHeight: CGFloat = 150

    public static let cornerRadius: CGFloat = 7
    public static let itemHeight: CGFloat = 28

    public static let menuWidth: CGFloat = 460
    public static let minimumContentWidth: CGFloat = 220
    public static let minimumSlideoutWidth: CGFloat = 220
    public static let maximumSlideoutWidth: CGFloat = 460
    public static let defaultSlideoutWidth: CGFloat = 440
    public static let windowHeight: CGFloat = 750

    public static let largeTextThreshold = 1_000

    public static func totalWidth(isPreviewOpen: Bool, slideoutWidth: CGFloat) -> CGFloat {
        menuWidth + (isPreviewOpen ? slideoutWidth : 0)
    }
}

// MARK: - Lightweight Throttler

public final class Throttler: @unchecked Sendable {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval
    private let queue: DispatchQueue

    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    public func throttle(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        queue.asyncAfter(deadline: DispatchTime.now() + delay, execute: item)
    }

    public func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

// MARK: - Color Swatch Helper

public enum ColorImage {
    public static func from(_ colorHex: String) -> NSImage? {
        guard let color = NSColor(hexString: colorHex) else { return nil }
        let image = NSImage(size: NSSize(width: 12, height: 12))
        image.lockFocus()
        color.drawSwatch(in: NSRect(x: 0, y: 0, width: 12, height: 12))
        image.unlockFocus()
        return image
    }
}

public extension NSColor {
    convenience init?(hexString raw: String) {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hex.hasPrefix("#") {
            hex.removeFirst()
        } else if hex.hasPrefix("0x") {
            hex.removeFirst(2)
        }
        guard [3, 4, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        switch hex.count {
        case 6:
            self.init(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        default:
            self.init(
                red: CGFloat((value >> 24) & 0xFF) / 255,
                green: CGFloat((value >> 16) & 0xFF) / 255,
                blue: CGFloat((value >> 8) & 0xFF) / 255,
                alpha: CGFloat(value & 0xFF) / 255
            )
        }
    }
}

// MARK: - Visual Effect View

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .popover
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    public init(material: NSVisualEffectView.Material = .popover, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

public extension View {
    @ViewBuilder
    func invisible(_ invisible: Bool) -> some View {
        if invisible {
            hidden()
        } else {
            self
        }
    }
}
