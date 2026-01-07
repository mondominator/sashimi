import SwiftUI
import AVFoundation

@main
struct SashimiApp: App {
    @StateObject private var sessionManager = SessionManager.shared

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    
    var body: some View {
        Group {
            if sessionManager.isAuthenticated {
                MainTabView()
            } else {
                ServerConnectionView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2")
                }
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            ProfileMenuView()
                .tabItem {
                    Label(sessionManager.currentUser?.name ?? "Profile", systemImage: "person.circle")
                }
        }
    }
}

struct ProfileMenuView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 20) {
                        if let userId = sessionManager.currentUser?.id,
                           let imageURL = JellyfinClient.shared.userImageURL(userId: userId) {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if let userName = sessionManager.currentUser?.name {
                                Text(userName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            if let serverURL = sessionManager.serverURL {
                                Text(serverURL.host ?? serverURL.absoluteString)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
                
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
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
}
