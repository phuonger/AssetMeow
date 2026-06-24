import SwiftUI

@main
struct AssetMeowApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                } else {
                    LoginView()
                        .environmentObject(appState)
                }
            }
            .frame(minWidth: 1000, minHeight: 700)
            .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
