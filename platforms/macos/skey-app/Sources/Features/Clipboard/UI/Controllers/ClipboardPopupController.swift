import AppKit
import Combine
import SwiftUI

// MARK: - Floating Popup Panel Controller

@MainActor
public final class ClipboardHistoryPopupController: NSObject {
    private let store: ClipboardStore
    private var panel: FloatingPanel?
    private var previewPopover: ClipboardPreviewPopover?
    public private(set) var viewModel: ClipboardHistoryViewModel?
    private var cancellables = Set<AnyCancellable>()
    private let onPasteSelection: ([ClipboardItem], _ asPlainText: Bool) -> Void
    private let popupPositionProvider: () -> ClipboardPopupPosition
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var flagsMonitor: Any?
    private var isClosing = false

    public init(
        store: ClipboardStore,
        popupPositionProvider: @escaping () -> ClipboardPopupPosition = { AppSettings.shared.clipboard.popupPosition },
        onPasteSelection: @escaping ([ClipboardItem], _ asPlainText: Bool) -> Void
    ) {
        self.store = store
        self.popupPositionProvider = popupPositionProvider
        self.onPasteSelection = onPasteSelection
        super.init()
        setupPanelIfNeeded()
    }

    private func setupPanelIfNeeded() {
        guard panel == nil else { return }

        let vm = ClipboardHistoryViewModel(
            store: store,
            onResize: { [weak self] width, height in
                self?.resizePanel(width: width, height: height)
            },
            onSelect: { [weak self] items, asPlainText in
                self?.close()
                self?.onPasteSelection(items, asPlainText)
            }
        )
        vm.openPreferencesHandler = {
            SettingsWindowController.shared.showSettings()
        }
        self.viewModel = vm

        let initialWidth = ClipboardPopupUI.menuWidth
        let initialHeight = vm.desiredHeight

        let p = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            onClose: { [weak self] in self?.close() }
        )

        let rootView = ClipboardHistoryContentView(
            viewModel: vm,
            onClose: { [weak self] in self?.close() }
        )
        p.contentView = NSHostingView(rootView: rootView)
        p.contentView?.layer?.cornerRadius = 10
        self.panel = p

        self.previewPopover = ClipboardPreviewPopover()

