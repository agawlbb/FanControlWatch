import Foundation

// Settings is a local page after the approved controls, never an HA selection.
public enum WatchPage: Equatable, Sendable {
    case device(String)
    case settings

    public static func next(_ current: Self, entities: [String], direction: Int) -> Self {
        let pages = entities.map { Self.device($0) } + [.settings]
        let index = pages.firstIndex(of: current) ?? 0
        let delta = direction >= 0 ? 1 : -1
        return pages[(index + delta + pages.count) % pages.count]
    }
}
