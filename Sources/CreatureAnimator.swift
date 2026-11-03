import AppKit

struct CreatureManifest: Decodable {
    struct Sequence: Decodable {
        let fps: Double
        let frameCount: Int
        let loop: Bool
        let duration: Double
    }
    let sequences: [String: Sequence]
}

// Routes only confirmed system states; animation never changes power settings.
enum CreatureRoute {
    static func idle(_ awake: Bool) -> String { awake ? "awake" : "sleep" }
    static func transition(from previous: Bool?, to awake: Bool) -> String? {
        guard let previous, previous != awake else { return nil }
        return awake ? "wake" : "settle"
    }
}

@MainActor final class CreatureAnimator {
    private let view: NSImageView
    private var frames: [String: [NSImage]] = [:]
    private var manifest: CreatureManifest?
    private var confirmedState: Bool?
    private var playback: Task<Void, Never>?
    var isLoaded: Bool { manifest != nil && frames.count == 4 }

    init(view: NSImageView) { self.view = view }

    func load(bundle: Bundle = .main) throws {
        guard let resources = bundle.resourceURL else { throw failure("Missing animation resources.") }
        let root = resources.appendingPathComponent("Creature")
        let manifest = try JSONDecoder().decode(CreatureManifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        var loaded: [String: [NSImage]] = [:]
        for key in ["awake", "sleep", "wake", "settle"] {
            guard let spec = manifest.sequences[key], spec.frameCount > 0,
                  spec.fps > 0, spec.fps <= 60 else { throw failure("Invalid animation: \(key)") }
            loaded[key] = try (0..<spec.frameCount).map { index in
                let filename = String(format: "%03d.png", index)
                let url = root.appendingPathComponent(key).appendingPathComponent(filename)
                guard let image = NSImage(contentsOf: url) else { throw failure("Missing animation frame: \(key)/\(filename)") }
                image.isTemplate = false
                image.size = NSSize(width: 28, height: 28)
                return image
            }
        }
        frames = loaded
        self.manifest = manifest
    }

    func show(awake: Bool) {
        guard isLoaded else { return }
        guard confirmedState != awake else { return }
        let transition = CreatureRoute.transition(from: confirmedState, to: awake)
        confirmedState = awake
        playback?.cancel()
        let idle = CreatureRoute.idle(awake)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            view.image = frames[idle]?.first
            return
        }
        playback = Task { [weak self] in
            guard let self else { return }
            if let transition { await play(transition) }
            guard !Task.isCancelled else { return }
            await play(idle)
        }
    }

    func stop() {
        playback?.cancel()
        playback = nil
        confirmedState = nil
    }

    private func play(_ key: String) async {
        guard let images = frames[key], let spec = manifest?.sequences[key] else { return }
        let started = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                view.image = frames[CreatureRoute.idle(confirmedState ?? false)]?.first
                return
            }
            let frame = Int((ProcessInfo.processInfo.systemUptime - started) * spec.fps)
            if !spec.loop && frame >= images.count {
                view.image = images.last
                return
            }
            view.image = images[spec.loop ? frame % images.count : frame]
            do { try await Task.sleep(for: .seconds(1 / spec.fps)) } catch { return }
        }
    }

    private func failure(_ description: String) -> NSError {
        NSError(domain: "KeepAwake.Animation", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
