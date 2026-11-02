import Foundation

/// Ask the GUI process, whose privacy permissions can differ from a shell's.
/// Reports aggregate Command counts only; no typed keys, text or applications.
enum ShortcutDiagnostics {
    static let request = Notification.Name("local.dvale.shortcutDiagnostics.request")
    static let response = Notification.Name("local.dvale.shortcutDiagnostics.response")

    /// The caller owns the observer and removes it when the app shuts down.
    static func respond(report: @escaping () -> [String: Any]?) -> NSObjectProtocol {
        let center = DistributedNotificationCenter.default()
        return center.addObserver(forName: request, object: nil, queue: .main) { note in
            guard let nonce = note.object as? String, UUID(uuidString: nonce) != nil,
                  let report = report(),
                  let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else { return }
            center.postNotificationName(response, object: nonce,
                                        userInfo: ["report": text], deliverImmediately: true)
        }
    }

    static func queryRunningApp() -> String? {
        let center = DistributedNotificationCenter.default()
        let nonce = UUID().uuidString
        var report: String?
        let observer = center.addObserver(forName: response, object: nonce, queue: .main) { note in
            report = note.userInfo?["report"] as? String
        }
        defer { center.removeObserver(observer) }
        center.postNotificationName(request, object: nonce, userInfo: nil, deliverImmediately: true)
        let deadline = Date().addingTimeInterval(3)
        while report == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return report
    }
}
