import AppKit
import ServiceManagement
import SwiftUI

private struct LoginItemToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    var body: some View {
        Toggle("Open at login", isOn: Binding(get: { enabled }, set: update))
        Text(message ?? "Starts the panel when you log in. Keep the app in your Applications folder so macOS can find it.")
            .font(.callout)
            .foregroundStyle(message == nil ? .secondary : Color.red)
    }

    private func update(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        enabled = status == .enabled
        if status == .requiresApproval {
            message = "Approve it in System Settings, under General, then Login Items."
        }
    }
}

struct PanelTab: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section("General") {
                LoginItemToggle()
            }
            Section("Alerts") {
                Toggle("Flash a lamp when its Claude starts waiting", isOn: $prefs.attentionBurst)
                Toggle("Also flash, more gently, when a Claude finishes", isOn: $prefs.finishBurst)
                    .disabled(!prefs.attentionBurst)
                LabeledContent("Only after it has worked for") {
                    HStack {
                        Slider(value: $prefs.finishMinimum, in: 0...60, step: 5)
                            .frame(width: 160)
                        Text(prefs.finishMinimum == 0 ? "any time" : "\(Int(prefs.finishMinimum)) s")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                .disabled(!prefs.attentionBurst || !prefs.finishBurst)
                Text("A brief burst that fires once, in the style of the current theme, so a waiting lamp is hard to miss. The finish flash is a softer blue version, and only plays after a Claude has worked for the time you choose, so quick replies stay quiet. Both are skipped when Reduce Motion is on.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("Layout") {
                Picker("Theme", selection: $prefs.theme) {
                    ForEach(PanelTheme.all) { Text($0.name).tag($0.id) }
                }
                Toggle("Stack the lamps vertically", isOn: $prefs.vertical)
                Toggle("Show a background behind the lamps", isOn: $prefs.showBackground)
                Toggle("Keep the panel above other windows", isOn: $prefs.alwaysOnTop)
                Toggle("Show each group's place name", isOn: $prefs.showPlaceLabel)
                Toggle("Show each group's tmux session name", isOn: $prefs.showSessionLabel)
            }
        }
        .formStyle(.grouped)
    }
}

struct PlacesTab: View {
    @ObservedObject var prefs: Preferences
    @State private var selection: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 200)
            Divider()
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { if selection == nil { selection = prefs.places.first?.id } }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach($prefs.places) { $place in
                    HStack(spacing: 8) {
                        Toggle("Show on the panel", isOn: $place.enabled)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        Text(place.name.isEmpty ? "Untitled" : place.name).lineLimit(1)
                    }
                    .tag(place.id)
                }
            }
            .listStyle(.sidebar)
            Divider()
            HStack(spacing: 0) {
                Button(action: addPlace) { Image(systemName: "plus").frame(width: 28, height: 24) }
                    .help("Add a place")
                Button(action: removePlace) { Image(systemName: "minus").frame(width: 28, height: 24) }
                    .help("Remove the selected place")
                    .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var detail: some View {
        if let index = prefs.places.firstIndex(where: { $0.id == selection }) {
            PlaceForm(place: $prefs.places[index])
        } else {
            Text("Add a place with the + button.").foregroundStyle(.secondary)
        }
    }

    private func addPlace() {
        let place = Place(name: "New place", kind: .ssh, enabled: false)
        prefs.places.append(place)
        selection = place.id
    }

    private func removePlace() {
        guard let selection, let index = prefs.places.firstIndex(where: { $0.id == selection }) else { return }
        prefs.places.remove(at: index)
        self.selection = prefs.places.first?.id
    }
}

private struct PlaceForm: View {
    @Binding var place: Place

    var body: some View {
        Form {
            TextField("Name", text: $place.name)
            Picker("Where", selection: $place.kind) {
                ForEach(PlaceKind.allCases) { Text($0.title).tag($0) }
            }
            if place.kind != .local {
                TextField(
                    place.kind == .ssh ? "Computer" : "Address",
                    text: $place.address,
                    prompt: Text(place.kind == .ssh ? "myserver or user@host" : "127.0.0.1:47500")
                )
                .autocorrectionDisabled()
                if place.connection == nil, !place.address.isEmpty {
                    Text("That doesn't look right.").foregroundStyle(.red)
                }
            }
            Text(place.kind.hint).font(.callout).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
