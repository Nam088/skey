import AppKit
import SwiftUI

// MARK: - ShortcutRecorderView

public struct ShortcutRecorderView: View {
    @Binding public var shortcut: KeyShortcut
    public var onShortcutChanged: ((KeyShortcut) -> Void)?

    @State private var isRecording: Bool = false
    @State private var liveModifiers: ShortcutModifiers = []
    @State private var eventMonitor: Any? = nil
    @State private var peakModifierChord: ShortcutModifiers = []
    @State private var isHovered: Bool = false
    @State private var pulseAnimation: Bool = false

    public init(
        shortcut: Binding<KeyShortcut>,
        onShortcutChanged: ((KeyShortcut) -> Void)? = nil
    ) {
        self._shortcut = shortcut
        self.onShortcutChanged = onShortcutChanged
    }

    public var body: some View {
        Button {
            if !isRecording {
                startRecording()
            }
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    // Recording Active State
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6.5, height: 6.5)
                            .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                            .opacity(pulseAnimation ? 1.0 : 0.5)
                            .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                            .onAppear { pulseAnimation = true }

                        if liveModifiers.isEmpty {
                            Text(L10n("shortcut.recording.prompt"))
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(.primary)
                        } else {
                            HStack(spacing: 3) {
                                ForEach(liveModifiers.symbolList, id: \.self) { symbol in
                                    KeyCapBadge(symbol, isHighlighted: true)
                                }
                                Text("...")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.accentColor)
                            }
                        }

                        Spacer(minLength: 4)

                        Button {
                            stopRecording()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(L10n("common.cancel"))
                    }
                    .frame(minWidth: 155)
                } else {
                    // Resting State with KeyCaps
                    HStack(spacing: 4) {
                        ForEach(shortcut.keycapSymbols, id: \.self) { symbol in
                            KeyCapBadge(symbol)
                        }

                        if isHovered {
                            Image(systemName: "pencil")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.accentColor)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isRecording
                            ? Color.accentColor.opacity(0.08)
                            : (isHovered ? Color(NSColor.controlAccentColor).opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.4))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        isRecording
                            ? Color.accentColor
                            : (isHovered ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.4)),
                        lineWidth: isRecording ? 1.5 : 0.8
                    )
                    .shadow(color: isRecording ? Color.accentColor.opacity(0.25) : Color.clear, radius: 3)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(isRecording ? L10n("shortcut.pressEscToCancel") : L10n("shortcut.clickToRecord"))
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Recording Actions

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        pulseAnimation = true
        liveModifiers = []
        peakModifierChord = []

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            return self.handleRecordingEvent(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        pulseAnimation = false
        liveModifiers = []
        peakModifierChord = []
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleRecordingEvent(_ event: NSEvent) -> NSEvent? {
        let mods = ShortcutModifiers(nsFlags: event.modifierFlags)

        // 1. Escape without modifiers cancels recording
        if event.type == .keyDown && event.keyCode == KeyConstants.kVK_Escape && mods.isEmpty {
            stopRecording()
            return nil
        }

        // 2. Flags Changed (Modifier keys held/released)
        if event.type == .flagsChanged {
            liveModifiers = mods

            if !mods.isEmpty {
                // Accumulate any modifier pressed in this chord (e.g. Option, then Shift)
                peakModifierChord.formUnion(mods)
            } else if !peakModifierChord.isEmpty {
                // All modifiers were released without a standard key -> Modifier-only chord!
                let count = peakModifierChord.symbolList.count
                if count >= 2 {
                    let newShortcut = KeyShortcut(keyCode: nil, modifiers: peakModifierChord)
                    self.shortcut = newShortcut
                    self.onShortcutChanged?(newShortcut)
                    stopRecording()
                    return nil
                }
                peakModifierChord = []
            }
            return nil
        }

        // 3. Key Down
        if event.type == .keyDown {
            peakModifierChord = []
            let keyCode = event.keyCode

            let isFunctionKey = KeyCodeHelper.isFunctionKey(keyCode)
            if !mods.isEmpty || isFunctionKey {
                let newShortcut = KeyShortcut(keyCode: keyCode, modifiers: mods)
                self.shortcut = newShortcut
                self.onShortcutChanged?(newShortcut)
                stopRecording()
                return nil
            }
        }

        return nil
    }
}

// MARK: - ShortcutPickerView

public struct ShortcutPickerView: View {
    @Binding public var preset: String
    @Binding public var shortcut: KeyShortcut
    public let presets: [ShortcutPresetItem]
    public var target: ShortcutSettings.ShortcutTarget?

    @ObservedObject private var shortcutSettings = AppSettings.shared.shortcuts

    public init(
        preset: Binding<String>,
        shortcut: Binding<KeyShortcut>,
        presets: [ShortcutPresetItem],
        target: ShortcutSettings.ShortcutTarget? = nil
    ) {
        self._preset = preset
        self._shortcut = shortcut
        self.presets = presets
        self.target = target
    }

    private var conflictTarget: ShortcutSettings.ShortcutTarget? {
        guard let target else { return nil }
        return shortcutSettings.findConflict(for: shortcut, excluding: target)
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                // 1. Interactive Modern Shortcut Recorder Field
                ShortcutRecorderView(
                    shortcut: Binding(
                        get: { shortcut },
                        set: { newShortcut in
                            shortcut = newShortcut
                            if let matched = presets.first(where: { $0.shortcut == newShortcut }) {
                                preset = matched.id
                            } else {
                                preset = "custom"
                            }
                        }
                    )
                )

                // 2. Preset Menu Button (Compact Popover Menu with Presets)
                Menu {
                    Section(L10n("shortcut.presets")) {
                        ForEach(presets) { p in
                            Button {
                                preset = p.id
                                shortcut = p.shortcut
                            } label: {
                                if shortcut == p.shortcut {
                                    Label(p.name, systemImage: "checkmark")
                                } else {
                                    Text(p.name)
                                }
                            }
                        }
                    }

                    if let target = target, !shortcutSettings.isDefault(for: target) {
                        Divider()
                        Button {
                            withAnimation {
                                shortcutSettings.resetToDefault(for: target)
                                preset = shortcutSettings.defaultPresetId(for: target)
                                shortcut = shortcutSettings.defaultShortcut(for: target)
                            }
                        } label: {
                            Label(L10n("shortcut.resetToDefault"), systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.8)
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L10n("shortcut.presets"))

                // 3. Quick Reset Button (Visible when customized away from default)
                if let target = target, !shortcutSettings.isDefault(for: target) {
                    Button {
                        withAnimation {
                            shortcutSettings.resetToDefault(for: target)
                            preset = shortcutSettings.defaultPresetId(for: target)
                            shortcut = shortcutSettings.defaultShortcut(for: target)
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help(L10n("shortcut.resetToDefault"))
                    .transition(.opacity.combined(with: .scale))
                }
            }

            // Conflict Warning Badge
            if let conflict = conflictTarget {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)

                    Text(String(format: L10n("shortcut.conflictWarning"), conflict.displayName))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
