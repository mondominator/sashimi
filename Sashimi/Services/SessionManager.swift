import Foundation
import Combine

@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: UserDto?
    @Published private(set) var serverURL: URL?
    
    private let userDefaultsServerURLKey = "serverURL"
    private let userDefaultsAccessTokenKey = "accessToken"
    private let userDefaultsUserIdKey = "userId"
    private let keychainService = "com.sashimi.jellyfin"
    
    private init() {
        Task {
            await restoreSession()
        }
    }
    
    func restoreSession() async {
        guard let urlString = UserDefaults.standard.string(forKey: userDefaultsServerURLKey),
              let url = URL(string: urlString),
              let accessToken = UserDefaults.standard.string(forKey: userDefaultsAccessTokenKey),
              let userId = UserDefaults.standard.string(forKey: userDefaultsUserIdKey) else {
            return
        }
        
        await JellyfinClient.shared.configure(serverURL: url, accessToken: accessToken, userId: userId)
        self.serverURL = url
        self.currentUser = UserDto(id: userId, name: UserDefaults.standard.string(forKey: "userName") ?? "User", serverID: nil, primaryImageTag: nil)
        self.isAuthenticated = true
    }
    
    func login(serverURL: URL, username: String, password: String) async throws {
        await JellyfinClient.shared.configure(serverURL: serverURL)
        
        let result = try await JellyfinClient.shared.authenticate(username: username, password: password)
        
        UserDefaults.standard.set(serverURL.absoluteString, forKey: userDefaultsServerURLKey)
        UserDefaults.standard.set(result.accessToken, forKey: userDefaultsAccessTokenKey)
        UserDefaults.standard.set(result.user.id, forKey: userDefaultsUserIdKey)
        UserDefaults.standard.set(result.user.name, forKey: "userName")
        
        self.serverURL = serverURL
        self.currentUser = result.user
        self.isAuthenticated = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userDefaultsServerURLKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsAccessTokenKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsUserIdKey)
        
        self.serverURL = nil
        self.currentUser = nil
        self.isAuthenticated = false
    }
}
