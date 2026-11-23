import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Shell

struct SettingsSidebar: View {
    @ObservedObject var selection: SettingsSelection

    var body: some View {
        List(SettingsSection.allCases, selection: binding) { section in
            Label {
                Text(section.title)
            } icon: {
                SettingsIcon(symbol: section.symbol, color: section.color)
            }
            .tag(section)
        }
        .listStyle(.sidebar)
    }

    private var binding: Binding<SettingsSection?> {
        Binding(get: { selection.section }, set: { if let section = $0 { selection.section = section } })
    }
}

struct SettingsDetail: View {
    @ObservedObject var selection: SettingsSelection
    @ObservedObject var prefs: Preferences

    var body: some View {
        switch selection.section {
        case .general: GeneralSettings(prefs: prefs)
        case .appearance: AppearanceSettings(prefs: prefs)
        case .alerts: AlertsSettings(prefs: prefs)
        case .places: PlacesSettings(prefs: prefs)
        }
    }
}

/// Colored rounded-square icon, like System Settings.
private struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(color.gradient))
    }
}

/// Explanatory text under a form section.
private struct Footnote: View {
    let text: String
    var isError = false

    init(_ text: String, isError: Bool = false) {
        self.text = text
        self.isError = isError
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(isError ? Color.red : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            LoginItemSection()
            Section {
                Toggle("Keep the panel above other windows", isOn: $prefs.alwaysOnTop)
            } footer: {
                Footnote("The panel also stays over fullscreen apps.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct LoginItemSection: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    var body: some View {
        Section {
            Toggle("Open at login", isOn: Binding(get: { enabled }, set: update))
        } footer: {
            Footnote(message ?? "Starts the panel when you log in. Keep the app in your Applications folder so macOS can find it.",
                     isError: message != nil)
        }
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

// MARK: - Appearance

private struct AppearanceSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $prefs.theme) {
                    ForEach(PanelTheme.all) { Text($0.name).tag($0.id) }
                }
            }
            Section("Lamps") {
                Toggle("Stack the lamps vertically", isOn: $prefs.vertical)
                Toggle("Show a background behind the lamps", isOn: $prefs.showBackground)
            }
            Section("Labels") {
                Toggle("Show each group's place name", isOn: $prefs.showPlaceLabel)
                Toggle("Show each group's tmux session name", isOn: $prefs.showSessionLabel)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Alerts

private struct AlertsSettings: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        Form {
            Section {
                Toggle("Flash a lamp when its Claude starts waiting", isOn: $prefs.attentionBurst)
            } footer: {
                Footnote("A brief burst that fires once, in the style of the current theme, so a waiting lamp is hard to miss.")
            }
            Section {
                Toggle("Also flash, more gently, when a Claude finishes", isOn: $prefs.finishBurst)
                LabeledContent("Only after it has worked for") {
                    HStack {
                        Slider(value: $prefs.finishMinimum, in: 0...60, step: 5)
                            .frame(width: 160)
                        Text(prefs.finishMinimum == 0 ? "any time" : "\(Int(prefs.finishMinimum)) s")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                .disabled(!prefs.finishBurst)
            } footer: {
                Footnote("The finish flash is a softer blue version, and only plays after a Claude has worked for the time you choose, so quick replies stay quiet. Both flashes are skipped when Reduce Motion is on.")
            }
            .disabled(!prefs.attentionBurst)
        }
        .formStyle(.grouped)
    }
}

// MARK: - Places

private struct PlacesSettings: View {
    @ObservedObject var prefs: Preferences
    @State private var sheet: PlaceSheet?

    private enum PlaceSheet: Identifiable {
        case add(Place)
        case edit(String)

        var id: String {
            switch self {
            case .add(let place): "add-\(place.id)"
            case .edit(let id): id
            }
        }
    }

    var body: some View {
        Form {
            Section {
                if prefs.places.isEmpty {
                    Text("No places yet").foregroundStyle(.secondary)
                }
                ForEach($prefs.places) { $place in
                    PlaceRow(place: $place) { sheet = .edit(place.id) }
                }
            } footer: {
                HStack(alignment: .top, spacing: 16) {
                    Footnote("A place is shown on the panel only while it's switched on. With more than one place, the panel's right-click menu has a Show submenu to toggle them.")
                    Spacer(minLength: 0)
                    Button("Add Place…") { sheet = .add(Place(name: "", kind: .ssh)) }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add(let place):
                PlaceEditor(place: place, isNew: true, onSave: { prefs.places.append($0) })
            case .edit(let id):
                if let place = prefs.places.first(where: { $0.id == id }) {
                    PlaceEditor(
                        place: place,
                        isNew: false,
                        onSave: { updated in
                            if let index = prefs.places.firstIndex(where: { $0.id == id }) {
                                prefs.places[index] = updated
                            }
                        },
                        onRemove: { prefs.places.removeAll { $0.id == id } }
                    )
                }
            }
        }
    }
}

private struct PlaceRow: View {
    @Binding var place: Place
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(symbol: place.kind.symbol, color: place.kind.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name.isEmpty ? "Untitled" : place.name)
                subtitle
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Details…", action: onEdit)
                .controlSize(.small)
            Toggle("Show on the panel", isOn: $place.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }

    @ViewBuilder private var subtitle: some View {
        if place.kind != .local, place.connection == nil {
            Text(place.address.isEmpty ? "No address yet" : "That address doesn't look right")
                .foregroundStyle(.red)
        } else {
            Text(place.kind == .local ? place.kind.title : "\(place.kind.shortTitle) · \(place.address)")
                .foregroundStyle(.secondary)
        }
    }
}

/// Sheet for adding a place or editing one. Changes apply when you click Add Place / Done.
private struct PlaceEditor: View {
    @State private var draft: Place
    let isNew: Bool
    let onSave: (Place) -> Void
    var onRemove: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(place: Place, isNew: Bool, onSave: @escaping (Place) -> Void, onRemove: (() -> Void)? = nil) {
        _draft = State(initialValue: place)
        self.isNew = isNew
        self.onSave = onSave
        self.onRemove = onRemove
    }

    private var isValid: Bool { draft.kind == .local || draft.connection != nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text(namePrompt))
                    Picker("Where", selection: $draft.kind) {
                        ForEach(PlaceKind.allCases) { Text($0.title).tag($0) }
                    }
                    if draft.kind != .local {
                        TextField(
                            draft.kind == .ssh ? "Computer" : "Address",
                            text: $draft.address,
                            prompt: Text(draft.kind == .ssh ? "myserver or user@host" : "127.0.0.1:47500")
                        )
                        .autocorrectionDisabled()
                    }
                } footer: {
                    if draft.kind != .local, draft.connection == nil, !draft.address.isEmpty {
                        Footnote("That doesn't look right.", isError: true)
                    } else {
                        Footnote(draft.kind.hint)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                if let onRemove {
                    Button("Remove Place", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Place" : "Done", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 460, height: 262)
    }

    private var namePrompt: String {
        draft.kind == .local ? draft.kind.title : (draft.address.isEmpty ? "Optional" : draft.address)
    }

    private var defaultName: String {
        draft.kind == .local || draft.address.isEmpty ? draft.kind.shortTitle : draft.address
    }

    private func save() {
        var place = draft
        place.address = place.address.trimmingCharacters(in: .whitespaces)
        if place.name.trimmingCharacters(in: .whitespaces).isEmpty { place.name = defaultName }
        onSave(place)
        dismiss()
    }
}

private extension PlaceKind {
    var shortTitle: String {
        switch self {
        case .local: "This Mac"
        case .ssh: "SSH"
        case .tcp: "Service"
        }
    }

    var symbol: String {
        switch self {
        case .local: "laptopcomputer"
        case .ssh: "terminal.fill"
        case .tcp: "server.rack"
        }
    }

    var color: Color {
        switch self {
        case .local: .blue
        case .ssh: .indigo
        case .tcp: .orange
        }
    }
}
