import Foundation

enum ScreenLockPolicy: String, Sendable {
    case immediate
    case requiresConfiguration
    case unknown

    static func parse(_ output: String, exitStatus: Int32) -> ScreenLockPolicy {
        guard exitStatus == 0 else { return .unknown }
        let marker = "screenlock delay is "
        let values = output.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let normalized = line.lowercased()
            guard let range = normalized.range(of: marker) else { return nil }
            return String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard values.count == 1, let value = values.first else { return .unknown }
        if ["immediate", "0", "0 second", "0 seconds"].contains(value) { return .immediate }
        if value.range(of: #"^[1-9][0-9]*( seconds?)?$"#, options: .regularExpression) != nil {
            return .requiresConfiguration
        }
        return .unknown
    }

    static func read() -> ScreenLockPolicy {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysadminctl")
        process.arguments = ["-screenLock", "status"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        do { try process.run() } catch { return .unknown }
        guard completed.wait(timeout: .now() + 5) == .success else {
            process.terminate()
            return .unknown
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return parse(String(decoding: data, as: UTF8.self), exitStatus: process.terminationStatus)
    }
}
