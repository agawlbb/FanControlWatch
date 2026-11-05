import SwiftUI
import UIKit
import UniformTypeIdentifiers
import FanControlCore
import UserNotifications

struct CompanionView: View {
    @ObservedObject private var model = PhoneModel.shared
    @ObservedObject private var library = PhoneLibrary.shared
    @State private var importing = false
    @State private var showingSettings = false
    @State private var editMode: EditMode = .active
    var body: some View {
        NavigationStack {
            List {
                if model.connection == nil {
                    Button("Link watch", action: model.link)
                } else {
                    Section("Messages") {
                        if model.messages.isEmpty { Text("No messages").foregroundStyle(.secondary) }
                        ForEach(model.messages) { message in
                            Button { model.selectedMessage = message } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.title).font(.headline)
                                    Text(message.message).lineLimit(2).foregroundStyle(.secondary)
                                }
                            }.moveDisabled(true).deleteDisabled(true)
                        }
                    }
                    Section("Tiles") {
                        ForEach(model.orderedDevices, id: \.entity) { device in
                            HStack {
                                Text(device.title)
                                Spacer()
                                if device.entity == model.connection?.entity { Image(systemName: "checkmark").foregroundStyle(.mint).accessibilityLabel("Active panel") }
                            }
                        }.onMove(perform: model.move).moveDisabled(model.saving)
                    }
                    Section("Exercise music") {
                        ForEach(library.tracks, id: \.fileName) { track in Text((track.name as NSString).deletingPathExtension) }
                            .onMove(perform: library.move).onDelete(perform: library.remove)
                        HStack {
                            Button("Add", systemImage: "plus") { importing = true }
                            Spacer()
                            Button("Sync", systemImage: "arrow.triangle.2.circlepath", action: library.sync)
                        }.buttonStyle(.borderless).moveDisabled(true).deleteDisabled(true)
                        if !library.status.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                if library.status != "On watch" { ProgressView(value: library.progress) }
                                Text(library.status).foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                }
                if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
                if !library.error.isEmpty { Text(library.error).foregroundStyle(.red) }
            }
            .task {
                while !Task.isCancelled {
                    library.updateProgress()
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Fan Control")
            .tint(.mint)
            .toolbar {
                if model.connection != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .refreshable { _ = await model.refresh() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.mp3, .mpeg4Audio, UTType(filenameExtension: "aac") ?? .audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): library.importFiles(urls)
                case .failure: library.error = "Import failed"
                }
            }
        }
        .onChange(of: model.connection == nil) { _, unlinked in if unlinked { showingSettings = false } }
        .onChange(of: model.selectedMessage?.id) { _, value in
            if value != nil { showingSettings = false; importing = false }
        }
        .sheet(isPresented: Binding(
            get: { model.selectedMessage != nil || showingSettings },
            set: { if !$0 { model.selectedMessage = nil; showingSettings = false } }
        )) {
            NavigationStack {
                if let message = model.selectedMessage {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(message.title).font(.title2.bold())
                            Text(message.message).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                    .navigationTitle("Message")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.selectedMessage = nil } } }
                } else {
                    SettingsView()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSettings = false } } }
                }
            }.environment(\.editMode, .constant(.inactive))
        }
        .onAppear {
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--preview-settings") { showingSettings = true }
            #endif
        }
    }
}

private struct SettingsView: View {
    @ObservedObject private var model = PhoneModel.shared
    @State private var headset = ""
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var enablingNotifications = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL
    var body: some View {
        Form {
            Section("Headset") {
                TextField("Name", text: $headset)
                    .autocorrectionDisabled()
                    .onSubmit { model.settings.headset = headset; model.saveSettings() }
                Button("Save") { model.settings.headset = headset; model.saveSettings() }.disabled(model.saving)
            }
            Section("Notifications") {
                if notificationStatus == .notDetermined {
                    Button("Enable notifications") {
                        enablingNotifications = true
                        Task { @MainActor in
                            defer { enablingNotifications = false }
                            do {
                                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                                UIApplication.shared.registerForRemoteNotifications()
                                await model.registerPush()
                            } catch { model.error = "Could not enable notifications. Try again." }
                        }
                    }.disabled(enablingNotifications)
                } else {
                    LabeledContent("Alerts", value: notificationStatus == .denied ? "Disabled" : "Allowed")
                    Button("Notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
                Text("Home Assistant automations can send alerts to this iPhone. They may appear on your Apple Watch depending on your settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Connection") {
                LabeledContent("Watch", value: model.reachable ? "Connected" : "Unavailable")
                if let c = model.connection { Text(c.url).foregroundStyle(.secondary).textSelection(.enabled) }
                Button("Refresh") { Task { _ = await model.refresh() } }
                Button("Relink watch", action: model.link)
                Button("Unlink phone", role: .destructive, action: model.unlink)
            }
            NavigationLink("Diagnostics") {
                List {
                    if let date = model.refreshedAt { LabeledContent("Last update", value: date.formatted()) }
                    LabeledContent("Watch snapshot", value: model.watchSequence > 0 ? String(model.watchSequence) : "Unknown")
                    ForEach(Array(model.events.enumerated()), id: \.offset) { _, value in Text(value).font(.caption.monospaced()) }
                }.navigationTitle("Diagnostics")
            }
            if !model.error.isEmpty { Text(model.error).foregroundStyle(.red) }
        }.navigationTitle("Settings")
            .onAppear { headset = model.settings.headset }
            .task(id: phase) {
                notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            }
    }
}
