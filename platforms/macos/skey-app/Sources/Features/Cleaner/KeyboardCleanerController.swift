import AppKit
import Combine
import CoreGraphics
import SwiftUI

// MARK: - CleanerBackgroundMode

public enum CleanerBackgroundMode: String, CaseIterable, Identifiable {
    case transparent = "transparent"
    case glassBlur = "glassBlur"
    case blackScreen = "blackScreen"
    case whiteScreen = "whiteScreen"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .transparent: return L10n("cleaner.mode.transparent")
        case .glassBlur:   return L10n("cleaner.mode.glassBlur")
        case .blackScreen: return L10n("cleaner.mode.blackScreen")
        case .whiteScreen: return L10n("cleaner.mode.whiteScreen")
        }
    }

    public var icon: String {
        switch self {
        case .transparent: return "eye.fill"
        case .glassBlur:   return "circle.hexagongrid.fill"
        case .blackScreen: return "moon.fill"
        case .whiteScreen: return "sun.max.fill"
        }
    }
}

// MARK: - KeyboardCleanerController

@MainActor
public final class KeyboardCleanerController: ObservableObject {
    public static let shared = KeyboardCleanerController()

    @Published public var isLocked = false
    @Published public var unlockProgress: CGFloat = 0.0
    @Published public var isHoldingEsc = false
    @Published public var backgroundMode: CleanerBackgroundMode = .transparent

    private var hudWindow: NSPanel?
    private var backdropWindows: [NSWindow] = []
    private var eventMonitor: Any?
    private var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var escHoldTimer: Timer?
    private var escHoldStartTime: Date?
    private let requiredHoldDuration: TimeInterval = 2.0

    private init() {}

    public func startCleaning() {
        guard !isLocked else { return }
        isLocked = true
        unlockProgress = 0.0
        isHoldingEsc = false
        backgroundMode = .transparent

        updateWindowsForMode()

        // 1. Install local event monitor to intercept keys directed to app windows
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]) { [weak self] event in
            self?.handleNSEvent(event)
            return nil // Block 100% of key events locally
        }

        // 2. Install hardware-level CGEventTap (.cgHIDEventTap) to block ALL keys including top-row media/brightness/volume
        installHardwareEventTap()
    }

    public func setBackgroundMode(_ mode: CleanerBackgroundMode) {
        self.backgroundMode = mode
        updateWindowsForMode()
    }

    private func updateWindowsForMode() {
        // Clear previous backdrop windows
        for window in backdropWindows {
            window.orderOut(nil)
        }
        backdropWindows.removeAll()

        // If in Glass Blur, Black Screen, or White Screen mode, create full-screen backdrop overlay windows
        if backgroundMode != .transparent {
            backdropWindows = NSScreen.screens.map { screen in
                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .fullSizeContentView],
                    backing: .buffered,
                    defer: false,
                    screen: screen
                )
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.ignoresMouseEvents = false
                window.contentView = NSHostingView(
                    rootView: ZStack {
                        if backgroundMode == .glassBlur {
                            VisualEffectBlurView(material: .fullScreenUI, blendingMode: .behindWindow)
                                .overlay(Color.black.opacity(0.65))
                                .ignoresSafeArea()
                        } else if backgroundMode == .blackScreen {
                            Color.black
                                .ignoresSafeArea()
                        } else if backgroundMode == .whiteScreen {
                            Color.white
                                .ignoresSafeArea()
                        }
                    }
                )
                window.makeKeyAndOrderFront(nil)
                return window
            }
        }

        // Create or update Floating Island HUD Window
        if hudWindow == nil {
            guard let mainScreen = NSScreen.main else { return }
            let hudWidth: CGFloat = 540
            let hudHeight: CGFloat = 60
            let xPos = (mainScreen.frame.width - hudWidth) / 2 + mainScreen.frame.minX
            let yPos = (mainScreen.frame.height - hudHeight) / 2 + mainScreen.frame.minY

            let panel = NSPanel(
                contentRect: NSRect(x: xPos, y: yPos, width: hudWidth, height: hudHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = NSColor.clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.isMovableByWindowBackground = true
            panel.isMovable = true

            let hostingView = NSHostingView(rootView: KeyboardCleanerView(controller: self))
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = hostingView
            self.hudWindow = panel
        }

        hudWindow?.makeKeyAndOrderFront(nil)
    }

    private func installHardwareEventTap() {
        let eventMask: UInt64 = (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.keyUp.rawValue) |
                                (1 << CGEventType.flagsChanged.rawValue) |
                                (1 << 14) // kCGEventSystemDefined

        let observer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return nil }
                let controller = Unmanaged<KeyboardCleanerController>.fromOpaque(refcon).takeUnretainedValue()

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                DispatchQueue.main.async {
                    if type == .keyDown {
                        if keyCode == 53 { // ESC
                            if !controller.isHoldingEsc {
                                controller.startEscHold()
                            }
                        } else {
                            controller.resetEscHold()
                        }
                    } else if type == .keyUp {
                        if keyCode == 53 {
                            controller.resetEscHold()
                        }
                    }
                }

                // Discard 100% of all keyboard and system media/brightness keystrokes
                return nil
            },
            userInfo: observer
        ) else { return }

        self.eventTapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleNSEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == 53 { // ESC
                if !isHoldingEsc {
                    startEscHold()
                }
            } else {
                resetEscHold()
            }
        } else if event.type == .keyUp {
            if event.keyCode == 53 {
                resetEscHold()
            }
        }
    }

    private func startEscHold() {
        isHoldingEsc = true
        escHoldStartTime = Date()
        escHoldTimer?.invalidate()

        escHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self = self, let start = self.escHoldStartTime else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(start)
                let progress = min(CGFloat(elapsed / self.requiredHoldDuration), 1.0)
                self.unlockProgress = progress

                if elapsed >= self.requiredHoldDuration {
                    timer.invalidate()
                    self.unlockAndClose()
                }
            }
        }
    }

    private func resetEscHold() {
        isHoldingEsc = false
        escHoldStartTime = nil
        escHoldTimer?.invalidate()
        escHoldTimer = nil
        unlockProgress = 0.0
    }

    public func unlockAndClose() {
        resetEscHold()
        isLocked = false

        if let tap = eventTapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTapPort = nil
            runLoopSource = nil
        }

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        hudWindow?.orderOut(nil)
        hudWindow = nil

        for window in backdropWindows {
            window.orderOut(nil)
        }
        backdropWindows.removeAll()
    }
}
