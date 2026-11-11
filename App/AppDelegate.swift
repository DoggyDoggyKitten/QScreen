import AppKit
import Carbon
import SwiftUI

private final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = QScreenModel()
    private var statusItem: NSStatusItem!
    private var pickerPanel: PickerPanel?
    private var pickerClickMonitor: Any?
    private var window: NSWindow?
    private var previews: [NSWindow] = []
    private var previewTimers: [Timer] = []
    private var keyMonitor: Any?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("app.started")
        QSStateStore.startPublishing()
        if let index = CommandLine.arguments.firstIndex(of: "--language"),
           CommandLine.arguments.indices.contains(index + 1) {
            model.setLanguage(CommandLine.arguments[index + 1])
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "QScreen")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePicker)
        updateStatusText()
        model.languageDidChange = { [weak self] in self?.updateStatusText() }
        model.showWindow = { [weak self] in self?.showMainWindow() }
        model.showPreview = { [weak self] in self?.openPreview() }
        model.dismissPopover = { [weak self] in self?.closePicker() }
        model.prepareForSaver = { [weak self] in
            self?.closePreview()
            self?.window?.orderOut(nil)
            NSApp.deactivate()
        }
        registerHotkey()
        // Compatibility notifications clear metadata only; never used as proof of locking.
        let center = DistributedNotificationCenter.default()
        lifecycleObservers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.endAway() }
        })
        lifecycleObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.model.endAway() }
        })
        // Clicking this app after returning is also an unambiguous reset, even if
        // a macOS version does not deliver the compatibility unlock notification.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                if self.pickerPanel?.isVisible == true {
                    if event.type == .keyDown && event.keyCode == UInt16(kVK_Escape) {
                        self.closePicker()
                        return true
                    }
                    if (event.type == .leftMouseDown || event.type == .rightMouseDown) && event.window !== self.pickerPanel &&
                        event.window !== self.statusItem.button?.window {
                        self.closePicker()
                    }
                }
                if !self.previews.isEmpty {
                    self.closePreview()
                    return true
                }
                if let session = self.model.activeSession,
                   Date().timeIntervalSince1970 - (session["startedAt"] as? Double ?? 0) > 3 {
                    self.model.endAway()
                }
                return false
            }
            return consumed ? nil : event
        }
        pickerClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePicker() }
        }
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            showMainWindow()
        }
        if CommandLine.arguments.contains("--show") { showMainWindow() }
        if CommandLine.arguments.contains("--setup") {
            model.settingsVisible = true
            showMainWindow()
        }
        if CommandLine.arguments.contains("--smoke-test") {
            showMainWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.runSmokeTest()
                NSApp.terminate(nil)
            }
        }
        if CommandLine.arguments.contains("--test-departure") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.model.startAway(reason: "meeting", minutes: 5)
            }
        }
        Diagnostics.snapshot(model)
    }

    private func updateStatusText() {
        statusItem.button?.toolTip = model.text("QScreen 离席 · ⌃⌥Q", "QScreen · Quick away · ⌃⌥Q")
        statusItem.button?.setAccessibilityLabel(model.text("QScreen 离席", "QScreen quick away"))
    }

    func showMainWindow() {
        model.refreshLockPolicy()
        if window == nil {
            let controller = NSHostingController(rootView: MainView(model: model))
            let panel = NSWindow(contentViewController: controller)
            panel.title = "QScreen"
            panel.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            panel.titlebarAppearsTransparent = true
            panel.setContentSize(NSSize(width: 1000, height: 672))
            panel.minSize = NSSize(width: 1000, height: 700)
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func togglePicker() {
        if pickerPanel?.isVisible == true { closePicker(); return }
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        if pickerPanel == nil {
            let hosting = NSHostingController(rootView: QuickPicker(model: model))
            let panel = PickerPanel(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentViewController = hosting
            panel.setContentSize(hosting.view.fittingSize)
            pickerPanel = panel
        }
        guard let panel = pickerPanel else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchor
        let x = min(max(anchor.midX - panel.frame.width / 2, visible.minX + 8), visible.maxX - panel.frame.width - 8)
        let y = max(visible.minY + 8, anchor.minY - panel.frame.height - 6)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
    }

    private func closePicker() {
        pickerPanel?.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    func applicationDidResignActive(_ notification: Notification) {
        closePicker()
    }

    private func registerHotkey() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installedHandler = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.togglePicker()
            }
            return noErr
        }, 1, &type, nil, &handler)
        guard installedHandler == noErr else { model.hotkeyAvailable = false; return }
        let identifier = EventHotKeyID(signature: 0x51534352, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_Q), UInt32(controlKey | optionKey), identifier, GetApplicationEventTarget(), 0, &hotkey)
        model.hotkeyAvailable = result == noErr
    }

    private func openPreview() {
        closePreview()
        closePicker()
        let session = model.sceneSession
        let start = CACurrentMediaTime()
        for screen in NSScreen.screens {
            let panel = PreviewWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .black
            let scene = QSSceneView(frame: NSRect(origin: .zero, size: screen.frame.size))
            scene.session = session as! [AnyHashable: Any]
            let container = NSView(frame: scene.frame)
            container.addSubview(scene)
            let hint = NSTextField(labelWithString: model.text("预览 · 按任意键或点击退出", "Preview · Press any key or click to exit"))
            hint.font = .systemFont(ofSize: 12)
            hint.textColor = QSSceneCharacter(session as! [AnyHashable: Any]) == "offwork" ? .white.withAlphaComponent(0.65) : .secondaryLabelColor
            hint.alignment = .center
            hint.frame = NSRect(x: 20, y: 20, width: scene.frame.width - 40, height: 24)
            hint.autoresizingMask = [.width, .maxYMargin]
            container.addSubview(hint)
            panel.contentView = container
            panel.makeKeyAndOrderFront(nil)
            let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak scene] _ in
                scene?.animationTime = CACurrentMediaTime() - start
                scene?.referenceTime = Date().timeIntervalSince1970
            }
            RunLoop.main.add(timer, forMode: .common)
            previewTimers.append(timer)
            previews.append(panel)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePreview() {
        previewTimers.forEach { $0.invalidate() }
        previewTimers.removeAll()
        previews.forEach { $0.orderOut(nil); $0.close() }
        previews.removeAll()
    }

    private func captureView(_ view: NSView?, to path: String) {
        guard let view,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = bitmap.representation(using: .png, properties: [:])
        try? data?.write(to: URL(fileURLWithPath: path))
    }

    private func enterText(_ value: String, placeholder: String) -> Bool {
        func findField(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.placeholderString == placeholder { return field }
            for child in view.subviews {
                if let field = findField(child) { return field }
            }
            return nil
        }
        guard let view = window?.contentView, let field = findField(view) else { return false }
        window?.makeKeyAndOrderFront(nil)
        guard window?.makeFirstResponder(field) == true, let editor = field.currentEditor() as? NSTextView else { return false }
        editor.selectAll(nil)
        editor.insertText(value, replacementRange: editor.selectedRange())
        window?.makeFirstResponder(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        return true
    }

    private func runSmokeTest() {
        let directory = ProcessInfo.processInfo.environment["QSCREEN_CAPTURE_DIR"] ?? "/tmp/qscreen-smoke"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        captureView(window?.contentView, to: "\(directory)/app.png")
        model.settingsVisible = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window?.contentView?.layoutSubtreeIfNeeded()
        captureView(window?.contentView, to: "\(directory)/settings.png")
        model.settingsVisible = false
        togglePicker()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        captureView(pickerPanel?.contentView, to: "\(directory)/picker.png")
        let pickerFitsScreen = pickerPanel.map { panel in panel.screen?.visibleFrame.contains(panel.frame) == true } ?? false
        let pickerBorderless = pickerPanel?.styleMask == .borderless
        pickerPanel?.appearance = NSAppearance(named: .darkAqua)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        captureView(pickerPanel?.contentView, to: "\(directory)/picker-dark.png")
        pickerPanel?.appearance = nil
        if let panel = pickerPanel,
           let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                                        context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                                        isARepeat: false, keyCode: UInt16(kVK_Escape)) {
            NSApp.sendEvent(escape)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let pickerEscapeDismissed = pickerPanel?.isVisible == false
        togglePicker()
        let pickerReopens = pickerPanel?.isVisible == true
        closePicker()
        let saved = model.durations["meeting"] ?? 60
        model.setDuration(45, reason: "meeting")
        let persisted = QSStateStore.minutes(forReason: "meeting") == 45
        model.setDuration(saved, reason: "meeting")
        model.selectedReason = "offwork"
        let noETA = (model.sceneSession["endsAt"] as? Double) == 0
        model.selectedReason = "lunch"
        let originalLanguage = model.language
        var languageSwitchWorks = true
        for language in ["zh", "en"] {
            model.setLanguage(language)
            model.settingsVisible = false
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            window?.contentView?.layoutSubtreeIfNeeded()
            captureView(window?.contentView, to: "\(directory)/app-\(language).png")
            model.settingsVisible = true
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            captureView(window?.contentView, to: "\(directory)/settings-\(language).png")
            togglePicker()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            captureView(pickerPanel?.contentView, to: "\(directory)/picker-\(language).png")
            closePicker()
            languageSwitchWorks = languageSwitchWorks && QSStateStore.language() == language && model.sceneSession["language"] as? String == language
        }
        model.setLanguage(originalLanguage)
        model.settingsVisible = false
        let savedCustomReason = model.customReason, savedCharacter = model.customCharacter
        let savedCustomMinutes = model.durations["custom"] ?? 15
        model.openCustomEditor()
        model.setLanguage("en")
        model.setCustomReason("")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let emptyCustomBlocked = !model.canStart
        let typedReason = enterText("Walking the dog", placeholder: "e.g. Walking the dog")
        let typedMinutes = enterText("25", placeholder: "Minutes")
        model.setCustomCharacter("coffee")
        let customInputWorks = typedReason && typedMinutes && model.customReason == "Walking the dog" && model.duration == 25 && model.canStart
        let customSession = model.sceneSession
        let customSyncReady = QSValidatedSession(customSession, Date().timeIntervalSince1970)["reason"] as? String == "custom" &&
            QSSceneTitle(customSession as! [AnyHashable: Any], "en") == "Walking the dog" &&
            QSSceneCharacter(customSession as! [AnyHashable: Any]) == "coffee"
        let customDraftSaved = QSStateStore.customReason() == "Walking the dog" && QSStateStore.customCharacter() == "coffee" &&
            QSStateStore.minutes(forReason: "custom") == 25
        for language in ["en", "zh"] {
            model.setLanguage(language)
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            captureView(window?.contentView, to: "\(directory)/custom-\(language).png")
        }
        model.setCustomReason(savedCustomReason)
        model.setCustomCharacter(savedCharacter)
        model.setDuration(savedCustomMinutes, reason: "custom")
        model.setLanguage(originalLanguage)
        model.selectedReason = "lunch"
        let result: [String: Any] = ["window": window?.isVisible == true,
                                    "presetCount": model.reasons.count,
                                    "durationPersistence": persisted,
                                    "offworkHasNoETA": noETA,
                                    "saverInstalled": model.installed,
                                    "lockPolicy": model.lockPolicy.rawValue,
                                    "pickerFitsScreen": pickerFitsScreen,
                                    "pickerBorderless": pickerBorderless,
                                    "pickerEscapeDismissed": pickerEscapeDismissed,
                                    "pickerReopens": pickerReopens,
                                    "languageSwitchAndPersistence": languageSwitchWorks,
                                    "language": model.language,
                                    "emptyCustomBlocked": emptyCustomBlocked,
                                    "customTypedInput": customInputWorks,
                                    "customSessionValidated": customSyncReady,
                                    "customDraftPersistence": customDraftSaved,
                                    "screens": NSScreen.screens.count,
                                    "screenSizes": NSScreen.screens.map { "\(Int($0.frame.width))×\(Int($0.frame.height))" }]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "\(directory)/results.json"))
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.host == "diagnostics" }) {
            Diagnostics.snapshot(model)
            return
        }
        showMainWindow()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showMainWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        closePreview()
        closePicker()
        if !CommandLine.arguments.contains("--smoke-test") { model.endAway() }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let pickerClickMonitor { NSEvent.removeMonitor(pickerClickMonitor) }
        for observer in lifecycleObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

