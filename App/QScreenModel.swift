import AppKit
import SwiftUI

@MainActor
final class QScreenModel: ObservableObject {
    @Published var selectedReason = "lunch"
    @Published var durations: [String: Int] = [:]
    @Published var activeSession: NSDictionary?
    @Published var installed = false
    @Published var lockPolicy: ScreenLockPolicy = .unknown
    @Published var starting = false
    @Published var selectedInSystem = UserDefaults.standard.bool(forKey: "selectedInSystem")
    @Published var settingsVisible = false
    @Published var error: String?
    @Published var overtime = QSStateStore.overtimeMinutes()
    @Published var hotkeyAvailable = true
    @Published private(set) var language = QSStateStore.language()
    var languageDidChange: (() -> Void)?
    var showWindow: (() -> Void)?
    var showPreview: (() -> Void)?
    var prepareForSaver: (() -> Void)?
    var dismissPopover: (() -> Void)?
    private var refreshTimer: Timer?
    private var checkingPolicy = false

    let reasons = ["lunch", "meeting", "coffee", "restroom", "away", "offwork"]
    var saverDestination: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/QScreen.saver")
    }
    var ready: Bool { installed && lockPolicy == .immediate && selectedInSystem }
    var duration: Int { durations[selectedReason] ?? QSDefaultMinutes(selectedReason) }
    func text(_ chinese: String, _ english: String) -> String { language == "en" ? english : chinese }
    func reasonTitle(_ reason: String) -> String { QSReasonTitleInLanguage(reason, language) }
    func characterName(_ reason: String) -> String { QSCharacterNameInLanguage(reason, language) }
    func minutesText(_ minutes: Int) -> String { text("\(minutes) 分钟", "\(minutes) min") }
    func setLanguage(_ value: String) {
        guard ["zh", "en"].contains(value) else { return }
        QSStateStore.setLanguage(value)
        language = QSStateStore.language()
        languageDidChange?()
    }
    var sceneSession: NSDictionary {
        let session = NSMutableDictionary(dictionary: QSSession(selectedReason, duration, Date().timeIntervalSince1970))
        session["language"] = language
        return session
    }

    init() {
        for reason in reasons { durations[reason] = QSStateStore.minutes(forReason: reason) }
        refreshReadiness()
        refreshLockPolicy()
        let stored = QSStateStore.readSession() as NSDictionary
        if stored["id"] != nil { activeSession = stored }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshReadiness() }
        }
    }

    func refreshReadiness() {
        installed = FileManager.default.fileExists(atPath: saverDestination.appendingPathComponent("Contents/MacOS/QScreen").path)
    }

    func refreshLockPolicy() {
        guard !checkingPolicy else { return }
        checkingPolicy = true
        Task { [weak self] in
            let policy = await Task.detached(priority: .utility) { ScreenLockPolicy.read() }.value
            self?.lockPolicy = policy
            self?.checkingPolicy = false
        }
    }

    func setDuration(_ minutes: Int, reason: String? = nil) {
        let key = reason ?? selectedReason
        let value = min(480, max(1, minutes))
        durations[key] = value
        QSStateStore.setMinutes(value, forReason: key)
    }

    func chooseAndStart(_ reason: String) {
        guard !starting else { return }
        selectedReason = reason
        startAway()
    }

    func startAway(reason overrideReason: String? = nil, minutes overrideMinutes: Int? = nil) {
        guard !starting else { return }
        refreshReadiness()
        Diagnostics.log("away.request installed=\(installed) selection=\(selectedInSystem)")
        guard installed && selectedInSystem else {
            dismissPopover?()
            settingsVisible = true
            showWindow?()
            return
        }
        let reason = overrideReason ?? selectedReason, minutes = overrideMinutes ?? duration
        starting = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.starting = false }
            // Check again for every departure; a cached green check must never
            // allow an unprotected saver after the system policy changes.
            let policy = await Task.detached(priority: .userInitiated) { ScreenLockPolicy.read() }.value
            self.lockPolicy = policy
            Diagnostics.log("lock.policy.checked value=\(policy.rawValue)")
            guard policy == .immediate else {
                self.dismissPopover?()
                self.settingsVisible = true
                self.showWindow?()
                self.error = self.text("请先在系统锁屏设置中，将启动屏保后要求输入密码设为「立即」。", "In System Settings → Lock Screen, set the password requirement after the screen saver begins to Immediately.")
                return
            }
            let session = QSSession(reason, minutes, Date().timeIntervalSince1970)
            guard QSStateStore.writeSession(session) else {
                Diagnostics.log("away.save.failed")
                self.error = self.text("未能保存离席状态，请重试。", "Could not save your away status. Please try again.")
                return
            }
            self.activeSession = session as NSDictionary
            Diagnostics.log("away.saved reason=\(reason) minutes=\(minutes)")
            self.dismissPopover?()
            self.prepareForSaver?()
            // Let the click finish. The native saver supplies the secure lock
            // under the verified immediate-password policy; no synthetic keys.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                Diagnostics.log("saver.launch.requested nativeImmediateLock=true")
                let engine = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: engine, configuration: configuration) { [weak self] _, failure in
                    Task { @MainActor in
                        if let failure {
                            Diagnostics.log("saver.launch.failed \(failure.localizedDescription)")
                            self?.endAway()
                            self?.error = self?.text("屏保未能启动：\(failure.localizedDescription)", "Could not start the screen saver: \(failure.localizedDescription)")
                            self?.showWindow?()
                        } else {
                            Diagnostics.log("saver.launch.accepted")
                        }
                    }
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
            error = text("安装包中缺少屏保模块，请重新构建 QScreen。", "The screen saver is missing from this app. Please rebuild QScreen.")
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
            self.error = text("屏保安装失败：\(error.localizedDescription)", "Could not install the screen saver: \(error.localizedDescription)")
        }
    }

    func openScreenSaverSettings() {
        openSettings("x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")
    }
    func openLockSettings() {
        openSettings("x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension")
    }
    private func openSettings(_ address: String) {
        guard let url = URL(string: address), NSWorkspace.shared.open(url) else {
            error = text("无法打开系统设置，请手动打开。", "Could not open System Settings. Please open it manually.")
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

