import AppKit
import Combine
import Foundation
import SwiftUI

// MARK: - ClipboardHistoryViewModel

@MainActor
public final class ClipboardHistoryViewModel: ObservableObject {
    @Published public var items: [ClipboardItem] = [] {
        didSet { updateDerivedCollections() }
    }
    @Published public private(set) var pinnedItems: [ClipboardItem] = []
    @Published public private(set) var unpinnedItems: [ClipboardItem] = []
    @Published public private(set) var displayOrder: [ClipboardItem] = []
    @Published public private(set) var indexMap: [UUID: Int] = [:]

    @Published public var selectedItemID: UUID?
    @Published public var scrollTargetID: UUID?
    @Published public var isPreviewOpen: Bool = false
    @Published public var previewPlacement: ClipboardPreviewPlacement = .right
    @Published public var slideoutWidth: CGFloat = ClipboardPopupUI.defaultSlideoutWidth
    @Published public var searchQuery: String = "" {
        didSet { scheduleSearch() }
    }
    @Published public var stackedItemIDs: [UUID] = []
    @Published public var pasteStackSelected: Bool = false
    @Published public var currentModifierFlags: NSEvent.ModifierFlags = []
    @Published public var showClearConfirmation = false
    @Published public var showClearAllConfirmation = false
    @Published public var selectedRowSwiftUIFrame: CGRect?

    public var openPreferencesHandler: (() -> Void)?
    public var onCloseForAction: (() -> Void)?

    public var settings: ClipboardSettings { AppSettings.shared.clipboard }

    public let imageCache = NSCache<NSUUID, NSImage>()
    public let appIconCache = NSCache<NSString, NSImage>()
    public let appNameCache = NSCache<NSString, NSString>()
    public let colorSwatchCache = NSCache<NSString, NSImage>()
    public let attributedTitleCache = NSCache<NSString, NSAttributedString>()
    public var missingAppIcons = Set<String>()
    public let hoverThrottler = Throttler(delay: 0.03)
    public var searchTask: Task<Void, Never>?
    public var preloadTask: Task<Void, Never>?
    public var autoPreviewTask: Task<Void, Never>?
    public var eventsTask: Task<Void, Never>?
    public let store: ClipboardStore
    public let onResize: (CGFloat, CGFloat) -> Void
    public let onSelect: ([ClipboardItem], _ asPlainText: Bool) -> Void

    public init(
        store: ClipboardStore,
        onResize: @escaping (CGFloat, CGFloat) -> Void,
        onSelect: @escaping ([ClipboardItem], _ asPlainText: Bool) -> Void
    ) {
        self.store = store
        self.onResize = onResize
        self.onSelect = onSelect
        imageCache.countLimit = 100
        colorSwatchCache.countLimit = 100
        attributedTitleCache.countLimit = 200

        // Listen for live store events
        eventsTask = Task { [weak self, store] in
            for await event in store.events {
                guard !Task.isCancelled else { break }
                self?.handleStoreEvent(event)
            }
        }

        // Eagerly pre-warm cache
        Task { [weak self] in
            await self?.load()
        }
    }

    deinit {
        searchTask?.cancel()
        preloadTask?.cancel()
        autoPreviewTask?.cancel()
        eventsTask?.cancel()
    }

    // MARK: - Derived Collections

