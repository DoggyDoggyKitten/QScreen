import Foundation

@main
struct ScreenLockPolicyTests {
    static func main() {
        let cases: [(String, Int32, ScreenLockPolicy)] = [
            ("2026-11-10 22:37:05 sysadminctl[63468:6164603] screenLock delay is immediate\n", 0, .immediate),
            ("screenLock delay is 0 seconds", 0, .immediate),
            ("screenLock delay is 60 seconds", 0, .requiresConfiguration),
            ("screenLock delay is 300", 0, .requiresConfiguration),
            ("screenLock delay is not immediate", 0, .unknown),
            ("screenLock delay is immediate but failed", 0, .unknown),
            ("screenLock delay is immediate", 1, .unknown),
            ("screenLock delay is immediate\nscreenLock delay is 60 seconds", 0, .unknown),
            ("", 0, .unknown),
            ("screenLock is disabled", 0, .unknown)
        ]
        for (output, status, expected) in cases {
            precondition(ScreenLockPolicy.parse(output, exitStatus: status) == expected, "Unsafe screen lock policy acceptance: \(output)")
        }
        print("Passed: only a confirmed immediate-password policy allows native departure locking.")
    }
}
