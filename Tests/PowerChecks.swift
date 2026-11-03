import Foundation

@main struct PowerChecks {
    static func main() async throws {
        precondition(Power.parse("System-wide power settings:\n SleepDisabled\t0\n") == false)
        precondition(Power.parse(" SleepDisabled 1\n") == true)
        for unknown in ["", " sleep 0\n", " SleepDisabled 2\n", " SleepDisabled\n", " SleepDisabled 1 extra\n"] {
            precondition(Power.parse(unknown) == nil)
        }
        let failure = try await Power.run("/usr/bin/false", [])
        precondition(failure.status != 0)
        print("PASS: sleep-state parsing and command failure")
    }
}