    public func updateDerivedCollections() {
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        self.pinnedItems = pinned
        self.unpinnedItems = unpinned
        let ordered = settings.pinTo == .bottom
            ? unpinned + pinned
            : pinned + unpinned
        self.displayOrder = ordered
        self.indexMap = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($0.element.id, $0.offset) })
    }

    private func handleStoreEvent(_ event: ClipboardEvent) {
        guard searchQuery.isEmpty else { return }
        switch event {
        case .added(let item):
            items.removeAll(where: { $0.id == item.id })
            items.insert(item, at: 0)
        case .removed(let itemID):
            items.removeAll(where: { $0.id == itemID })
        case .clearedAll:
            items.removeAll()
        case .updated(let item):
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = item
            }
        }
        updateDerivedCollections()
        if selectedItemID == nil || !items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = items.first?.id
        }
    }

    // MARK: - Derived State

    public var activePreviewItem: ClipboardItem? {
        if pasteStackSelected { return nil }
        guard let selectedItemID else { return items.first }
        return items.first(where: { $0.id == selectedItemID }) ?? items.first
    }

    public var desiredHeight: CGFloat {
        let headerHeight: CGFloat = 42
        let footerHeight: CGFloat = settings.showFooter ? 140 : 0
        let pinsCount = pinnedItems.count
        let stackCount = stackedItemIDs.isEmpty ? 0 : 1

        if items.isEmpty {
            let emptyStateHeight: CGFloat = 70
            let total = headerHeight + emptyStateHeight + footerHeight
            return min(max(total, settings.showFooter ? 260 : 120), ClipboardPopupUI.windowHeight)
        }

        let imageRowHeight = CGFloat(max(50, settings.imageThumbnailHeight)) + 8
        var totalContentHeight: CGFloat = 0
        for item in items {
            if item.contentType == .image {
                totalContentHeight += imageRowHeight
            } else {
                totalContentHeight += ClipboardPopupUI.itemHeight
            }
        }
        if stackCount > 0 {
            totalContentHeight += ClipboardPopupUI.itemHeight
        }

        let separatorsHeight = (pinsCount > 0 ? 22.0 : 0.0) + 16.0
        let total = headerHeight + totalContentHeight + separatorsHeight + footerHeight

        let maxAvailableHeight: CGFloat = {
            if let screen = NSScreen.main {
                return min(screen.visibleFrame.height - 60, ClipboardPopupUI.windowHeight)
            }
            return ClipboardPopupUI.windowHeight
        }()

        let minHeight: CGFloat = settings.showFooter ? 240 : 100
        return min(max(total, minHeight), maxAvailableHeight)
    }

    public var pasteStackItems: [ClipboardItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return stackedItemIDs.compactMap { itemsByID[$0] }
    }

    public var clearAllModifiersPressed: Bool {
        let clearModifiers: NSEvent.ModifierFlags = [.command, .option]
        let clearAllModifiers: NSEvent.ModifierFlags = [.command, .option, .shift]
        return !currentModifierFlags.isEmpty
            && !currentModifierFlags.isSubset(of: clearModifiers)
            && currentModifierFlags.isSubset(of: clearAllModifiers)
    }

    // MARK: - Actions

    public func togglePreview() {
        autoPreviewTask?.cancel()
        isPreviewOpen.toggle()
        resize()
    }

    public func setSlideoutWidth(_ width: CGFloat) {
        slideoutWidth = min(max(width, ClipboardPopupUI.minimumSlideoutWidth), ClipboardPopupUI.maximumSlideoutWidth)
        resize()
    }

    public func resize() {
        onResize(
            ClipboardPopupUI.menuWidth,
            desiredHeight
        )
    }

    // MARK: - Data Loading & Search

    public func load() async {
        await search(query: searchQuery)
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.search(query: query)
        }
    }

    public func search(query: String) async {
        let fetched = (try? await store.fetchHistory(matching: query)) ?? []
        guard !Task.isCancelled, query == searchQuery else { return }
        items = fetched
        if selectedItemID == nil || !items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = items.first?.id
        }
        resize()

        preloadTask?.cancel()
        preloadTask = Task(priority: .background) { [weak self, fetched, store] in
            for item in fetched.prefix(15) where item.contentType == .image && item.hasFullPayload {
                guard !Task.isCancelled else { return }
                if let data = await store.loadPayloadData(for: item), let img = NSImage(data: data) {
                    guard !Task.isCancelled else { return }
                    self?.imageCache.setObject(img, forKey: item.id as NSUUID)
                }
            }
        }
    }
}
