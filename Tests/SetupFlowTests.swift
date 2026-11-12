import Foundation

@main struct SetupFlowTests {
    static func main() {
        precondition(SetupFlow.shouldPresent(hasLaunched: false, started: false, completed: false))
        precondition(SetupFlow.shouldPresent(hasLaunched: true, started: true, completed: false))
        precondition(!SetupFlow.shouldPresent(hasLaunched: true, started: false, completed: false), "Existing users must not be forced through onboarding")
        precondition(!SetupFlow.shouldPresent(hasLaunched: true, started: true, completed: true))
        precondition(SetupFlow.restoredStep(99) == .install)
        precondition(SetupFlow.restoredStep(-1) == .install)
        precondition(SetupFlow.restoredStep(3) == .password)
        for installed in [false, true] {
            for selected in [false, true] {
                for policy in [ScreenLockPolicy.unknown, .requiresConfiguration, .immediate] {
                    let ready = installed && selected && policy == .immediate
                    precondition(SetupFlow.canAdvance(.finish, installed: installed, selected: selected, policy: policy) == ready)
                    precondition(SetupFlow.canAdvance(.password, installed: installed, selected: selected, policy: policy) == ready)
                    precondition((SetupFlow.firstIncomplete(installed: installed, selected: selected, policy: policy) == .finish) == ready)
                }
            }
        }
        precondition(!SetupFlow.canAdvance(.install, installed: false, selected: false, policy: .unknown))
        precondition(!SetupFlow.canAdvance(.select, installed: true, selected: false, policy: .immediate))
        precondition(SetupFlow.firstIncomplete(installed: true, selected: false, policy: .immediate) == .wallpaper, "Missing selection must include the screen saver entry instructions")
        print("Passed: fresh install, resume, existing-user migration, corrupt progress and all setup completion prerequisites.")
    }
}
