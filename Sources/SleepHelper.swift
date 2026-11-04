import Foundation
import SystemConfiguration
import OSLog

final class SleepHelper: NSObject, SleepHelperProtocol, NSXPCListenerDelegate {
    private let lock = NSLock()
    private let logger = Logger(subsystem: "app.wakey.mac.helper.distribution", category: "Sleep")

    private func isConsoleUser(_ connection: NSXPCConnection) -> Bool {
        var uid: uid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
              name != "loginwindow", uid >= 500 else { return false }
        return connection.effectiveUserIdentifier == uid
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isConsoleUser(connection) else {
            logger.error("Rejected connection outside the active console user")
            return false
        }
        connection.exportedInterface = NSXPCInterface(with: SleepHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func setSleepDisabled(_ disabled: Bool, reply: @escaping @Sendable (Bool, String?) -> Void) {
        guard let connection = NSXPCConnection.current(), isConsoleUser(connection) else {
            reply(false, "Only the active Mac user can change this setting.")
            return
        }
        let caller = connection.effectiveUserIdentifier
        lock.lock()
        defer { lock.unlock() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            logger.notice("uid=\(caller) requested SleepDisabled=\(disabled); exit=\(process.terminationStatus)")
            reply(process.terminationStatus == 0, process.terminationStatus == 0 ? nil : "macOS couldn’t change the sleep setting.")
        } catch {
            logger.error("pmset launch failed: \(error.localizedDescription, privacy: .public)")
            reply(false, "Couldn’t run the sleep command.")
        }
    }
}

@main struct HelperMain {
    static func main() {
        guard geteuid() == 0 else { exit(77) }
        let helper = SleepHelper()
        let listener = NSXPCListener(machServiceName: HelperConfiguration.service)
        listener.setConnectionCodeSigningRequirement(HelperConfiguration.requirement(identifier: "app.wakey.mac"))
        listener.delegate = helper
        listener.resume()
        withExtendedLifetime((helper, listener)) { RunLoop.current.run() }
    }
}
