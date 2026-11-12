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
    @Published private(set) var customReason = QSStateStore.customReason()
    @Published private(set) var customCharacter = QSStateStore.customCharacter()
    @Published private(set) var setupVisible = false
    @Published private(set) var setupStep = SetupFlow.restoredStep(UserDefaults.standard.integer(forKey: "onboardingStep"))
    @Published private(set) var finishingSetup = false
    @Published var setupError: String?
    var languageDidChange: (() -> Void)?
    var showWindow: (() -> Void)?
    var showPreview: (() -> Void)?
    var showQuickPicker: (() -> Void)?
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
    var shouldPresentSetup: Bool {
        SetupFlow.shouldPresent(hasLaunched: UserDefaults.standard.bool(forKey: "hasLaunched"),
                                started: UserDefaults.standard.bool(forKey: "onboardingStarted"),
                                completed: UserDefaults.standard.bool(forKey: "onboardingCompleted"))
    }
    var canAdvanceSetup: Bool {
        SetupFlow.canAdvance(setupStep, installed: installed, selected: selectedInSystem, policy: lockPolicy)
    }
    func beginSetup(resume: Bool = false) {
        UserDefaults.standard.set(true, forKey: "onboardingStarted")
        if !resume { setSetupStep(.install) }
        setupVisible = true
        settingsVisible = false
        setupError = nil
        dismissPopover?()
        refreshReadiness()
        refreshLockPolicy()
        showWindow?()
    }
    func setSetupStep(_ step: SetupStep) {
        setupStep = step
        setupError = nil
        UserDefaults.standard.set(step.rawValue, forKey: "onboardingStep")
        if step == .password || step == .finish { refreshLockPolicy() }
    }
    func advanceSetup() {
        refreshReadiness()
        guard canAdvanceSetup, let next = SetupStep(rawValue: setupStep.rawValue + 1) else { return }
        setSetupStep(next)
    }
    func dismissSetup() {
        setupVisible = false
        settingsVisible = true
    }
    func finishSetup(openQuickPicker: Bool = false) {
        guard !finishingSetup else { return }
        finishingSetup = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.finishingSetup = false }
            self.lockPolicy = await Task.detached(priority: .userInitiated) { ScreenLockPolicy.read() }.value
            self.refreshReadiness()
            let next = SetupFlow.firstIncomplete(installed: self.installed, selected: self.selectedInSystem, policy: self.lockPolicy)
            guard next == .finish else {
                self.setSetupStep(next)
                self.setupError = self.text("请先完成这一步，再结束设置。", "Complete this step before finishing setup.")
                return
            }
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            self.setupVisible = false
            self.settingsVisible = false
            if openQuickPicker { self.showQuickPicker?() }
        }
    }
    var duration: Int { durations[selectedReason] ?? QSDefaultMinutes(selectedReason) }
    var customReasonValid: Bool { !QSNormalizedCustomReason(customReason).isEmpty }
    var canStart: Bool { !starting && (selectedReason != "custom" || customReasonValid) }
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
        makeSession(reason: selectedReason, minutes: duration)
    }
    var customSceneSession: NSDictionary {
        makeSession(reason: "custom", minutes: durations["custom"] ?? 15)
    }
    private func makeSession(reason: String, minutes: Int) -> NSDictionary {
        let value = reason == "custom" ? QSCustomSession(customReason, customCharacter, minutes, Date().timeIntervalSince1970)
                                       : QSSession(reason, minutes, Date().timeIntervalSince1970)
        let session = NSMutableDictionary(dictionary: value)
        session["language"] = language
        return session
    }

    func setCustomReason(_ value: String) {
        customReason = String(value.prefix(40))
        QSStateStore.setCustomReason(customReason)
    }
    func setCustomCharacter(_ value: String) {
        guard reasons.contains(value) else { return }
        customCharacter = value
        QSStateStore.setCustomCharacter(value)
    }
    func openCustomEditor() {
        selectedReason = "custom"
        settingsVisible = false
        dismissPopover?()
        showWindow?()
    }

    init() {
        for reason in reasons { durations[reason] = QSStateStore.minutes(forReason: reason) }
        durations["custom"] = QSStateStore.minutes(forReason: "custom")
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
        if reason == "custom" { openCustomEditor(); return }
        selectedReason = reason
        startAway()
    }

    func startAway(reason overrideReason: String? = nil, minutes overrideMinutes: Int? = nil) {
        guard !starting else { return }
        // Commit a typed minute value before reading it, including Command-Return.
        if let window = NSApp.keyWindow, !window.makeFirstResponder(nil) { return }
        refreshReadiness()
        Diagnostics.log("away.request installed=\(installed) selection=\(selectedInSystem)")
        guard installed && selectedInSystem else {
            beginSetup(resume: true)
            setSetupStep(SetupFlow.firstIncomplete(installed: installed, selected: selectedInSystem, policy: lockPolicy))
            return
        }
        let reason = overrideReason ?? selectedReason, minutes = overrideMinutes ?? duration
        let customTitle = QSNormalizedCustomReason(customReason), character = customCharacter
        guard reason != "custom" || !customTitle.isEmpty else {
            openCustomEditor()
            error = text("请填写离席理由。", "Enter an away reason.")
            return
        }
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
                self.beginSetup(resume: true)
                self.setSetupStep(.password)
                return
            }
            let session = reason == "custom" ? QSCustomSession(customTitle, character, minutes, Date().timeIntervalSince1970)
                                             : QSSession(reason, minutes, Date().timeIntervalSince1970)
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

