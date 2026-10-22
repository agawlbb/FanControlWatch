import Foundation

// Settings is a local page after the approved controls, never an HA selection.
public enum WatchPage: Equatable, Sendable {
    case device(String)
    case settings

    public static func next(_ current: Self, entities: [String], active: String? = nil, direction: Int) -> Self {
        let controls = active.map { a in entities.contains(a) ? [a] + entities.filter { $0 != a } : entities } ?? entities
        let pages = controls.map { Self.device($0) } + [.settings]
        let index = pages.firstIndex(of: current) ?? 0
        let delta = direction >= 0 ? 1 : -1
        return pages[min(pages.count - 1, max(0, index + delta))]
    }
}
