import SwiftUI
import FanControlCore

struct ControlsView: View {
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var setup = false
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let d = model.device {
                    if let p = d.panel, p.type == "driving" {
                        let rgb = p.color ?? [92, 225, 193]
                        Rectangle().fill(Color(red: Double(rgb[0])/255, green: Double(rgb[1])/255, blue: Double(rgb[2])/255)).frame(height: 5).accessibilityHidden(true)
                    }
                    if let p = d.panel, p.type != "fan" { panel(p) } else { device(d) }
                } else if model.connection != nil {
                    Text("Set up a panel in Home Assistant").font(.headline)
                    Text("Fan Control → Configure → Manage watch panels. Select this watch, then add or activate a panel.").font(.caption)
                } else {
                    Image(systemName: "fan.fill").font(.largeTitle).foregroundStyle(.mint)
                    Text("Fan Control").font(.headline)
                    Text("Connect to Home Assistant").font(.caption)
                    Button("Pair watch") { setup = true }
                }
            }.padding(.horizontal, 5)
        }
        .persistentSystemOverlays(.hidden)
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            model.swipe(value.translation.width < 0 ? 1 : -1)
        })
        .contextMenu { Button("Connection settings") { setup = true } }
        .onOpenURL { url in
            if url.scheme == "fancontrol", url.host == "active" { model.enter() }
        }
        .sheet(isPresented: $setup, onDismiss: { model.enter() }) { SetupView(model: model) }
        .onAppear { model.enter() }
        .onDisappear { model.leave() }
        .onChange(of: scenePhase) { _, phase in if phase == .active && !setup { model.enter() } else { model.leave() } }
        .onChange(of: setup) { _, value in if value { model.leave() } }
    }
    private func control(_ action: String, _ label: String, known: Bool = true, enabled: Bool = true) -> some View {
        let applies = model.feedback?.command == action
        let feedback = applies ? model.feedback : nil
        let gray = !model.stateFresh || (feedback?.gray ?? !known)
        let shown = feedback?.label ?? label
        return Button { model.send(action, label: label) } label: {
            Text(shown).frame(maxWidth: .infinity, minHeight: 40).foregroundStyle(gray ? Color.gray : Color.mint)
        }
        .tint(gray ? Color.gray.opacity(0.25) : Color.mint.opacity(0.18))
        .disabled(model.busy || !enabled || !model.stateFresh)
    }
    @ViewBuilder private func device(_ d: Device) -> some View {
        let state = model.observed["state"] as? String
        let available = state == "on" || state == "off"
        if ["script", "scene"].contains(d.domain) {
            control("activate", "Run", known: false, enabled: state != nil && state != "unavailable" && state != "unknown")
        } else if ["fan", "light", "switch", "input_boolean"].contains(d.domain) {
            // Label projects the absolute next state immediately on the originating control.
            let pending = model.feedback?.phase != .confirmed && (model.feedback?.command == "turn_on" || model.feedback?.command == "turn_off")
            let action = pending ? model.feedback!.command : state == "on" ? "turn_off" : "turn_on"
            control(action, pending ? model.feedback!.label : state == "on" ? "ON" : state == "off" ? "OFF" : "UNKNOWN", known: available, enabled: available)
                
            if d.domain == "fan" {
                let percentage = (model.observed["attributes"] as? [String: Any])?["percentage"] as? Int
                let speed = percentage.flatMap { value in Evidence.percentages.firstIndex(where: { $0 >= value }).map { $0 + 1 } }
                HStack {
                    Button("−") { model.adjust(-1) }.disabled(!model.canAdjustSpeed || percentage == nil)
                    Text(model.speedDraft.map(String.init) ?? (model.feedback?.command.hasPrefix("speed") == true ? model.feedback!.label : speed.map(String.init) ?? "?"))
                        .foregroundStyle(!model.stateFresh || percentage == nil || model.speedDraft != nil || model.feedback?.command.hasPrefix("speed") == true && model.feedback!.gray ? Color.gray : Color.mint)
                    Button("+") { model.adjust(1) }.disabled(!model.canAdjustSpeed || percentage == nil)
                }
                .tint(.mint)
            }
        } else { Text("Controls unavailable").foregroundStyle(.gray) }
    }
    @ViewBuilder private func panel(_ p: Panel) -> some View {
        if p.type == "driving" {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                cover("garage", "Garage")
                cover("trunk", "Trunk")
                climate(p)
                actionControl("honk", "Honk Horn", enabled: model.observed["honk_available"] as? Bool == true)
            }
        } else if p.type == "exercise" {
            actionControl("start_exercise", "Start exercise", enabled: model.observed["start_available"] as? Bool == true)
            actionControl("stop_exercise", "Stop exercise", enabled: model.observed["stop_available"] as? Bool == true)
        } else {
            let battery = model.observed["battery"] as? Double
            Text(battery.map { String(format: "%.0f%%", $0) } ?? "?%")
                .foregroundStyle(model.stateFresh && battery != nil ? Color.mint : Color.gray)
            climate(p)
            actionControl("leave", p.script_label ?? "Leave for work", enabled: model.observed["script_available"] as? Bool == true)
        }
    }
    private func actionControl(_ action: String, _ label: String, enabled: Bool) -> some View {
        let receipt = model.actionFeedback(action)
        let gray = receipt.map { $0.phase != .accepted } ?? (!model.stateFresh || !enabled)
        return Button { model.send(action, label: label) } label: {
            Text(receipt == nil ? label : "Activated")
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(gray ? Color.gray : Color.mint)
        }
        .tint(gray ? Color.gray.opacity(0.25) : Color.mint.opacity(0.18))
        .disabled(model.busy || !enabled || !model.stateFresh)
    }
    private func climate(_ p: Panel) -> some View {
        let on = model.observed["climate_on"] as? Bool == true
        let pending = model.feedback?.phase != .confirmed && model.feedback?.command.hasPrefix("climate_") == true
        let action = pending ? model.feedback!.command : on ? "climate_off" : "climate_on"
        let available = model.observed["climate_available"] as? Bool == true &&
            (!on || p.type != "driving" || model.observed["climate_off_available"] as? Bool == true)
        return control(action, "\(p.climate_label ?? "Climate")\n\(on ? "ON" : "OFF")", known: available, enabled: available)
    }
    private func cover(_ role: String, _ title: String) -> some View {
        let observed = model.observed[role + "_state"] as? String
        let matching = model.feedback?.command.hasPrefix(role + "_") == true
        let action = matching && model.feedback?.phase != .confirmed ? model.feedback!.command : role + "_" + Evidence.coverIntent(observed)
        return control(action, title + "\n" + (["open", "closed", "opening", "closing"].contains(observed ?? "") ? observed!.uppercased() : "CLOSED"), known: observed == "open" || observed == "closed", enabled: observed != "opening" && observed != "closing")
    }
}

