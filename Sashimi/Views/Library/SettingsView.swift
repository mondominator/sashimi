import SwiftUI

struct SettingsView: View {
    var showSignOut: Bool = true
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showingLogoutConfirmation = false

    var body: some View {
        List {
            Section("Home Screen") {
                NavigationLink("Row Order") {
                    HomeScreenSettingsView()
                }
            }

            Section("Playback") {
                NavigationLink("Video Quality") {
                    VideoQualitySettingsView()
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }

            if showSignOut {
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showingLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                sessionManager.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Home Screen Settings

enum HomeRowType: String, Codable, CaseIterable {
    case hero
    case continueWatching

    var displayName: String {
        switch self {
        case .hero: return "Featured"
        case .continueWatching: return "Continue Watching"
        }
    }
}

struct HomeRowConfig: Codable, Identifiable, Equatable {
    let id: String
    let type: HomeRowType?  // nil for library rows
    let libraryId: String?  // for library rows
    let libraryName: String?
    var isVisible: Bool

    var displayName: String {
        if let type = type {
            return type.displayName
        }
        return libraryName ?? "Unknown Library"
    }

    static func builtIn(_ type: HomeRowType, visible: Bool = true) -> HomeRowConfig {
        HomeRowConfig(id: type.rawValue, type: type, libraryId: nil, libraryName: nil, isVisible: visible)
    }

    static func library(id: String, name: String, visible: Bool = true) -> HomeRowConfig {
        HomeRowConfig(id: "library_\(id)", type: nil, libraryId: id, libraryName: name, isVisible: visible)
    }
}

@MainActor
class HomeScreenSettings: ObservableObject {
    static let shared = HomeScreenSettings()

    @Published var rowConfigs: [HomeRowConfig] = []
    @Published var needsRefresh = false

    private let userDefaultsKey = "homeScreenRowOrder"

    init() {
        loadSettings()
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let configs = try? JSONDecoder().decode([HomeRowConfig].self, from: data) {
            rowConfigs = configs
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(rowConfigs) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        needsRefresh = true
    }

    func updateWithLibraries(_ libraries: [JellyfinLibrary]) {
        var newConfigs: [HomeRowConfig] = []

        // Add built-in rows if not already present
        for type in HomeRowType.allCases {
            if let existing = rowConfigs.first(where: { $0.type == type }) {
                newConfigs.append(existing)
            } else {
                newConfigs.append(.builtIn(type))
            }
        }

        // Add library rows
        for library in libraries {
            if let existing = rowConfigs.first(where: { $0.libraryId == library.id }) {
                // Update name in case it changed
                var updated = existing
                if updated.libraryName != library.name {
                    updated = .library(id: library.id, name: library.name, visible: existing.isVisible)
                }
                newConfigs.append(updated)
            } else {
                newConfigs.append(.library(id: library.id, name: library.name))
            }
        }

        // Remove library rows that no longer exist
        rowConfigs = newConfigs.filter { config in
            if config.libraryId != nil {
                return libraries.contains { $0.id == config.libraryId }
            }
            return true
        }

        // Preserve order from saved settings
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedConfigs = try? JSONDecoder().decode([HomeRowConfig].self, from: data) {
            let savedOrder = savedConfigs.map { $0.id }
            rowConfigs.sort { a, b in
                let indexA = savedOrder.firstIndex(of: a.id) ?? Int.max
                let indexB = savedOrder.firstIndex(of: b.id) ?? Int.max
                return indexA < indexB
            }
        }
    }

    func moveRow(from source: IndexSet, to destination: Int) {
        rowConfigs.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    func toggleVisibility(for config: HomeRowConfig) {
        if let index = rowConfigs.firstIndex(where: { $0.id == config.id }) {
            rowConfigs[index].isVisible.toggle()
            saveSettings()
        }
    }

    func isRowVisible(_ type: HomeRowType) -> Bool {
        rowConfigs.first { $0.type == type }?.isVisible ?? true
    }

    func isLibraryVisible(_ libraryId: String) -> Bool {
        rowConfigs.first { $0.libraryId == libraryId }?.isVisible ?? true
    }

    func orderedLibraryIds() -> [String] {
        rowConfigs.compactMap { $0.libraryId }
    }
}

struct HomeScreenSettingsView: View {
    @StateObject private var settings = HomeScreenSettings.shared
    @State private var isEditing = false

    var body: some View {
        List {
            Section {
                ForEach(settings.rowConfigs) { config in
                    HStack {
                        Button {
                            settings.toggleVisibility(for: config)
                        } label: {
                            Image(systemName: config.isVisible ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(config.isVisible ? .green : .gray)
                        }
                        .buttonStyle(.plain)

                        Text(config.displayName)
                            .foregroundStyle(config.isVisible ? .primary : .secondary)

                        Spacer()

                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove { source, destination in
                    settings.moveRow(from: source, to: destination)
                }
            } header: {
                Text("Drag to reorder, tap to show/hide")
            }
        }
        .navigationTitle("Home Screen Rows")
        .environment(\.editMode, .constant(.active))
    }
}

struct VideoQualitySettingsView: View {
    @AppStorage("maxBitrate") private var maxBitrate = 20_000_000

    let bitrateOptions = [
        (label: "Auto", value: 0),
        (label: "4K - 120 Mbps", value: 120_000_000),
        (label: "4K - 80 Mbps", value: 80_000_000),
        (label: "1080p - 40 Mbps", value: 40_000_000),
        (label: "1080p - 20 Mbps", value: 20_000_000),
        (label: "720p - 8 Mbps", value: 8_000_000),
        (label: "480p - 3 Mbps", value: 3_000_000),
    ]

    var body: some View {
        List {
            ForEach(bitrateOptions, id: \.value) { option in
                Button {
                    maxBitrate = option.value
                } label: {
                    HStack {
                        Text(option.label)
                        Spacer()
                        if maxBitrate == option.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Video Quality")
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionManager.shared)
}
