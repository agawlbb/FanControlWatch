import SwiftUI
import UniformTypeIdentifiers
import FanControlCore

struct CompanionView: View {
    @ObservedObject private var model = PhoneModel.shared
    @ObservedObject private var library = PhoneLibrary.shared
    @State private var importing = false
    @State private var editMode: EditMode = .active
    var body: some View {
        NavigationStack {
            List {
                if model.connection == nil {
                    Button("Link watch", action: model.link)
                } else {
                    Section("Tiles") {
                        ForEach(model.orderedDevices, id: \.entity) { device in
                            HStack {
                                Text(device.title)
                                Spacer()
                                if device.entity == model.connection?.entity { Image(systemName: "checkmark").foregroundStyle(.mint).accessibilityLabel("Active panel") }
                            }
                        }.onMove(perform: model.move)
                    }
                    Section("Exercise music") {
                        ForEach(library.tracks, id: \.fileName) { track in Text((track.name as NSString).deletingPathExtension) }
                            .onMove(perform: library.move).onDelete(perform: library.remove)
                        HStack {
                            Button("Add", systemImage: "plus") { importing = true }
                            Spacer()
                            Button("Sync", systemImage: "arrow.triangle.2.circlepath", action: library.sync)
                        }.buttonStyle(.borderless).moveDisabled(true).deleteDisabled(true)
                        if !library.status.isEmpty { Text(library.status).foregroundStyle(.secondary).font(.caption) }
                    }
                    Section {
                        NavigationLink("Settings") { SettingsView() }
                    }
                }
                if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
                if !library.error.isEmpty { Text(library.error).foregroundStyle(.red) }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Fan Control")
            .tint(.mint)
            .refreshable { _ = await model.refresh() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.mp3, .mpeg4Audio, UTType(filenameExtension: "aac") ?? .audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): library.importFiles(urls)
                case .failure: library.error = "Import failed"
                }
            }
        }
    }
}

private struct SettingsView: View {
    @ObservedObject private var model = PhoneModel.shared
    @State private var headset = ""
    var body: some View {
        Form {
            Section("Headset") {
                TextField("Name", text: $headset)
                    .autocorrectionDisabled()
                    .onSubmit { model.settings.headset = headset; model.saveSettings() }
                Button("Save") { model.settings.headset = headset; model.saveSettings() }
            }
            Section("Connection") {
                LabeledContent("Watch", value: model.reachable ? "Connected" : "Unavailable")
                if let c = model.connection { Text(c.url).foregroundStyle(.secondary).textSelection(.enabled) }
                Button("Refresh") { Task { _ = await model.refresh() } }
                Button("Relink watch", action: model.link)
            }
            NavigationLink("Diagnostics") {
                List {
                    if let date = model.refreshedAt { LabeledContent("Last update", value: date.formatted()) }
                    LabeledContent("Watch snapshot", value: String(model.watchSequence))
                    ForEach(Array(model.events.enumerated()), id: \.offset) { _, value in Text(value).font(.caption.monospaced()) }
                }.navigationTitle("Diagnostics")
            }
            if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
        }.navigationTitle("Settings")
            .onAppear { headset = model.settings.headset }
    }
}