struct SetupView: View {
    @ObservedObject var model: WatchModel
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var status = "Enter your Home Assistant local or HTTPS address."
    @State private var pairing: Task<Void, Never>?
    var body: some View {
        ScrollView { VStack {
            Text("Home Assistant").font(.headline)
            if model.connection != nil {
                Text("Paired. Configure devices and panels in Home Assistant.")
                Text("Watch ID: \(model.connection!.watch_id)").font(.caption2)
                Button("Forget connection", role: .destructive) { model.forget(); dismiss() }
            } else {
                TextField("https://home.example", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text(status).font(.caption2)
                Button(pairing == nil ? "Pair" : "Cancel pairing") {
                    if let pairing { pairing.cancel(); self.pairing = nil; status = "Pairing cancelled"; return }
                    pairing = Task {
                        do {
                            let c = try await Pairing().run(address: address.trimmingCharacters(in: .whitespacesAndNewlines)) { status = $0 }
                            guard !Task.isCancelled else { return }; model.paired(c); dismiss()
                        } catch { if !Task.isCancelled { status = "Pairing not completed. Check address and try again." } }
                        pairing = nil
                    }
                }
            }
            Link("Source · AGPL-3.0-only", destination: URL(string: "https://github.com/agawlbb/FanControlWatch")!).font(.caption2)
        } }
        .onDisappear { pairing?.cancel() }
    }
}



