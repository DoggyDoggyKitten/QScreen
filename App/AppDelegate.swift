import AppKit
import Carbon
import SwiftUI

private final class PreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = QScreenModel()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var window: NSWindow?
    private var previews: [NSWindow] = []
    private var previewTimers: [Timer] = []
    private var keyMonitor: Any?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("app.started")
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "QScreen 离席")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePicker)
        statusItem.button?.toolTip = "QScreen · ⌃⌥Q"
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: QuickPicker(model: model))
        model.showWindow = { [weak self] in self?.showMainWindow() }
        model.showPreview = { [weak self] in self?.openPreview() }
        model.dismissPopover = { [weak self] in self?.popover.performClose(nil) }
        model.lock = { [weak self] in
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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
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
        Diagnostics.snapshot(model)
    }

    func showMainWindow() {
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
        if popover.isShown { popover.performClose(nil); return }
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
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
        popover.performClose(nil)
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
            let hint = NSTextField(labelWithString: "预览 · 按任意键或点击退出")
            hint.font = .systemFont(ofSize: 12)
            hint.textColor = model.selectedReason == "offwork" ? .white.withAlphaComponent(0.65) : .secondaryLabelColor
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
        captureView(popover.contentViewController?.view, to: "\(directory)/picker.png")
        popover.performClose(nil)
        let saved = model.durations["meeting"] ?? 60
        model.setDuration(45, reason: "meeting")
        let persisted = QSStateStore.minutes(forReason: "meeting") == 45
        model.setDuration(saved, reason: "meeting")
        model.selectedReason = "offwork"
        let noETA = (model.sceneSession["endsAt"] as? Double) == 0
        model.selectedReason = "lunch"
        let result: [String: Any] = ["window": window?.isVisible == true,
                                    "presetCount": model.reasons.count,
                                    "durationPersistence": persisted,
                                    "offworkHasNoETA": noETA,
                                    "saverInstalled": model.installed,
                                    "accessibilityGranted": model.trusted,
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
        if !CommandLine.arguments.contains("--smoke-test") { model.endAway() }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        for observer in lifecycleObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

