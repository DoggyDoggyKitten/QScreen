import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class QScreenModel: ObservableObject {
    @Published var selectedReason = "lunch"
    @Published var durations: [String: Int] = [:]
    @Published var activeSession: NSDictionary?
    @Published var installed = false
    @Published var trusted = false
    @Published var selectedInSystem = UserDefaults.standard.bool(forKey: "selectedInSystem")
    @Published var settingsVisible = false
    @Published var error: String?
    @Published var overtime = QSStateStore.overtimeMinutes()
    @Published var hotkeyAvailable = true
    var showWindow: (() -> Void)?
    var showPreview: (() -> Void)?
    var lock: (() -> Void)?
    var dismissPopover: (() -> Void)?
    var relaunch: (() -> Void)?
    private var refreshTimer: Timer?

    let reasons = ["lunch", "meeting", "coffee", "restroom", "away", "offwork"]
    var saverDestination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/QScreen.saver")
    }
    var ready: Bool { installed && trusted && selectedInSystem }
    var duration: Int { durations[selectedReason] ?? QSDefaultMinutes(selectedReason) }
    var sceneSession: NSDictionary {
        QSSession(selectedReason, duration, Date().timeIntervalSince1970) as NSDictionary
    }

    init() {
        for reason in reasons { durations[reason] = QSStateStore.minutes(forReason: reason) }
        refreshReadiness()
        let stored = QSStateStore.readSession() as NSDictionary
        if stored["id"] != nil { activeSession = stored }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshReadiness() }
        }
    }

    func refreshReadiness() {
        installed = FileManager.default.fileExists(atPath: saverDestination.appendingPathComponent("Contents/MacOS/QScreen").path)
        trusted = CGPreflightPostEventAccess()
    }

    func setDuration(_ minutes: Int, reason: String? = nil) {
        let key = reason ?? selectedReason
        let value = min(480, max(1, minutes))
        durations[key] = value
        QSStateStore.setMinutes(value, forReason: key)
    }

    func chooseAndStart(_ reason: String) {
        selectedReason = reason
        startAway()
    }

    func startAway() {
        refreshReadiness()
        Diagnostics.log("away.request installed=\(installed) eventPosting=\(trusted) selection=\(selectedInSystem)")
        guard ready else {
            dismissPopover?()
            settingsVisible = true
            showWindow?()
            return
        }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0x0C, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x0C, keyDown: false) else {
            error = "无法发送锁屏快捷键，请重试。"
            return
        }
        let session = sceneSession
        guard QSStateStore.writeSession(session as! [AnyHashable: Any]) else {
            Diagnostics.log("away.save.failed")
            error = "未能保存离席状态，请重试。"
            return
        }
        activeSession = session
        Diagnostics.log("away.saved reason=\(selectedReason) minutes=\(duration)")
        dismissPopover?()
        lock?()
        down.flags = [.maskControl, .maskCommand]
        up.flags = [.maskControl, .maskCommand]
        // Let the triggering click finish before sending Control-Command-Q.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            Diagnostics.log("lock.shortcut.posted")
        }
        // The system remains responsible for authentication. Starting the engine
        // only requests the currently selected saver; it never substitutes a fake lock.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            Diagnostics.log("saver.launch.requested")
            let engine = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(at: engine, configuration: configuration) { [weak self] _, failure in
                if let failure {
                    Task { @MainActor in
                        Diagnostics.log("saver.launch.failed \(failure.localizedDescription)")
                        self?.error = "屏保未能启动：\(failure.localizedDescription)"
                    }
                } else {
                    Task { @MainActor in Diagnostics.log("saver.launch.accepted") }
                }
            }
        }
    }

    func endAway() {
        if activeSession != nil { Diagnostics.log("away.cleared") }
        QSStateStore.clearSession()
        activeSession = nil
    }

    func installSaver() {
        guard let source = Bundle.main.url(forResource: "QScreen", withExtension: "saver") else {
            error = "安装包中缺少屏保模块，请重新构建 QScreen。"
            return
        }
        do {
            try FileManager.default.createDirectory(at: saverDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Stage the replacement before touching an existing installation.
            let staged = saverDestination.deletingLastPathComponent().appendingPathComponent(".QScreen-\(UUID().uuidString).saver")
            try FileManager.default.copyItem(at: source, to: staged)
            defer { try? FileManager.default.removeItem(at: staged) }
            if FileManager.default.fileExists(atPath: saverDestination.path) {
                _ = try FileManager.default.replaceItemAt(saverDestination, withItemAt: staged)
            } else {
                try FileManager.default.moveItem(at: staged, to: saverDestination)
            }
            refreshReadiness()
        } catch {
            self.error = "屏保安装失败：\(error.localizedDescription)"
        }
    }

    func openScreenSaverSettings() {
        openSettings("x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")
    }
    func requestLockPermission() {
        Diagnostics.log("permission.postEvent.requested")
        trusted = CGRequestPostEventAccess()
        if !trusted {
            openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }
    private func openSettings(_ address: String) {
        guard let url = URL(string: address), NSWorkspace.shared.open(url) else {
            error = "无法打开系统设置，请手动打开。"
            return
        }
    }
    func confirmSelection() {
        selectedInSystem = true
        UserDefaults.standard.set(true, forKey: "selectedInSystem")
    }
    func setOvertime(_ minutes: Int) {
        overtime = minutes
        QSStateStore.setOvertimeMinutes(minutes)
    }
}

