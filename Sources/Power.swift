import Foundation

struct CommandResult: Sendable {
    let status: Int32
    let output: String
}

enum Power {
    static func parse(_ output: String) -> Bool? {
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            if fields.count == 2, fields[0] == "SleepDisabled" {
                if fields[1] == "1" { return true }
                if fields[1] == "0" { return false }
            }
        }
        return nil
    }

    @concurrent static func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    static func read() async throws -> Bool {
        let result = try await run("/usr/bin/pmset", ["-g"])
        guard result.status == 0, let enabled = parse(result.output) else {
            throw NSError(domain: "KeepAwake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn’t read the Mac’s sleep setting. Try again."])
        }
        return enabled
    }
}
