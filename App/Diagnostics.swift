import AppKit

@MainActor
enum Diagnostics {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/QScreen", isDirectory: true)

    static func log(_ event: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("events.log")
        let data = Data("\(ISO8601DateFormatter().string(from: Date())) \(event)\n".utf8)
        if let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 256_000 {
            try? data.write(to: destination, options: .atomic)
        } else if let handle = try? FileHandle(forWritingTo: destination) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: destination, options: .atomic)
        }
    }

    static func snapshot(_ model: QScreenModel) {
        model.refreshReadiness()
        let result: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "bundlePath": Bundle.main.bundlePath,
            "installed": model.installed,
            "accessibility": model.trusted,
            "selectionConfirmed": model.selectedInSystem,
            "hasAwaySession": model.activeSession != nil,
            "screens": NSScreen.screens.count
        ]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("diagnostics.json"), options: .atomic)
        }
    }
}
