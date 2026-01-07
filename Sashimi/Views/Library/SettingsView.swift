import SwiftUI

struct SettingsView: View {
    var showSignOut: Bool = true
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        List {
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
