import AppKit
import ServiceManagement
import OSLog

@MainActor final class HelperRequest {
    private var connection: NSXPCConnection?
    private var continuation: CheckedContinuation<Void, any Error>?
    private var timeout: Task<Void, Never>?

    func set(_ disabled: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let connection = NSXPCConnection(machServiceName: HelperConfiguration.service, options: .privileged)
            self.connection = connection
            connection.remoteObjectInterface = NSXPCInterface(with: SleepHelperProtocol.self)
            connection.setCodeSigningRequirement(HelperConfiguration.requirement(identifier: HelperConfiguration.service))
            connection.invalidationHandler = { [weak self] in
                Task { @MainActor in self?.finish("Helper unavailable. Check its approval in System Settings.") }
            }
            connection.interruptionHandler = { [weak self] in
                Task { @MainActor in self?.finish("The helper disconnected. Try again.") }
            }
            connection.resume()
            let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
                Task { @MainActor in self?.finish("Helper unavailable. Check its approval in System Settings.") }
            } as? SleepHelperProtocol
            guard let proxy else { finish("Couldn’t connect to the helper."); return }
            proxy.setSleepDisabled(disabled) { [weak self] success, error in
                Task { @MainActor in self?.finish(success ? nil : (error ?? "Couldn’t change the sleep setting.")) }
            }
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                self?.finish("The helper didn’t respond. Try again.")
            }
        }
    }

    private func finish(_ message: String?) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
        if let message {
            continuation.resume(throwing: NSError(domain: "KeepAwake", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        } else {
            continuation.resume()
        }
    }
}

@MainActor final class StatusAnimationView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let animationView = StatusAnimationView()
    private lazy var animator = CreatureAnimator(view: animationView)
    private let service = SMAppService.daemon(plistName: HelperConfiguration.plist)
    private var enabled: Bool?
    private var busy = false
    private var error: String?
    private var polling: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.wakey.mac", category: "Toggle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: 28)
        if let button = item.button {
            do { try animator.load() }
            catch { self.error = error.localizedDescription }
            animationView.frame = NSRect(x: button.bounds.midX - 14, y: button.bounds.midY - 14, width: 28, height: 28)
            animationView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
            animationView.imageScaling = .scaleProportionallyUpOrDown
            animationView.setAccessibilityElement(false)
            button.addSubview(animationView)
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        render()
        do {
            if service.status == .notRegistered || service.status == .notFound { try service.register() }
        } catch {
            self.error = "Helper setup: \(error.localizedDescription)"
            logger.error("Helper registration failed: \(error.localizedDescription, privacy: .public)")
        }
        polling = Task {
            await refresh()
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                if !busy { await refresh() }
            }
        }
    }

    private func refresh() async {
        do { enabled = try await Power.read() }
        catch { enabled = nil; self.error = error.localizedDescription }
        render()
    }

    private func render() {
        guard let button = item?.button else { return }
        let ready = service.status == .enabled
        let showArtwork = ready && enabled != nil && animator.isLoaded
        animationView.isHidden = !showArtwork
        if showArtwork {
            button.image = nil
            button.contentTintColor = nil
            animator.show(awake: enabled == true)
            animationView.alphaValue = busy ? 0.5 : 1
        } else {
            animator.stop()
            let symbol = busy ? "arrow.triangle.2.circlepath" : "exclamationmark.circle"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Keep Awake")?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.white]))
            button.image?.isTemplate = false
            button.contentTintColor = .white
        }
        let state = !ready ? "Setup required" : (enabled == nil ? "Unavailable" : (enabled == true ? "On" : "Off"))
        button.setAccessibilityLabel("Wakey: Keep Awake \(state)")
        button.setAccessibilityValue(busy ? "Changing" : state)
        button.toolTip = error ?? (busy ? "Changing sleep setting…" : (!ready ? "Approve Wakey in Login Items & Extensions" : "Keep Awake: \(state) — click to toggle"))
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
        guard !busy else { return }
        guard service.status == .enabled else {
            do {
                if service.status == .notRegistered || service.status == .notFound { try service.register() }
                SMAppService.openSystemSettingsLoginItems()
            } catch { self.error = error.localizedDescription; render() }
            return
        }
        busy = true
        error = nil
        render()
        Task {
            defer { busy = false; render() }
            do {
                // Read immediately before toggling so external changes are respected.
                let desired = !(try await Power.read())
                let request = HelperRequest()
                try await request.set(desired)
                enabled = try await Power.read()
                if enabled != desired {
                    error = "The setting changed unexpectedly. Click to try again."
                }
            } catch {
                self.error = error.localizedDescription
                logger.error("Toggle failed: \(error.localizedDescription, privacy: .public)")
                await refresh()
                NSSound.beep()
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if let error {
            let row = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            row.isEnabled = false
            menu.addItem(row)
            menu.addItem(.separator())
        }
        if service.status != .enabled {
            let setup = NSMenuItem(title: "Approve Helper…", action: #selector(openSetup), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
            menu.addItem(.separator())
        }
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        quit.isEnabled = !busy
        quit.toolTip = "Leaves the current sleep setting in place."
        menu.addItem(quit)
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openSetup() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func quit() { NSApp.terminate(nil) }
}

@main struct WakeyMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--remove-helper") {
            do {
                try SMAppService.daemon(plistName: HelperConfiguration.plist).unregister()
                print("Wakey helper unregistered. Quit the app before removing it.")
            } catch {
                print("Couldn’t remove helper: \(error.localizedDescription)")
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--service-status") {
            print("Helper status: \(SMAppService.daemon(plistName: HelperConfiguration.plist).status.rawValue)")
            return
        }
        if CommandLine.arguments.contains("--check-animation-assets") {
            let view = NSImageView()
            let animator = CreatureAnimator(view: view)
            do {
                try animator.load()
                precondition(animator.isLoaded)
                precondition(CreatureRoute.transition(from: nil, to: true) == nil)
                precondition(CreatureRoute.transition(from: true, to: true) == nil)
                precondition(CreatureRoute.transition(from: false, to: true) == "wake")
                precondition(CreatureRoute.transition(from: true, to: false) == "settle")
                print("PASS: four native animation sequences loaded; initial, unchanged and both transition routes verified")
            } catch { fputs("Animation check failed: \(error)\n", stderr); exit(1) }
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
