import Foundation

// Settings is a local page after the approved controls, never an HA selection.
public enum WatchPage: Equatable, Sendable {
    case device(String)
    case settings

    public static func next(_ current: Self, entities: [String], active: String? = nil, direction: Int) -> Self {
        let pages = entities.map { Self.device($0) }
        guard !pages.isEmpty else { return current }
        let index = pages.firstIndex(of: current) ?? 0
        let delta = direction >= 0 ? 1 : -1
        return pages[min(pages.count - 1, max(0, index + delta))]
    }
}
