import Foundation

enum SetupStep: Int, CaseIterable {
    case install, wallpaper, select, password, finish
}

enum SetupFlow {
    static func shouldPresent(hasLaunched: Bool, started: Bool, completed: Bool) -> Bool {
        !hasLaunched || (started && !completed)
    }

    static func restoredStep(_ value: Int) -> SetupStep {
        SetupStep(rawValue: value) ?? .install
    }

    static func firstIncomplete(installed: Bool, selected: Bool, policy: ScreenLockPolicy) -> SetupStep {
        if !installed { return .install }
        if !selected { return .wallpaper }
        if policy != .immediate { return .password }
        return .finish
    }

    static func canAdvance(_ step: SetupStep, installed: Bool, selected: Bool, policy: ScreenLockPolicy) -> Bool {
        switch step {
        case .install: return installed
        case .wallpaper: return true
        case .select: return installed && selected
        case .password, .finish: return installed && selected && policy == .immediate
        }
    }
}
