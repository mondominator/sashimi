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
                NavigationLink("Playback Settings") {
                    PlaybackSettingsView()
                }
            }

            Section("Parental Controls") {
                NavigationLink("Restrictions") {
                    ParentalControlsView()
                }
            }

            Section("Security") {
                NavigationLink("Certificate Settings") {
                    CertificateSettingsView()
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

// MARK: - Playback Settings

@MainActor
class PlaybackSettings: ObservableObject {
    static let shared = PlaybackSettings()

    @AppStorage("maxBitrate") var maxBitrate = 20_000_000
    @AppStorage("autoPlayNextEpisode") var autoPlayNextEpisode = true
    @AppStorage("autoSkipIntro") var autoSkipIntro = false
    @AppStorage("autoSkipCredits") var autoSkipCredits = false
    @AppStorage("resumeThresholdSeconds") var resumeThresholdSeconds = 30
    @AppStorage("preferredAudioLanguage") var preferredAudioLanguage = ""
    @AppStorage("preferredSubtitleLanguage") var preferredSubtitleLanguage = ""
    @AppStorage("subtitlesEnabled") var subtitlesEnabled = false
    @AppStorage("forceDirectPlay") var forceDirectPlay = false
}

struct PlaybackSettingsView: View {
    @StateObject private var settings = PlaybackSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink("Maximum Bitrate") {
                    VideoQualitySettingsView()
                }

                Toggle("Force Direct Play", isOn: $settings.forceDirectPlay)
            } header: {
                Text("Video Quality")
            } footer: {
                Text("Direct play streams the original file without transcoding. May cause issues with some formats.")
            }

            Section {
                Toggle("Auto-Play Next Episode", isOn: $settings.autoPlayNextEpisode)
                Toggle("Auto-Skip Intro", isOn: $settings.autoSkipIntro)
                Toggle("Auto-Skip Credits", isOn: $settings.autoSkipCredits)
            } header: {
                Text("Playback Behavior")
            } footer: {
                Text("Auto-skip requires the intro-skipper plugin on your Jellyfin server.")
            }

            Section {
                NavigationLink("Resume Threshold") {
                    ResumeThresholdSettingsView()
                }
            } header: {
                Text("Resume Playback")
            } footer: {
                Text("Only ask to resume if watched more than this amount.")
            }

            Section {
                NavigationLink("Preferred Language") {
                    LanguagePickerView(
                        title: "Audio Language",
                        selection: $settings.preferredAudioLanguage
                    )
                }
            } header: {
                Text("Audio")
            }

            Section {
                Toggle("Enable Subtitles", isOn: $settings.subtitlesEnabled)

                if settings.subtitlesEnabled {
                    NavigationLink("Preferred Language") {
                        LanguagePickerView(
                            title: "Subtitle Language",
                            selection: $settings.preferredSubtitleLanguage
                        )
                    }
                }
            } header: {
                Text("Subtitles")
            }
        }
        .navigationTitle("Playback")
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

struct ResumeThresholdSettingsView: View {
    @AppStorage("resumeThresholdSeconds") private var resumeThresholdSeconds = 30

    let thresholdOptions = [
        (label: "Always ask", value: 0),
        (label: "30 seconds", value: 30),
        (label: "1 minute", value: 60),
        (label: "2 minutes", value: 120),
        (label: "5 minutes", value: 300),
        (label: "10 minutes", value: 600),
    ]

    var body: some View {
        List {
            ForEach(thresholdOptions, id: \.value) { option in
                Button {
                    resumeThresholdSeconds = option.value
                } label: {
                    HStack {
                        Text(option.label)
                        Spacer()
                        if resumeThresholdSeconds == option.value {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Resume Threshold")
    }
}

struct LanguagePickerView: View {
    let title: String
    @Binding var selection: String

    let languages = [
        (code: "", name: "System Default"),
        (code: "en", name: "English"),
        (code: "es", name: "Spanish"),
        (code: "fr", name: "French"),
        (code: "de", name: "German"),
        (code: "it", name: "Italian"),
        (code: "pt", name: "Portuguese"),
        (code: "ja", name: "Japanese"),
        (code: "ko", name: "Korean"),
        (code: "zh", name: "Chinese"),
        (code: "ru", name: "Russian"),
        (code: "ar", name: "Arabic"),
        (code: "hi", name: "Hindi"),
        (code: "nl", name: "Dutch"),
        (code: "pl", name: "Polish"),
        (code: "sv", name: "Swedish"),
        (code: "da", name: "Danish"),
        (code: "no", name: "Norwegian"),
        (code: "fi", name: "Finnish"),
    ]

    var body: some View {
        List {
            ForEach(languages, id: \.code) { language in
                Button {
                    selection = language.code
                } label: {
                    HStack {
                        Text(language.name)
                        Spacer()
                        if selection == language.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Certificate Settings

struct CertificateSettingsView: View {
    @StateObject private var certSettings = CertificateTrustSettings.shared
    @State private var showingWarning = false
    @State private var pendingToggle: (() -> Void)?

    var body: some View {
        List {
            Section {
                Toggle("Allow Self-Signed Certificates", isOn: Binding(
                    get: { certSettings.allowSelfSigned },
                    set: { newValue in
                        if newValue {
                            pendingToggle = { certSettings.allowSelfSigned = true }
                            showingWarning = true
                        } else {
                            certSettings.allowSelfSigned = false
                        }
                    }
                ))

                Toggle("Allow Expired Certificates", isOn: Binding(
                    get: { certSettings.allowExpiredCerts },
                    set: { newValue in
                        if newValue {
                            pendingToggle = { certSettings.allowExpiredCerts = true }
                            showingWarning = true
                        } else {
                            certSettings.allowExpiredCerts = false
                        }
                    }
                ))
            } header: {
                Text("Certificate Validation")
            } footer: {
                Text("⚠️ Disabling certificate validation reduces security. Only enable these options if you understand the risks and trust your network.")
            }

            if !certSettings.trustedHosts.isEmpty {
                Section {
                    ForEach(Array(certSettings.trustedHosts).sorted(), id: \.self) { host in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(host)
                                    .font(.body)
                                Text("Manually trusted")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                certSettings.untrustHost(host)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Trusted Hosts")
                } footer: {
                    Text("These hosts have been manually trusted. Remove them to require valid certificates.")
                }
            }

            Section {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text("HTTPS connections are always encrypted")
                }

                HStack {
                    Image(systemName: certSettings.allowSelfSigned ? "exclamationmark.triangle" : "checkmark.shield")
                        .foregroundStyle(certSettings.allowSelfSigned ? .yellow : .green)
                    Text(certSettings.allowSelfSigned ? "Self-signed certificates accepted" : "Only trusted certificates accepted")
                }
            } header: {
                Text("Current Security Status")
            }
        }
        .navigationTitle("Certificate Settings")
        .confirmationDialog(
            "Security Warning",
            isPresented: $showingWarning,
            titleVisibility: .visible
        ) {
            Button("Enable Anyway", role: .destructive) {
                pendingToggle?()
                pendingToggle = nil
            }
            Button("Cancel", role: .cancel) {
                pendingToggle = nil
            }
        } message: {
            Text("Enabling this setting reduces the security of your connection. Man-in-the-middle attacks become possible. Only enable this if you are connecting to a trusted local server with a self-signed certificate.")
        }
    }
}

// MARK: - Parental Controls

@MainActor
class ParentalControlsManager: ObservableObject {
    static let shared = ParentalControlsManager()

    @AppStorage("parentalPIN") private var storedPIN: String = ""
    @AppStorage("isPINEnabled") var isPINEnabled: Bool = false
    @AppStorage("maxContentRating") var maxContentRating: ContentRating = .any
    @AppStorage("kidsMode") var kidsMode: Bool = false
    @AppStorage("hideUnrated") var hideUnrated: Bool = false

    var hasSetPIN: Bool {
        !storedPIN.isEmpty
    }

    func setPIN(_ pin: String) {
        storedPIN = pin
        isPINEnabled = true
    }

    func verifyPIN(_ pin: String) -> Bool {
        pin == storedPIN
    }

    func disablePIN() {
        storedPIN = ""
        isPINEnabled = false
    }

    func shouldHideItem(withRating rating: String?) -> Bool {
        guard maxContentRating != .any else { return false }

        guard let rating = rating else {
            return hideUnrated
        }

        let itemRating = ContentRating(officialRating: rating)
        return itemRating.severity > maxContentRating.severity
    }
}

enum ContentRating: String, CaseIterable, Codable {
    case any = "Any"
    case g = "G"
    case pg = "PG"
    case pg13 = "PG-13"
    case r = "R"
    case nc17 = "NC-17"

    var displayName: String {
        switch self {
        case .any: return "No Restriction"
        case .g: return "G - General Audiences"
        case .pg: return "PG - Parental Guidance"
        case .pg13: return "PG-13 - Parents Strongly Cautioned"
        case .r: return "R - Restricted"
        case .nc17: return "NC-17 - Adults Only"
        }
    }

    var severity: Int {
        switch self {
        case .any: return 100
        case .g: return 0
        case .pg: return 1
        case .pg13: return 2
        case .r: return 3
        case .nc17: return 4
        }
    }

    init(officialRating: String) {
        let normalized = officialRating.uppercased().replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "G": self = .g
        case "PG": self = .pg
        case "PG13": self = .pg13
        case "R": self = .r
        case "NC17": self = .nc17
        case "TV14": self = .pg13
        case "TVMA": self = .r
        case "TVG": self = .g
        case "TVPG": self = .pg
        case "TVY", "TVY7": self = .g
        default: self = .any
        }
    }
}

struct ParentalControlsView: View {
    @StateObject private var controls = ParentalControlsManager.shared
    @State private var showPINSetup = false
    @State private var showPINVerify = false
    @State private var pendingAction: (() -> Void)?

    var body: some View {
        List {
            Section {
                Toggle("Enable PIN Lock", isOn: Binding(
                    get: { controls.isPINEnabled },
                    set: { newValue in
                        if newValue {
                            showPINSetup = true
                        } else {
                            // Verify PIN before disabling
                            pendingAction = { controls.disablePIN() }
                            showPINVerify = true
                        }
                    }
                ))

                if controls.isPINEnabled {
                    Button("Change PIN") {
                        pendingAction = { showPINSetup = true }
                        showPINVerify = true
                    }
                }
            } header: {
                Text("PIN Protection")
            } footer: {
                Text("PIN protects access to settings and adult content.")
            }

            Section {
                NavigationLink("Maximum Content Rating") {
                    ContentRatingPickerView()
                }

                Toggle("Hide Unrated Content", isOn: $controls.hideUnrated)
            } header: {
                Text("Content Restrictions")
            } footer: {
                Text("Content above the selected rating will be hidden. Currently set to: \(controls.maxContentRating.displayName)")
            }

            Section {
                Toggle("Kids Mode", isOn: Binding(
                    get: { controls.kidsMode },
                    set: { newValue in
                        if !newValue && controls.isPINEnabled {
                            // Require PIN to disable kids mode
                            pendingAction = { controls.kidsMode = false }
                            showPINVerify = true
                        } else {
                            controls.kidsMode = newValue
                            if newValue {
                                controls.maxContentRating = .g
                            }
                        }
                    }
                ))
            } header: {
                Text("Kids Mode")
            } footer: {
                Text("Kids Mode shows only G-rated content and simplifies the interface. Requires PIN to exit.")
            }
        }
        .navigationTitle("Parental Controls")
        .sheet(isPresented: $showPINSetup) {
            PINSetupView { pin in
                controls.setPIN(pin)
                showPINSetup = false
            }
        }
        .sheet(isPresented: $showPINVerify) {
            PINVerifyView { success in
                showPINVerify = false
                if success {
                    pendingAction?()
                }
                pendingAction = nil
            }
        }
    }
}

struct ContentRatingPickerView: View {
    @AppStorage("maxContentRating") private var maxContentRating: ContentRating = .any

    var body: some View {
        List {
            ForEach(ContentRating.allCases, id: \.rawValue) { rating in
                Button {
                    maxContentRating = rating
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rating.rawValue)
                                .font(.headline)
                            Text(rating.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if maxContentRating == rating {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Content Rating")
    }
}

struct PINSetupView: View {
    let onComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step = 1
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Image(systemName: step == 1 ? "lock" : "lock.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(SashimiTheme.accent)

                Text(step == 1 ? "Create a 4-Digit PIN" : "Confirm Your PIN")
                    .font(.title2)
                    .fontWeight(.bold)

                // PIN dots display
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPIN.count > index ? SashimiTheme.accent : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical)

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                // Hidden text field for PIN input
                TextField("", text: Binding(
                    get: { currentPIN },
                    set: { handlePINInput($0) }
                ))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)

                Text("Use the number keys on your remote")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(60)
            .navigationTitle("Set PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private var currentPIN: String {
        step == 1 ? pin : confirmPin
    }

    private func handlePINInput(_ input: String) {
        let filtered = String(input.filter { $0.isNumber }.prefix(4))

        if step == 1 {
            pin = filtered
            if pin.count == 4 {
                step = 2
            }
        } else {
            confirmPin = filtered
            if confirmPin.count == 4 {
                if confirmPin == pin {
                    onComplete(pin)
                } else {
                    errorMessage = "PINs don't match. Try again."
                    confirmPin = ""
                    step = 1
                    pin = ""
                }
            }
        }
    }
}

struct PINVerifyView: View {
    let onComplete: (Bool) -> Void

    @StateObject private var controls = ParentalControlsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var attempts = 0
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(SashimiTheme.accent)

                Text("Enter Your PIN")
                    .font(.title2)
                    .fontWeight(.bold)

                // PIN dots display
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(pin.count > index ? SashimiTheme.accent : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical)

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                // Hidden text field for PIN input
                TextField("", text: Binding(
                    get: { pin },
                    set: { handlePINInput($0) }
                ))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)

                Text("Use the number keys on your remote")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(60)
            .navigationTitle("Enter PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func handlePINInput(_ input: String) {
        let filtered = String(input.filter { $0.isNumber }.prefix(4))
        pin = filtered

        if pin.count == 4 {
            if controls.verifyPIN(pin) {
                onComplete(true)
                dismiss()
            } else {
                attempts += 1
                if attempts >= 3 {
                    errorMessage = "Too many attempts. Please try again later."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        onComplete(false)
                        dismiss()
                    }
                } else {
                    errorMessage = "Incorrect PIN. \(3 - attempts) attempts remaining."
                    pin = ""
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionManager.shared)
}
