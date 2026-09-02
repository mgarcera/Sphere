import Foundation

/// Temporary. Diagnostics that survive the app closing, so a bug can be
/// reproduced whenever it is convenient and read back on the next launch —
/// stdout only exists while a console is attached, which means catching the
/// moment live.
enum Trace {
    private static let key = "diagnosticTrace"

    static func log(_ message: String) {
        var lines = UserDefaults.standard.stringArray(forKey: key) ?? []
        lines.append("\(Date().formatted(date: .omitted, time: .standard))  \(message)")
        UserDefaults.standard.set(Array(lines.suffix(80)), forKey: key)
    }

    static func dump() {
        let lines = UserDefaults.standard.stringArray(forKey: key) ?? []
        print("[DBG-del] --- \(lines.count) lines from previous runs ---")
        lines.forEach { print("[DBG-del] \($0)") }
        // Deliberately NOT cleared: dumping to a console nobody is attached to
        // threw away the only copy last time.
    }
}
