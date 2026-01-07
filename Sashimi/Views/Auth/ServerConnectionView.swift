import SwiftUI

struct ServerConnectionView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case serverAddress
        case username
        case password
        case connectButton
    }
    
    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 16) {
                Text("Sashimi")
                    .font(.system(size: 76, weight: .bold))
                
                Text("Jellyfin Client")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 40) {
                TextField("Server Address (e.g., http://192.168.1.100:8096)", text: $serverAddress)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($focusedField, equals: .serverAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                TextField("Username", text: $username)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($focusedField, equals: .username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($focusedField, equals: .password)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                
                Button {
                    connect()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLoading || !isFormValid)
                .focused($focusedField, equals: .connectButton)
            }
            .frame(maxWidth: 600)
        }
        .padding(80)
        .onAppear {
            focusedField = .serverAddress
        }
    }
    
    private var isFormValid: Bool {
        !serverAddress.isEmpty && !username.isEmpty
    }
    
    private func connect() {
        guard let url = URL(string: serverAddress) else {
            errorMessage = "Invalid server address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await sessionManager.login(serverURL: url, username: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ServerConnectionView()
        .environmentObject(SessionManager.shared)
}
