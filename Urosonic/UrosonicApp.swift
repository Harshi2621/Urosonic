// UrosonicApp.swift — Entry point

import SwiftUI

@main
struct UrosonicApp: App {
    @StateObject private var router              = AppRouter()
    @StateObject private var authState           = AuthState()
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil // Follows device system mode
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(authState)
                .environmentObject(notificationManager)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