        Publishers.CombineLatest3(vm.$isPreviewOpen, vm.$selectedItemID, vm.$selectedRowSwiftUIFrame)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updatePreviewPanelVisibility()
            }
            .store(in: &cancellables)
    }

    public func toggle(relativeTo button: NSStatusBarButton? = nil) {
        if let panel, panel.isVisible {
            close()
            return
        }
        show(relativeTo: button)
    }

    public func close() {
        guard !isClosing else { return }
        isClosing = true
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
        previewPopover?.close()
        panel?.orderOut(nil)
        viewModel?.searchQuery = ""
        viewModel?.isPreviewOpen = false
        isClosing = false
    }

    public func show(relativeTo button: NSStatusBarButton? = nil) {
        setupPanelIfNeeded()
        guard let panel, let viewModel else { return }

        if !viewModel.searchQuery.isEmpty {
            viewModel.searchQuery = ""
        }
        // Reset transient row/preview state on every presentation. The panel
        // is reused between toggles, so SwiftUI's onAppear is not guaranteed
        // to run again for the hosted root view.
        viewModel.resetPresentationState()

        let initialWidth = ClipboardPopupUI.menuWidth
        let initialHeight = viewModel.desiredHeight
        let origin = computeOrigin(size: NSSize(width: initialWidth, height: initialHeight), button: button)

        let screen = NSScreen.screens.first { NSMouseInRect(origin, $0.frame, false) }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect.zero
        if origin.x + ClipboardPopupUI.menuWidth + 400 > screen.maxX {
            viewModel.previewPlacement = .left
        } else {
            viewModel.previewPlacement = .right
        }

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: initialWidth, height: initialHeight), display: true, animate: false)
        panel.orderFrontRegardless()
        panel.makeKey()

        setupEventMonitors()
        updatePreviewPanelVisibility()

        Task {
            await viewModel.load()
        }
    }

    private func updatePreviewPanelVisibility() {
        guard let panel, let contentView = panel.contentView, let previewPopover, let viewModel else { return }
        if viewModel.isPreviewOpen && viewModel.activePreviewItem != nil {
            let rowRect: NSRect = {
                if let swiftUIRect = viewModel.selectedRowSwiftUIFrame {
                    let y = contentView.isFlipped ? swiftUIRect.minY : (contentView.bounds.height - swiftUIRect.maxY)
                    return NSRect(x: 0, y: y, width: contentView.bounds.width, height: swiftUIRect.height)
                }
                let activeItem = viewModel.activePreviewItem
                let itemIndex: Int = {
                    if let id = activeItem?.id, let idx = viewModel.items.firstIndex(where: { $0.id == id }) {
                        return idx
                    }
                    return 0
                }()
                let rowHeight = ClipboardPopupUI.itemHeight
                let headerOffset: CGFloat = 42
                let y: CGFloat = {
                    if contentView.isFlipped {
                        return headerOffset + CGFloat(itemIndex) * rowHeight
                    } else {
                        return max(10, panel.frame.height - headerOffset - CGFloat(itemIndex + 1) * rowHeight)
                    }
                }()
                return NSRect(x: 0, y: y, width: ClipboardPopupUI.menuWidth, height: rowHeight)
            }()

            let preferredEdge: NSRectEdge = viewModel.previewPlacement == .left ? .minX : .maxX
            previewPopover.show(
                viewModel: viewModel,
                relativeTo: rowRect,
                of: contentView,
                preferredEdge: preferredEdge,
                onClose: { [weak self] in self?.close() }
            )
        } else {
            previewPopover.close()
        }
    }

    private func computeOrigin(size: NSSize, button: NSStatusBarButton?) -> NSPoint {
        let position = popupPositionProvider()
        if position == .statusItem, let button {
            let rectInWindow = button.convert(button.bounds, to: nil)
            if let screenRect = button.window?.convertToScreen(rectInWindow) {
                let topLeftPoint = NSPoint(x: screenRect.minX, y: screenRect.minY - size.height)
                let screen = button.window?.screen ?? NSScreen.main
                return constrained(topLeftPoint, ofSize: size, to: screen)
            }
        }

        let mouseLocation = NSEvent.mouseLocation
        let point = NSPoint(x: mouseLocation.x, y: mouseLocation.y - size.height)
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        return constrained(point, ofSize: size, to: screen)
    }

    private func constrained(_ origin: NSPoint, ofSize size: NSSize, to screen: NSScreen?) -> NSPoint {
        guard let frame = screen?.visibleFrame else { return origin }
        return NSPoint(
            x: min(max(origin.x, frame.minX), frame.maxX - size.width),
            y: min(max(origin.y, frame.minY), frame.maxY - size.height)
        )
    }

    private func resizePanel(width: CGFloat, height: CGFloat) {
        guard let panel else { return }
        let currentFrame = panel.frame
        guard let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }

        let newY = currentFrame.maxY - height
        let clampedY = max(screen.minY, min(newY, screen.maxY - height))
        let newFrame = NSRect(x: currentFrame.minX, y: clampedY, width: ClipboardPopupUI.menuWidth, height: height)
        panel.setFrame(newFrame, display: true, animate: false)
        updatePreviewPanelVisibility()
    }

    private func setupEventMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if event.window != panel && event.window != self.previewPopover?.panel && event.window?.className.contains("Popover") != true {
                    self.close()
                }
                return event
            }

            let handled = Self.handleKeyDown(
                event,
                viewModel: self.viewModel,
                onClose: { self.close() }
            )
            return handled ? nil : event
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.viewModel?.currentModifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    @MainActor
    private static func handleKeyDown(
        _ event: NSEvent,
        viewModel: ClipboardHistoryViewModel?,
        onClose: @escaping () -> Void
    ) -> Bool {
        guard let viewModel else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        let keyCode = Int(event.keyCode)

        if let inputClient = NSApp.keyWindow?.firstResponder as? NSTextInputClient,
           inputClient.hasMarkedText(), keyCode == 36 || keyCode == 76 {
            return false
        }

        if viewModel.showClearConfirmation || viewModel.showClearAllConfirmation {
            if keyCode == 53 { // Escape
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.showClearConfirmation = false
                    viewModel.showClearAllConfirmation = false
                }
                return true
            }
            if keyCode == 36 || keyCode == 76 { // Return / Enter
                let isClearAll = viewModel.showClearAllConfirmation
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.showClearConfirmation = false
                    viewModel.showClearAllConfirmation = false
                }
                Task {
                    if isClearAll {
                        await viewModel.clearAll()
                    } else {
                        await viewModel.clearUnpinned()
                    }
                }
                return true
            }
        }

        switch keyCode {
        case 125, 126: // Down / Up arrow
            let delta = keyCode == 125 ? 1 : -1
            if flags.contains(.shift) {
                viewModel.extendSelection(by: delta)
            } else if flags.contains(.command) || flags.contains(.option) {
                if delta > 0 { viewModel.moveToLast() } else { viewModel.moveToFirst() }
            } else {
                viewModel.moveSelection(by: delta)
            }
            return true

        case 116, 115: // PageUp / Home
            viewModel.moveToFirst()
            return true

        case 121, 119: // PageDown / End
            viewModel.moveToLast()
            return true

        case 36, 76: // Return / Enter
            let asPlainText = flags.contains(.option) || flags.contains(.shift)
            viewModel.confirmSelection(asPlainText: asPlainText)
            return true

        case 53: // Escape
            onClose()
            return true

        case 51: // Backspace
            if flags.contains(.command) && flags.contains(.option) && flags.contains(.shift) {
                viewModel.requestClearAll()
            } else if flags.contains(.command) && flags.contains(.option) {
                viewModel.requestClear()
            } else if flags.contains(.command) {
                Task { await viewModel.deleteCurrentItem() }
            } else {
                return false
            }
            return true

        case 4 where flags == [.control]: // ⌃H
            viewModel.deleteCharFromSearch()
            return true

        case 13 where flags == [.control]: // ⌃W
            viewModel.deleteWordFromSearch()
            return true

        case 32 where flags == [.control]: // ⌃U
            viewModel.clearSearchField()
            return true

        case 35 where flags == [.option]: // ⌥P
            Task { await viewModel.togglePinCurrent() }
            return true

        case 49 where flags == [.option]: // ⌥Space
            viewModel.togglePreview()
            return true

        case 43 where flags == [.command]: // ⌘,
            viewModel.openPreferences()
            return true

        case 12 where flags == [.command]: // ⌘Q
            onClose()
            NSApp.terminate(nil)
            return true

        default:
            if (flags.contains(.command) || flags.contains(.option)),
               let chars = event.charactersIgnoringModifiers,
               let num = Int(chars), (1...9).contains(num) {
                let asPlainText = flags.contains(.option)
                viewModel.selectByIndex(num - 1, asPlainText: asPlainText)
                return true
            }
            return false
        }
    }
}
