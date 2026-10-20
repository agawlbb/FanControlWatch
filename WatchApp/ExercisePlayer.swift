import SwiftUI
import AVFoundation
import CryptoKit
import WatchKit
import FanControlCore

// The player belongs to the process, not the visible panel. Wrist-down and panel
// navigation must not destroy ongoing audio. No HA/vehicle result confirms music.
@MainActor final class ExercisePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = ExercisePlayer()
    @Published private(set) var playing = false
    @Published private(set) var beganPlayback = false
    @Published private(set) var waiting = false
    @Published private(set) var syncing = false
    @Published private(set) var status = ""
    private var player: AVAudioPlayer?
    private var tracks: [ExerciseTrack] = []
    private var index = 0
    private var folder: URL?
    private var scope: String?
    private var sessionTarget: Device?
    private var active = false
    private var wantsPlayback = false
    private var speakerChosen = false
    private var activation = UUID()
    private var syncTask: Task<Void, Never>?
    private var syncGeneration = UUID()
    private var routeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private let session = AVAudioSession.sharedInstance()

    private struct Library: Codable { let directory: String; let tracks: [ExerciseTrack] }
    private var musicDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseMusic")
    }
    private func root(_ c: Connection) -> URL {
        let key = c.url + "|" + (c.remote_url ?? "") + "|" + c.watch_id + "|" + c.token
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return musicDirectory.appendingPathComponent(digest)
    }
    override private init() {
        super.init()
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.routeChanged() }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            if began { Task { @MainActor in self?.pause() } }
        }
    }
    func load(_ c: Connection) {
        let location = root(c)
        guard scope != location.path else { return }
        stop(); tracks = []; folder = nil; scope = location.path
        guard let data = try? Data(contentsOf: location.appendingPathComponent("playlist.json")),
              let library = try? JSONDecoder().decode(Library.self, from: data),
              UUID(uuidString: library.directory) != nil, (1...25).contains(library.tracks.count),
              library.tracks.allSatisfy({ (try? $0.validate()) != nil }) else { return }
        let saved = location.appendingPathComponent(library.directory)
        guard library.tracks.allSatisfy({ FileManager.default.fileExists(atPath: saved.appendingPathComponent($0.fileName).path) }) else { return }
        tracks = library.tracks; folder = saved
    }
    func start(_ c: Connection, target: Device) {
        guard !syncing else { status = "Finish music sync first"; return }
        load(c); stop(); sessionTarget = target; active = true; wantsPlayback = true
        guard !tracks.isEmpty else { status = "Sync music in Connection settings"; return }
        waiting = true; status = "Waiting for headset"
        activate()
    }
    func stopIfTargetChanged(_ c: Connection) {
        guard active, let sessionTarget else { return }
        // Compare typed configuration, not JSON text whose key order can vary.
        if scope != root(c).path || !c.devices.contains(sessionTarget) { stop() }
    }
    func stop() {
        activation = UUID(); active = false; wantsPlayback = false; speakerChosen = false; sessionTarget = nil
        player?.stop(); player = nil; index = 0; playing = false; beganPlayback = false; waiting = false; status = ""
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
    func forget() {
        syncGeneration = UUID(); syncTask?.cancel(); syncTask = nil; syncing = false; stop()
        // Delete persisted copies even if no library was loaded this launch.
        try? FileManager.default.removeItem(at: musicDirectory)
        UserDefaults.standard.removeObject(forKey: "exerciseHeadsetUID")
        scope = nil; tracks = []; folder = nil
    }
    func useSpeaker() {
        guard active, !tracks.isEmpty else { return }
        speakerChosen = true; wantsPlayback = true
        // Apple controls destination selection. Never force speaker output or
        // assume that accepting a picker actually selected the requested route.
        activate()
    }
    private func activate() {
        let ticket = UUID(); activation = ticket
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            session.activate(options: []) { [weak self] success, _ in
                Task { @MainActor in
                    guard let self, self.active, self.activation == ticket else { return }
                    if success { self.routeChanged() }
                    else { self.playing = false; self.waiting = true; self.status = "Waiting for headset" }
                }
            }
        } catch { status = "Audio not available"; waiting = true }
    }
    private func allowedRoute() -> Bool {
        let outputs = session.currentRoute.outputs
        guard !outputs.isEmpty else { return false }
        return outputs.allSatisfy { port in
            let bluetooth = [AVAudioSession.Port.bluetoothA2DP, .bluetoothLE, .bluetoothHFP].contains(port.portType)
            let preferred = bluetooth && ExerciseAudioRoute.isPreferred(name: port.portName, uid: port.uid, rememberedUID: UserDefaults.standard.string(forKey: "exerciseHeadsetUID"))
            if preferred { UserDefaults.standard.set(port.uid, forKey: "exerciseHeadsetUID") }
            return ExerciseAudioRoute.mayPlay(preferredHeadset: preferred, builtInSpeaker: port.portType == .builtInSpeaker, speakerChosen: speakerChosen)
        }
    }
    private func routeChanged() {
        guard active else { return }
        guard allowedRoute() else {
            let lost = playing
            player?.pause(); playing = false; beganPlayback = false; waiting = true
            if lost { speakerChosen = false; wantsPlayback = true }
            status = speakerChosen ? "Choose Watch speaker in Control Center" : "Waiting for headset"; return
        }
        waiting = false
        if wantsPlayback { playCurrent() }
    }
    private func playCurrent() {
        guard active, allowedRoute(), !tracks.isEmpty, let folder else { return }
        do {
            if player == nil {
                player = try AVAudioPlayer(contentsOf: folder.appendingPathComponent(tracks[index].fileName))
                player?.delegate = self
            }
            playing = player?.play() == true
            beganPlayback = beganPlayback || playing
            status = playing ? "" : "Playback not confirmed"
        } catch { playing = false; status = "Track could not play" }
    }
    func pause() { wantsPlayback = false; player?.pause(); playing = false }
    func toggle() {
        if playing { pause() }
        else { wantsPlayback = true; activate() }
    }
    func skip(_ delta: Int) {
        guard active, !tracks.isEmpty else { return }
        let resume = wantsPlayback
        player?.stop(); player = nil; index = (index + delta + tracks.count) % tracks.count
        playing = false
        if resume { routeChanged() }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player, self.active else { return }
            if flag { self.skip(1) }
            else { self.pause(); self.status = "Track could not play" }
        }
    }
    func sync(_ c: Connection) {
        guard !syncing else { return }
        load(c); stop(); syncing = true; status = "Syncing music…"
        let syncTicket = UUID(); syncGeneration = syncTicket
        let destination = root(c)
        syncTask = Task {
            let staging = destination.appendingPathComponent(UUID().uuidString)
            defer { if syncGeneration == syncTicket { syncing = false; syncTask = nil } }
            do {
                let client = Integration(c)
                let result = try await client.request(["action": "exercise_music_list"])
                let list = try JSONDecoder().decode([ExerciseTrack].self, from: JSONSerialization.data(withJSONObject: result["tracks"] ?? []))
                guard (1...25).contains(list.count), Set(list.map(\.name)).count == list.count else { throw ControlError.invalidResponse }
                try list.forEach { try $0.validate() }
                guard list.reduce(0, { $0 + $1.size }) <= 200 * 1024 * 1024 else { throw ControlError.invalidResponse }
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                for (number, track) in list.enumerated() {
                    status = "Syncing \(number + 1)/\(list.count)"
                    let file = staging.appendingPathComponent(track.fileName)
                    FileManager.default.createFile(atPath: file.path, contents: nil)
                    let output = try FileHandle(forWritingTo: file)
                    do {
                        var offset = 0; var digest = SHA256()
                        while offset < track.size {
                            try Task.checkCancellation()
                            let response = try await client.request(["action": "exercise_music_chunk", "name": track.name, "offset": offset])
                            guard response["offset"] as? Int == offset, let raw = response["data"] as? String,
                                  let data = Data(base64Encoded: raw), !data.isEmpty, data.count <= 196608,
                                  offset + data.count <= track.size else { throw ControlError.invalidResponse }
                            try output.write(contentsOf: data); digest.update(data: data); offset += data.count
                        }
                        guard digest.finalize().map({ String(format: "%02x", $0) }).joined() == track.sha256 else { throw ControlError.invalidResponse }
                        try output.close()
                    } catch { try? output.close(); throw error }
                }
                try Task.checkCancellation()
                guard syncTicket == syncGeneration else { throw CancellationError() }
                let library = Library(directory: staging.lastPathComponent, tracks: list)
                try JSONEncoder().encode(library).write(to: destination.appendingPathComponent("playlist.json"), options: .atomic)
                let old = folder; tracks = list; folder = staging
                if let old, old != staging { try? FileManager.default.removeItem(at: old) }
                status = "\(list.count) tracks ready offline"
            } catch {
                try? FileManager.default.removeItem(at: staging)
                if !Task.isCancelled, syncTicket == syncGeneration { status = "Music sync failed; previous tracks kept" }
            }
        }
    }
    #if DEBUG && targetEnvironment(simulator)
    func preview(playing: Bool) {
        // Rendering fixtures contain no audio and never activate an audio session.
        self.playing = playing; beganPlayback = playing; waiting = !playing
        status = playing ? "" : "Waiting for headset"
    }
    #endif
}

struct ExercisePlaybackView: View {
    @ObservedObject private var player = ExercisePlayer.shared
    var body: some View {
        VStack(spacing: 2) {
            if player.beganPlayback && !player.waiting {
                HStack(spacing: 2) {
                    Button { player.skip(-1) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                    Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill") }.accessibilityLabel(player.playing ? "Pause" : "Play")
                    Button { player.skip(1) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                }.tint(.mint)
                WatchVolume().frame(height: 28)
            } else if player.waiting {
                Text(player.status).font(.caption2).foregroundStyle(.gray)
                Button("Use watch speaker") { player.useSpeaker() }.font(.caption2)
            } else if !player.status.isEmpty {
                Text(player.status).font(.caption2).foregroundStyle(.gray)
            }
        }
    }
}

// Native system volume, including Crown interaction; never simulate system
// volume by changing the player's per-track gain.
private struct WatchVolume: WKInterfaceObjectRepresentable {
    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .local)
    }
    func updateWKInterfaceObject(_ object: WKInterfaceVolumeControl, context: Context) {}
}
