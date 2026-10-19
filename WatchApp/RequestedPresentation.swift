import Foundation
import FanControlCore

// Networking is foreground-only. Snapshots never include optimistic projections.
struct RequestedPresentation {
    static func label(command: String, original: String) -> String {
        switch command {
        case "turn_on": return "ON"
        case "turn_off": return "OFF"
        case "climate_on": return "Climate ON"
        case "climate_off": return "Climate OFF"
        case "activate", "leave": return original
        case "start_exercise": return "LOCKED"
        case "stop_exercise": return "UNLOCKED · CLIMATE ON"
        default:
            if command.hasSuffix("_open") { return original.components(separatedBy: "\n")[0] + "\nOPEN" }
            if command.hasSuffix("_close") { return original.components(separatedBy: "\n")[0] + "\nCLOSED" }
            return original
        }
    }
}
